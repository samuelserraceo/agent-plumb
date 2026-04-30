"""search — semantic search over `.sdd/` markdown content (closes #91).

Reads `parameters.mcp.semantic_search` from the project's `.sdd/config.md`.
If `enabled: true`, walks the project's `.sdd/` markdown surfaces
(decisions, patterns, data-model, stack, every shipped feature spec),
chunks each file into ~500-char blocks, embeds each chunk via the
configured endpoint, caches the vectors at `.sdd/.cache/embeddings.json`,
and returns the top-k chunks ranked by cosine similarity to the query.

Cache discipline:
  - Vectors keyed by (path, chunk_index, content_sha). On every search,
    only chunks whose content_sha changed since the last run are re-
    embedded; the rest are read from cache.
  - The whole cache is invalidated (re-embedded) if the model or
    provider/endpoint signature changes — different models produce
    incomparable vectors.

Provider abstraction:
  - "openai" (default) — POST /v1/embeddings, body {model, input}.
    Covers OpenAI itself, Ollama's OpenAI-compatible mode, vLLM,
    and most cloud providers.
  - "ollama-native" — POST /api/embeddings, body {model, prompt}.
    Older Ollama versions or anyone who wants the native shape.

Cost ceiling: `max_chunks_per_run` (default 1000) refuses to embed more
chunks than the cap in a single call. Stops a misconfigured huge
`.sdd/` from accidentally embedding the whole repo on first run.

Network discipline: stdlib `urllib.request` only — no `requests`, no
new framework deps. 30-second per-request timeout. One retry on 5xx
or transient timeout; fail clean otherwise.

Failure modes — all return a JSON-serialisable error shape with
plain-English explanation + a config_shape pointer for fixing:
  - endpoint unreachable (tunnel down, VPS offline, network)
  - auth fail (when an auth header is configured)
  - malformed response (provider shape doesn't match contract)
  - cost ceiling exceeded
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import tempfile
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse


_CONFIG_SHAPE = {
    "parameters": {
        "mcp": {
            "semantic_search": {
                "enabled": True,
                "provider": "<openai|ollama-native>",
                "endpoint": "<http://localhost:11434/v1/embeddings or similar>",
                "model": "<embedding model, e.g. nomic-embed-text>",
                "top_k": 5,
                "max_chunks_per_run": 1000,
            }
        }
    }
}

# Cache schema version. Bump this if the cache shape changes; mismatch
# triggers a full re-embed.
_CACHE_VERSION = 1

# Default chunk size in characters. Picked to be small enough that an
# embedding model gets coherent context, large enough that we don't
# embed every line. Sentence-aware splitting kicks in when a paragraph
# exceeds this.
_DEFAULT_CHUNK_CHARS = 500

# HTTP timeout per embedding call. CPU-only servers (e.g. Sam's GEMMA
# host) take 50-200ms per embedding; 30s gives plenty of headroom for
# slow networks + retries.
_HTTP_TIMEOUT_SECONDS = 30

# Whitelisted provider strings. Update both this set AND the per-provider
# branch in `_embed_one` together when adding a new shape — the upstream
# config-resolution check uses this set for early rejection so users get a
# clean error before chunking and network work.
_SUPPORTED_PROVIDERS = {"openai", "ollama-native"}


# ────────────────────────────────────────────────────────────────────
# Config + cache I/O
# ────────────────────────────────────────────────────────────────────


def _read_config_yaml(project_root: str) -> Dict[str, Any]:
    """Pull the YAML frontmatter from .sdd/config.md.

    config.md uses `---\n<yaml>\n---\n<prose>`. We parse the front matter
    only — the prose is human guidance, not config.
    """
    cfg_path = os.path.join(project_root, ".sdd", "config.md")
    if not os.path.isfile(cfg_path):
        return {}
    try:
        with open(cfg_path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return {}
    # Match frontmatter on both LF (Unix) and CRLF (Windows) checkouts.
    fm = re.match(r"^---\s*\r?\n(.*?)\r?\n---", text, re.DOTALL)
    if not fm:
        return {}
    try:
        import yaml  # PyYAML — already a framework dep
    except ImportError:
        return {}
    try:
        loaded = yaml.safe_load(fm.group(1)) or {}
        return loaded if isinstance(loaded, dict) else {}
    except Exception:
        return {}


def _cache_path(project_root: str) -> str:
    return os.path.join(project_root, ".sdd", ".cache", "embeddings.json")


def _load_cache(project_root: str) -> Dict[str, Any]:
    """Read the embeddings cache. Returns an empty cache shape on any
    failure (file missing, malformed JSON, version mismatch — caller
    handles invalidation by re-embedding everything)."""
    path = _cache_path(project_root)
    if not os.path.isfile(path):
        return {"version": _CACHE_VERSION, "endpoint_signature": "", "chunks": []}
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {"version": _CACHE_VERSION, "endpoint_signature": "", "chunks": []}
    if not isinstance(data, dict) or data.get("version") != _CACHE_VERSION:
        return {"version": _CACHE_VERSION, "endpoint_signature": "", "chunks": []}
    if not isinstance(data.get("chunks"), list):
        data["chunks"] = []
    return data


def _save_cache(project_root: str, cache: Dict[str, Any]) -> None:
    """Atomic write — tempfile + rename so a crash mid-write never
    leaves the cache half-written (same discipline as advance.sh's
    spec.md writer + settings.sh's config.md writer)."""
    path = _cache_path(project_root)
    cache_dir = os.path.dirname(path)
    os.makedirs(cache_dir, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".embeddings.tmp.", dir=cache_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(cache, fh, ensure_ascii=False, separators=(",", ":"))
        os.replace(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            try:
                os.unlink(tmp)
            except OSError:
                pass
        raise


# ────────────────────────────────────────────────────────────────────
# File walker + chunker
# ────────────────────────────────────────────────────────────────────


def _walk_sdd_files(project_root: str) -> List[Tuple[str, str]]:
    """Return list of (relative_path, content) for every .md surface
    we want searchable.

    Includes:
      - .sdd/decisions.md, patterns.md, data-model.md, stack.md
      - .sdd/features/<id>/spec.md for every feature folder

    Excludes:
      - Framework asset dirs (playbooks/, actions/, scripts/, setup/,
        .cache/) — those are framework code, not project knowledge
      - .sdd/ideas/ — half-baked thoughts; user can opt these in later
    """
    sdd = os.path.join(project_root, ".sdd")
    if not os.path.isdir(sdd):
        return []
    out: List[Tuple[str, str]] = []
    # Top-level knowledge files
    for name in ("decisions.md", "patterns.md", "data-model.md", "stack.md"):
        fp = os.path.join(sdd, name)
        if os.path.isfile(fp):
            try:
                with open(fp, encoding="utf-8") as fh:
                    out.append((os.path.relpath(fp, project_root), fh.read()))
            except OSError:
                continue
    # Per-feature spec.md
    features_dir = os.path.join(sdd, "features")
    if os.path.isdir(features_dir):
        for entry in sorted(os.listdir(features_dir)):
            spec_path = os.path.join(features_dir, entry, "spec.md")
            if os.path.isfile(spec_path):
                try:
                    with open(spec_path, encoding="utf-8") as fh:
                        out.append((os.path.relpath(spec_path, project_root), fh.read()))
                except OSError:
                    continue
    return out


def _chunk_text(content: str, max_chars: int = _DEFAULT_CHUNK_CHARS) -> List[Dict[str, Any]]:
    """Split markdown content into chunks of at most `max_chars` chars.

    Strategy:
      1. Split on double-newline (paragraph boundaries) — markdown's
         natural section.
      2. If a paragraph is longer than max_chars, sub-split on sentence
         boundaries (`. ` or `.\n`).
      3. If a sentence is still longer (rare; usually code blocks),
         hard-split at max_chars. Acceptable degradation.

    Returns a list of dicts: [{chunk_index, start_line, end_line, content}].
    Empty input → empty list.
    """
    if not content:
        return []
    chunks: List[Dict[str, Any]] = []
    current_line = 1
    paragraphs = content.split("\n\n")
    chunk_idx = 0
    for para in paragraphs:
        para_lines = para.count("\n") + 1
        if not para.strip():
            current_line += para_lines + 1  # +1 for the splitter blank line
            continue
        if len(para) <= max_chars:
            chunks.append({
                "chunk_index": chunk_idx,
                "start_line": current_line,
                "end_line": current_line + para_lines - 1,
                "content": para.strip(),
            })
            chunk_idx += 1
        else:
            # Paragraph too long — sub-split on sentences. Naïve but
            # good enough; markdown blocks rarely have run-on sentences.
            #
            # CR cycle-2 finding: track sentence positions as offsets
            # into the ORIGINAL `para` text, not as substrings of a
            # rebuilt buffer. The earlier `re.split` approach dropped
            # the separator whitespace (including embedded newlines),
            # so `buf.count("\n")` undercounted source lines whenever
            # the split point crossed a line break. By using
            # `re.finditer` with span info, line counts come straight
            # from the original para via `para[a:b].count("\n")` —
            # always exact.
            sentence_re = re.compile(r".+?(?:[.!?](?:\s+|$)|$)", re.DOTALL)
            sentences = list(sentence_re.finditer(para))
            chunk_start_off = 0  # offset into para where the current chunk begins
            buf_end_off = 0      # offset into para where the current chunk ends so far

            def _line_at(offset: int) -> int:
                """1-based source line number of `offset` within the
                file, given the paragraph starts at `current_line`."""
                return current_line + para[:offset].count("\n")

            def _emit(start_off: int, end_off: int) -> None:
                nonlocal chunk_idx
                snippet = para[start_off:end_off].strip()
                if not snippet:
                    return
                chunks.append({
                    "chunk_index": chunk_idx,
                    "start_line": _line_at(start_off),
                    "end_line": _line_at(end_off - 1) if end_off > start_off else _line_at(start_off),
                    "content": snippet,
                })
                chunk_idx += 1

            for m in sentences:
                sent_start, sent_end = m.start(), m.end()
                if not para[sent_start:sent_end].strip():
                    continue  # skip pure-whitespace tail match from `|$` branch
                # Would adding this sentence overflow the cap?
                if sent_end - chunk_start_off > max_chars and buf_end_off > chunk_start_off:
                    _emit(chunk_start_off, buf_end_off)
                    chunk_start_off = buf_end_off
                # Sentence on its own exceeds cap → hard-split it into
                # max_chars-sized pieces. Advance chunk_start_off per
                # emitted piece so each piece's start_line/end_line is
                # computed from its real para offsets.
                if sent_end - sent_start > max_chars:
                    if buf_end_off > chunk_start_off:
                        _emit(chunk_start_off, buf_end_off)
                        chunk_start_off = buf_end_off
                    for i in range(sent_start, sent_end, max_chars):
                        piece_end = min(i + max_chars, sent_end)
                        _emit(i, piece_end)
                    chunk_start_off = sent_end
                    buf_end_off = sent_end
                else:
                    buf_end_off = sent_end
            if buf_end_off > chunk_start_off:
                _emit(chunk_start_off, buf_end_off)
        current_line += para_lines + 1  # +1 for the splitter blank line
    return chunks


def _chunk_sha(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


# ────────────────────────────────────────────────────────────────────
# Embedding client
# ────────────────────────────────────────────────────────────────────


class EmbeddingError(Exception):
    """Raised when an embedding call fails. The user-visible string
    explains what went wrong + how to fix."""


def _endpoint_signature(provider: str, endpoint: str, model: str) -> str:
    """Deterministic id for cache invalidation. Cache keyed by this;
    if it changes, invalidate the whole cache (vectors aren't
    comparable across models / providers)."""
    return hashlib.sha256(
        f"{provider}|{endpoint}|{model}".encode("utf-8")
    ).hexdigest()[:16]


def _normalize_endpoint(provider: str, endpoint: str) -> str:
    """If the user's endpoint is just the base URL (e.g. http://host:11434),
    auto-append the right path for the provider. If they wrote the full
    path themselves, leave it alone."""
    endpoint = endpoint.rstrip("/")
    if provider == "openai":
        if endpoint.endswith("/embeddings") or endpoint.endswith("/v1/embeddings"):
            return endpoint
        return endpoint + "/v1/embeddings"
    if provider == "ollama-native":
        if endpoint.endswith("/api/embeddings"):
            return endpoint
        return endpoint + "/api/embeddings"
    # Unknown provider — let the user's URL stand as-is and let the
    # network error path catch the failure.
    return endpoint


def _embed_one(
    provider: str,
    endpoint: str,
    model: str,
    text: str,
    auth_header: Optional[str] = None,
) -> List[float]:
    """Embed a single text via the configured provider. Returns the
    raw vector. Raises EmbeddingError on any failure."""
    if provider == "openai":
        body = {"model": model, "input": text}
        response_key = "data"  # response is {data: [{embedding: [...]}]}
    elif provider == "ollama-native":
        body = {"model": model, "prompt": text}
        response_key = "embedding"  # response is {embedding: [...]}
    else:
        raise EmbeddingError(
            f"unknown provider '{provider}'. Supported: openai, ollama-native. "
            f"Set parameters.mcp.semantic_search.provider in .sdd/config.md."
        )

    # Validate URL scheme before any network call. Without this, a malformed
    # endpoint like `file:///etc/passwd` would happily be opened by urlopen
    # — defence-in-depth even though the endpoint comes from project-trusted
    # config.md. CR cycle-1 finding.
    parsed_url = urlparse(endpoint)
    if parsed_url.scheme.lower() not in ("http", "https"):
        raise EmbeddingError(
            f"endpoint URL scheme must be http or https; got "
            f"{parsed_url.scheme!r} for endpoint {endpoint!r}. "
            f"Fix parameters.mcp.semantic_search.endpoint in .sdd/config.md."
        )

    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url=endpoint,
        data=data,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    if auth_header:
        req.add_header("Authorization", auth_header)

    last_error: Optional[Exception] = None
    for attempt in range(2):  # 1 initial + 1 retry on transient
        try:
            with urllib.request.urlopen(req, timeout=_HTTP_TIMEOUT_SECONDS) as resp:
                payload = resp.read().decode("utf-8")
                parsed = json.loads(payload)
        except urllib.error.HTTPError as exc:
            # 5xx → retry. 4xx → fail (config/auth issue, retry won't help).
            if 500 <= exc.code < 600 and attempt == 0:
                last_error = exc
                continue
            # `from exc` preserves the original traceback for debugging
            # while keeping a clean user-facing message. CR cycle-1.
            raise EmbeddingError(
                f"embedding endpoint returned HTTP {exc.code} ({exc.reason}). "
                f"Check parameters.mcp.semantic_search.endpoint and credentials."
            ) from exc
        except urllib.error.URLError as exc:
            # Network unreachable. Retry once.
            if attempt == 0:
                last_error = exc
                continue
            raise EmbeddingError(
                f"embedding endpoint not reachable: {exc.reason}. "
                f"Check the endpoint URL or the SSH tunnel/network connection."
            ) from exc
        except (json.JSONDecodeError, TimeoutError, UnicodeDecodeError) as exc:
            # UnicodeDecodeError (CR cycle-2): some endpoints return
            # binary or non-UTF-8 payloads on error — wrap them in the
            # same friendly EmbeddingError instead of letting the raw
            # decode failure bubble up as a stack trace.
            raise EmbeddingError(
                f"embedding endpoint returned malformed response: {exc}. "
                f"The provider may be wrong (set provider: openai or "
                f"ollama-native in .sdd/config.md)."
            ) from exc
        # Parse response shape per provider.
        if provider == "openai":
            if not isinstance(parsed, dict) or "data" not in parsed:
                raise EmbeddingError(
                    "OpenAI-compatible response missing 'data' field. "
                    "Endpoint may not actually speak OpenAI shape — try "
                    "provider: ollama-native if pointing at older Ollama."
                )
            data_arr = parsed["data"]
            if not isinstance(data_arr, list) or not data_arr:
                raise EmbeddingError("OpenAI-compatible response has empty 'data' array.")
            first = data_arr[0]
            if not isinstance(first, dict) or "embedding" not in first:
                raise EmbeddingError("OpenAI-compatible response missing 'data[0].embedding'.")
            vector = first["embedding"]
        else:  # ollama-native
            if not isinstance(parsed, dict) or "embedding" not in parsed:
                raise EmbeddingError(
                    "Ollama-native response missing 'embedding' field. "
                    "Endpoint may speak the OpenAI shape — try "
                    "provider: openai instead."
                )
            vector = parsed["embedding"]
        if not isinstance(vector, list) or not vector:
            raise EmbeddingError("embedding response had empty vector.")
        if not all(isinstance(x, (int, float)) for x in vector):
            raise EmbeddingError("embedding response vector contained non-numeric values.")
        return [float(x) for x in vector]

    # Exhausted retries
    raise EmbeddingError(
        f"embedding call failed after retry: {last_error}. "
        f"Check the endpoint and the network."
    )


# ────────────────────────────────────────────────────────────────────
# Cosine similarity (pure Python — no numpy dep)
# ────────────────────────────────────────────────────────────────────


def _cosine(a: List[float], b: List[float]) -> float:
    if len(a) != len(b) or not a:
        return 0.0
    dot = 0.0
    norm_a = 0.0
    norm_b = 0.0
    for x, y in zip(a, b):
        dot += x * y
        norm_a += x * x
        norm_b += y * y
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return dot / ((norm_a ** 0.5) * (norm_b ** 0.5))


# ────────────────────────────────────────────────────────────────────
# Main entry point
# ────────────────────────────────────────────────────────────────────


def search(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    """Semantic search over the project's .sdd/ markdown surfaces.

    Args:
        project_root: project root path
        args: dict; expected keys:
            query (required, string)
            top_k (optional, int — overrides config)

    Returns: dict with one of these shapes:

        On success:
            {
              "matches": [{path, snippet, score, start_line, end_line}, ...],
              "stats": {
                "total_chunks": int,
                "embedded_this_run": int,
                "from_cache": int,
                "elapsed_ms": int (optional),
              }
            }

        On disabled:
            {"error": "not configured", "config_shape": {...}, "query": ...}

        On embedding failure:
            {"error": "...plain English fix path...",
             "fallback": "agent should read files directly",
             "query": ...}

        On cost ceiling:
            {"error": "would embed N chunks; cap is M", "query": ...}
    """
    query = (args or {}).get("query")
    if not query or not isinstance(query, str):
        return {"error": "missing or non-string arg 'query'"}

    cfg = _read_config_yaml(project_root)
    sem = (((cfg.get("parameters") or {}).get("mcp") or {}).get("semantic_search") or {})
    if not isinstance(sem, dict):
        sem = {}
    enabled = bool(sem.get("enabled"))

    if not enabled:
        return {
            "error": "semantic search not configured — set parameters.mcp.semantic_search "
                     "in .sdd/config.md",
            "config_shape": _CONFIG_SHAPE,
            "query": query,
        }

    # Resolve config — provider, endpoint, model are all REQUIRED. Per the
    # framework's foundation 3 doctrine ("Never assume — always check") and
    # CLAUDE.md's "external dependencies must be explicit customisation
    # blocks, never baked-in defaults", we refuse to silently default the
    # provider. The user must commit to one in .sdd/config.md.
    # CR cycle-1 finding.
    provider_raw = sem.get("provider")
    if not isinstance(provider_raw, str) or not provider_raw:
        return {
            "error": "parameters.mcp.semantic_search.provider is required. "
                     "Set it to \"openai\" (default OpenAI-compatible shape — "
                     "works with Ollama in compatible mode, vLLM, etc.) or "
                     "\"ollama-native\" (older Ollama versions) in "
                     ".sdd/config.md.",
            "config_shape": _CONFIG_SHAPE,
            "query": query,
        }
    # CR cycle-2 finding: reject unsupported providers HERE in config
    # resolution, not later inside _embed_one. Earlier rejection means
    # the user gets a clean config error before any chunking / file
    # walking / network call happens, instead of a misleading
    # mid-pipeline EmbeddingError.
    if provider_raw not in _SUPPORTED_PROVIDERS:
        supported = ", ".join(sorted(_SUPPORTED_PROVIDERS))
        return {
            "error": (
                f"parameters.mcp.semantic_search.provider {provider_raw!r} is "
                f"not supported. Supported values: {supported}. Set provider "
                f"in .sdd/config.md."
            ),
            "config_shape": _CONFIG_SHAPE,
            "query": query,
        }
    provider = provider_raw
    endpoint_raw = sem.get("endpoint")
    if not isinstance(endpoint_raw, str) or not endpoint_raw:
        return {
            "error": "parameters.mcp.semantic_search.endpoint is required (e.g. "
                     "http://localhost:11434 for an Ollama tunnel).",
            "config_shape": _CONFIG_SHAPE,
            "query": query,
        }
    model_raw = sem.get("model")
    if not isinstance(model_raw, str) or not model_raw:
        return {
            "error": "parameters.mcp.semantic_search.model is required (e.g. "
                     "nomic-embed-text or bge-small-en-v1.5).",
            "config_shape": _CONFIG_SHAPE,
            "query": query,
        }
    endpoint = _normalize_endpoint(provider, endpoint_raw)
    top_k_raw = (args or {}).get("top_k")
    if not isinstance(top_k_raw, int) or top_k_raw <= 0:
        top_k_cfg = sem.get("top_k", 5)
        top_k = int(top_k_cfg) if isinstance(top_k_cfg, int) and top_k_cfg > 0 else 5
    else:
        top_k = top_k_raw
    max_chunks_cfg = sem.get("max_chunks_per_run", 1000)
    max_chunks = int(max_chunks_cfg) if isinstance(max_chunks_cfg, int) and max_chunks_cfg > 0 else 1000
    auth_header = sem.get("auth_header")  # optional; e.g. "Bearer xyz"
    auth_header = auth_header if isinstance(auth_header, str) and auth_header else None

    # Walk + chunk every searchable file.
    files = _walk_sdd_files(project_root)
    if not files:
        return {
            "matches": [],
            "stats": {"total_chunks": 0, "embedded_this_run": 0, "from_cache": 0},
            "query": query,
        }

    sig = _endpoint_signature(provider, endpoint, model_raw)
    cache = _load_cache(project_root)
    # If the endpoint signature changed (model swapped, provider swapped,
    # endpoint changed) — invalidate cache.
    if cache.get("endpoint_signature") != sig:
        cache = {"version": _CACHE_VERSION, "endpoint_signature": sig, "chunks": []}

    cached_index: Dict[Tuple[str, int, str], List[float]] = {}
    for entry in cache.get("chunks", []):
        if not isinstance(entry, dict):
            continue
        key = (entry.get("path"), entry.get("chunk_index"), entry.get("content_sha"))
        vec = entry.get("vector")
        if isinstance(vec, list):
            cached_index[key] = vec

    # Build the list of chunks to embed (cache miss).
    all_chunks: List[Dict[str, Any]] = []  # what we'll search over
    to_embed: List[Tuple[int, Dict[str, Any]]] = []  # (index_in_all_chunks, chunk_meta)
    for rel_path, content in files:
        for ch in _chunk_text(content):
            sha = _chunk_sha(ch["content"])
            entry = {
                "path": rel_path,
                "chunk_index": ch["chunk_index"],
                "start_line": ch["start_line"],
                "end_line": ch["end_line"],
                "content": ch["content"],
                "content_sha": sha,
                "vector": cached_index.get((rel_path, ch["chunk_index"], sha)),
            }
            all_chunks.append(entry)
            if entry["vector"] is None:
                to_embed.append((len(all_chunks) - 1, entry))

    # Cost ceiling.
    if len(to_embed) > max_chunks:
        return {
            "error": (
                f"would embed {len(to_embed)} chunks; cap is {max_chunks}. "
                f"Either raise max_chunks_per_run in .sdd/config.md, or "
                f"prune .sdd/ content (archive shipped specs, compress patterns.md)."
            ),
            "stats": {"total_chunks": len(all_chunks), "would_embed": len(to_embed)},
            "query": query,
        }

    # Embed cache misses.
    embedded_this_run = 0
    for idx, entry in to_embed:
        try:
            vec = _embed_one(provider, endpoint, model_raw, entry["content"], auth_header)
        except EmbeddingError as exc:
            return {
                "error": str(exc),
                "fallback": "agent should fall back to reading the file directly for this query",
                "stats": {
                    "total_chunks": len(all_chunks),
                    "embedded_this_run": embedded_this_run,
                    "from_cache": len(all_chunks) - len(to_embed),
                },
                "query": query,
            }
        all_chunks[idx]["vector"] = vec
        embedded_this_run += 1

    # Persist cache (only after all embeds succeed — partial writes
    # would corrupt the next run's cache hit detection).
    cache["endpoint_signature"] = sig
    cache["chunks"] = [
        {
            "path": c["path"],
            "chunk_index": c["chunk_index"],
            "content_sha": c["content_sha"],
            "vector": c["vector"],
        }
        for c in all_chunks
        if c["vector"] is not None
    ]
    try:
        _save_cache(project_root, cache)
    except OSError as exc:
        # Cache write failed — don't fail the whole search; just note
        # in stats. Next run will re-embed everything (small cost).
        cache_warning: Optional[str] = f"cache write failed: {exc}"
    else:
        cache_warning = None

    # Embed the query.
    try:
        query_vec = _embed_one(provider, endpoint, model_raw, query, auth_header)
    except EmbeddingError as exc:
        return {
            "error": str(exc),
            "fallback": "agent should fall back to reading the file directly for this query",
            "query": query,
        }

    # Score every chunk.
    scored: List[Tuple[float, Dict[str, Any]]] = []
    for ch in all_chunks:
        vec = ch.get("vector")
        if not isinstance(vec, list):
            continue
        scored.append((_cosine(query_vec, vec), ch))
    scored.sort(key=lambda x: x[0], reverse=True)

    matches = [
        {
            "path": ch["path"],
            "snippet": ch["content"][:300],
            "score": round(score, 4),
            "start_line": ch["start_line"],
            "end_line": ch["end_line"],
        }
        for score, ch in scored[:top_k]
    ]

    out = {
        "matches": matches,
        "stats": {
            "total_chunks": len(all_chunks),
            "embedded_this_run": embedded_this_run,
            "from_cache": len(all_chunks) - embedded_this_run,
        },
        "query": query,
    }
    if cache_warning:
        out["warning"] = cache_warning
    return out
