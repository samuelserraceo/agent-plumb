"""Tier 3 LLM-driven synthesis (v1.1).

When you (or the agent) asks a question about your project, takes the
relevant pieces of `.sdd/` markdown that v1.0 retrieval already returns,
sends them to a chat AI you've configured (Ollama+Gemma in v1.1's
wizard scope), and returns the answer with `[[…]]` citations that
resolve to real graph nodes.

See spec: .sdd/features/001-tier-3-llm-driven-synthesis/spec.md
See wireframe: .sdd/features/001-tier-3-llm-driven-synthesis/wireframe.html

Build sequence (per §14 plan-decompose):
  T1 — scaffold (this file's stub) ✓
  T5 — clean answer flow (this file)
  T6 — cite-check rejects invented [[link]]
  T7 — rejected answer NOT cached
  T8 — cache hit/miss
  T9 — cache invalidates on corpus signature flip
  T10 — three call/token caps
  T11/T12 — structured + prose renderers
  T13-T16 — config / disabled / envvar / literal-token warning
  T17 — four failure modes
  T18 — 1024-byte length cap
  T19 — injection floor
  T20/T21 — ambiguity / empty corpus (best-effort)
  T22 — observability counters
  T28-T30 — cache eviction / question validation / slug sanitisation
"""

from __future__ import annotations

import contextlib
import hashlib
import json
import os
import re
import tempfile
import time
from typing import Any, Callable, Dict, List, Optional, Tuple

import yaml

from . import _graph_cache


# ─── Constants (anti-theatre — exact thresholds, not vague) ──────────
_CACHE_VERSION = 1
_CACHE_MAX_ENTRIES = 1000               # T28 — LRU eviction at this size
_DEFAULT_LENGTH_CAP_BYTES = 1024        # T18 — exact byte count
_QUESTION_MAX_CHARS = 2000              # T29 — exact char count
_VALID_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9._:\-]*$", re.IGNORECASE)  # T30
_LITERAL_TOKEN_PATTERNS = [             # T16 — common provider key shapes
    re.compile(r"^sk-[A-Za-z0-9]{20,}$"),
    re.compile(r"^sk_live_[A-Za-z0-9]{20,}$"),
    re.compile(r"^Bearer\s+eyJ[A-Za-z0-9._-]{10,}$"),
]
_WIKI_LINK_RE = re.compile(r"\[\[([a-z0-9][a-z0-9._:\-]*)\]\]", re.IGNORECASE)


# ─── Exceptions used internally ──────────────────────────────────────
class _Tier3Error(Exception):
    """Internal — caught by synthesise() and rendered as ok:false."""

    def __init__(self, reason: str, **extras: Any) -> None:
        super().__init__(reason)
        self.reason = reason
        self.extras = extras


# ─── Public entry point ──────────────────────────────────────────────
def synthesise(
    project_root: str,
    args: Dict[str, Any],
    *,
    _llm_call: Optional[Callable[[str, List[Dict[str, Any]], Dict[str, Any]], str]] = None,
    _now: Optional[Callable[[], float]] = None,
) -> Dict[str, Any]:
    """Tier 3 synthesis: project + question → cited answer.

    Args:
        project_root: absolute path to the SDD project (the directory
            containing the `.sdd/` tree).
        args: per-query argument dict. Keys:
            - slug (str, required): a graph-node slug to anchor the
              retrieval (e.g. "001-waitlist", "pattern:auth-retry").
            - question (str, optional): the natural-language question.
              Empty string is acceptable in test fixtures.
            - format ("structured" | "prose", default "structured"):
              shape of the response (T11 / T12).
        _llm_call: dependency-injection slot for tests + mocking. Real
            implementation calls Ollama HTTP in T24; tests inject a
            mock that returns canned text.
        _now: dependency-injection slot for time — useful for cache
            LRU + observability tests.

    Returns:
        Dict with at least an `ok` key. On success, also: `answer`,
        `cite_chunks`, `ambiguity`, `format_seen`. On failure: `reason`,
        and (for cite-check failure) a raw-chunks fallback in
        `cite_chunks`.
    """
    try:
        # 1. Load + validate config (T2 / T13 / T14)
        cfg = _load_tier3_config(project_root)
        if not cfg.get("enabled"):
            return _err("Tier 3 not enabled in this project's config.md")

        # 2. Validate args (T29 / T30)
        slug = (args or {}).get("slug", "")
        question = (args or {}).get("question", "")
        fmt = (args or {}).get("format", "structured")

        if not isinstance(slug, str) or not _VALID_SLUG_RE.match(slug or ""):
            return _err(f"invalid slug: {slug!r}")

        question_err = _validate_question(question)
        if question_err is not None:
            return _err(f"question invalid: {question_err}")

        if fmt not in ("structured", "prose"):
            return _err(f"invalid format: {fmt!r} (expected 'structured' or 'prose')")

        # 3. Resolve provider auth (T15 — env-var indirection)
        cfg = dict(cfg)  # local copy, don't mutate cached config
        cfg["auth_header"] = _resolve_auth_header(cfg.get("auth_header", ""))

        # 4. Load graph cache (used for cite-check + retrieval)
        graph = _graph_cache.load(project_root)
        corpus_signature = graph.get("source_signature", "")

        # 5. Cache lookup (T8 — exact-match question + corpus signature)
        cache = _load_synthesis_cache(project_root)
        cache_key = _make_cache_key(question, corpus_signature)
        hit = cache.get("entries", {}).get(cache_key)
        if hit is not None:
            # Update LRU touch time + return cached answer
            now_fn = _now or time.time
            hit["touched_at"] = now_fn()
            _save_synthesis_cache(project_root, cache)
            return _render(hit, fmt)

        # 6. Retrieval — gather candidate chunks (T5 path; reuses
        #    v1.0 graph queries minimally for now)
        chunks = _gather_chunks(project_root, graph, slug, question)

        # 7. Caps — pre-network refusal (T10)
        cap_err = _check_caps(chunks, cfg)
        if cap_err is not None:
            return _err(cap_err)

        # 8. LLM call — dependency-injected for tests
        llm = _llm_call or _real_llm_call
        try:
            answer_text = llm(question, chunks, cfg)
        except _ProviderUnreachable as e:
            return _err(f"provider unreachable: {e}")
        except _ProviderRateLimited as e:
            return _err(f"rate-limited: {e}")
        except Exception as e:  # noqa: BLE001 — defensive default
            return _err(f"AI returned malformed response: {type(e).__name__}: {e}")

        if not isinstance(answer_text, str):
            return _err("AI returned malformed response: not a string")

        # 9. Length cap (T18) — trim to 1024 bytes if longer
        answer_text, was_trimmed = _apply_length_cap(answer_text)

        # 10. Cite-check (T5 + T6)
        cite_slugs = _WIKI_LINK_RE.findall(answer_text)
        cite_chunks: List[Dict[str, Any]] = []
        broken: List[str] = []
        for cs in cite_slugs:
            node = _graph_cache.find_node(graph, cs)
            if node is None:
                broken.append(cs)
            else:
                cite_chunks.append({
                    "slug": node.get("slug", cs),
                    "path": node.get("path", ""),
                    "line": node.get("line"),
                    "kind": node.get("kind", "unknown"),
                })

        if broken:
            # T6 — cite-check rejection → raw-chunks fallback
            # T7 — do NOT cache the rejected answer
            return {
                "ok": False,
                "reason": f"cite-check failed: invented citations {broken}",
                "answer": None,
                "cite_chunks": chunks,  # raw retrieval chunks
                "ambiguity": None,
                "broken_slugs": broken,
            }

        # 11. Build success entry (T8 cache write — only on success per AC5)
        now_fn = _now or time.time
        entry = {
            "answer": answer_text,
            "cite_chunks": cite_chunks,
            "ambiguity": _detect_ambiguity_marker(answer_text),
            "format_seen": [fmt],
            "created_at": now_fn(),
            "touched_at": now_fn(),
            "trimmed": was_trimmed,
        }

        # 12. Cache write with LRU eviction (T28)
        cache.setdefault("entries", {})[cache_key] = entry
        _evict_lru_if_full(cache)
        _save_synthesis_cache(project_root, cache)

        return _render(entry, fmt)

    except _Tier3Error as e:
        return {"ok": False, "reason": e.reason, **e.extras}


# ─── Helpers ─────────────────────────────────────────────────────────
def _err(reason: str, **extras: Any) -> Dict[str, Any]:
    """Canonical error shape — every error path returns through here."""
    return {"ok": False, "reason": reason, "answer": None, "cite_chunks": [], "ambiguity": None, **extras}


def _load_tier3_config(project_root: str) -> Dict[str, Any]:
    """Read parameters.mcp.tier3 from .sdd/config.md frontmatter."""
    cfg_path = os.path.join(project_root, ".sdd", "config.md")
    if not os.path.isfile(cfg_path):
        return {"enabled": False}
    try:
        with open(cfg_path, encoding="utf-8") as f:
            text = f.read()
    except (OSError, UnicodeDecodeError):
        return {"enabled": False}
    if not text.startswith("---"):
        return {"enabled": False}
    end = text.find("\n---", 4)
    if end < 0:
        return {"enabled": False}
    try:
        fm = yaml.safe_load(text[4:end])
    except yaml.YAMLError:
        return {"enabled": False}
    return ((fm or {}).get("parameters") or {}).get("mcp", {}).get("tier3") or {"enabled": False}


def _validate_question(question: Any) -> Optional[str]:
    """Return None if valid; an error reason string if invalid (T29)."""
    if question is None:
        return "missing"
    if not isinstance(question, str):
        return f"not a string (got {type(question).__name__})"
    if question == "":
        return "empty"
    if len(question) > _QUESTION_MAX_CHARS:
        return f"too long ({len(question)} chars; max {_QUESTION_MAX_CHARS})"
    # Reject control characters + null bytes
    if any(ord(c) < 0x20 and c not in "\t\n\r" for c in question):
        return "contains control characters"
    if "\x00" in question:
        return "contains null bytes"
    return None


def _resolve_auth_header(value: str) -> str:
    """Resolve ${ENV_VAR} indirection (T15). Empty string passthrough.
    Also fires a warning to stderr if a literal-looking token is
    pasted directly (T16)."""
    if not value:
        return ""
    m = re.fullmatch(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", value)
    if m:
        return os.environ.get(m.group(1), "")
    # Literal value — check if it looks like a real key (T16 warning)
    for pat in _LITERAL_TOKEN_PATTERNS:
        if pat.match(value):
            import sys
            print(
                f"[tier3-warning] auth_header looks like a real provider key. "
                f"To keep tokens out of git-tracked config, use ${{ENV_VAR}} "
                f"indirection instead of pasting the literal value.",
                file=sys.stderr,
            )
            break
    return value


def _make_cache_key(question: str, corpus_signature: str) -> str:
    """Cache key = sha256(question) || corpus_signature (T8 / T9)."""
    qh = hashlib.sha256(question.encode("utf-8")).hexdigest()
    return f"{qh}:{corpus_signature}"


def _gather_chunks(project_root: str, graph: Dict[str, Any], slug: str, question: str) -> List[Dict[str, Any]]:
    """Minimal retrieval — gather chunks of `.sdd/` content near `slug`.

    For T5+: walks the graph for the slug + its neighbours, reads each
    target's content (capped to 2KB per chunk for token bounds).
    Real embedding-based retrieval is layered later when semantic_search
    is enabled — this is the structural retrieval path that always works.
    """
    chunks: List[Dict[str, Any]] = []
    nodes = graph.get("nodes", [])
    seen_paths: set = set()
    # Anchor node
    for n in nodes:
        if n.get("slug", "").lower() == slug.lower() and n.get("path") not in seen_paths:
            chunks.append(_read_chunk(project_root, n))
            seen_paths.add(n.get("path"))
    # Neighbour nodes (cheap heuristic — first 4 other nodes)
    for n in nodes:
        if len(chunks) >= 5:
            break
        if n.get("path") in seen_paths:
            continue
        chunks.append(_read_chunk(project_root, n))
        seen_paths.add(n.get("path"))
    return chunks


def _read_chunk(project_root: str, node: Dict[str, Any]) -> Dict[str, Any]:
    """Read a node's content, capped at 2KB for chunk-size discipline."""
    path = node.get("path", "")
    line = node.get("line", 1)
    abs_path = os.path.join(project_root, path) if not os.path.isabs(path) else path
    text = ""
    try:
        with open(abs_path, encoding="utf-8") as f:
            text = f.read(2048)
    except (OSError, UnicodeDecodeError):
        text = ""
    return {
        "slug": node.get("slug", ""),
        "path": path,
        "line": line,
        "kind": node.get("kind", "unknown"),
        "text": text,
    }


def _check_caps(chunks: List[Dict[str, Any]], cfg: Dict[str, Any]) -> Optional[str]:
    """Pre-network token-count check (T10 / T29).

    Approximate token count: bytes / 4 (rough char-to-token ratio for
    English markdown; close enough for cap-enforcement). Real provider
    tokenisers would tighten this — we err on the side of refusing
    earlier rather than later.
    """
    max_input = int(cfg.get("max_input_tokens_per_call", 8000))
    total_bytes = sum(len(c.get("text", "").encode("utf-8")) for c in chunks)
    approx_tokens = total_bytes // 4
    if approx_tokens > max_input:
        return f"max_input_tokens_per_call exceeded (~{approx_tokens} > {max_input})"
    return None


def _apply_length_cap(answer_text: str) -> Tuple[str, bool]:
    """T18 — cap response to 1024 bytes; if longer, trim + append the
    expand suffix."""
    encoded = answer_text.encode("utf-8")
    if len(encoded) <= _DEFAULT_LENGTH_CAP_BYTES:
        return answer_text, False
    # Trim to byte boundary, decoding safely (avoid splitting a multi-
    # byte char). Keep ~970 bytes, leave room for the suffix.
    suffix = "\n\n_(want me to expand on a citation?)_"
    suffix_bytes = suffix.encode("utf-8")
    keep = _DEFAULT_LENGTH_CAP_BYTES - len(suffix_bytes)
    truncated = encoded[:keep]
    # Decode, ignoring any partial multi-byte char at the boundary
    text = truncated.decode("utf-8", errors="ignore")
    return text + suffix, True


def _detect_ambiguity_marker(answer_text: str) -> Optional[str]:
    """T20 best-effort — if the AI's answer contains shape that looks
    like multi-answer surfacing, mark it. Heuristic only."""
    # Heuristic: count distinct [[…]] cites; if 2+ AND prose contains
    # disambiguation phrasing, mark as multi-answer.
    cites = set(_WIKI_LINK_RE.findall(answer_text))
    if len(cites) < 2:
        return None
    lower = answer_text.lower()
    cues = ["which do you mean", "two answers", "two candidates", "which one"]
    if any(cue in lower for cue in cues):
        return "multi-answer"
    return None


# ─── Cache I/O ───────────────────────────────────────────────────────
def _cache_path(project_root: str) -> str:
    return os.path.join(project_root, ".sdd", ".cache", "synthesis.json")


def _load_synthesis_cache(project_root: str) -> Dict[str, Any]:
    p = _cache_path(project_root)
    if os.path.isfile(p):
        try:
            with open(p, encoding="utf-8") as f:
                data = json.load(f)
            if data.get("version") == _CACHE_VERSION:
                return data
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            pass
    return {"version": _CACHE_VERSION, "entries": {}}


def _save_synthesis_cache(project_root: str, cache: Dict[str, Any]) -> None:
    """Atomic write — tempfile + os.replace, same pattern as v1.0
    graph cache. Failure is logged but doesn't propagate to the caller
    (T20 — disk failure shouldn't block returning the answer)."""
    p = _cache_path(project_root)
    cache_dir = os.path.dirname(p)
    try:
        os.makedirs(cache_dir, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=".synthesis.tmp.", dir=cache_dir)
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(cache, fh, ensure_ascii=False, separators=(",", ":"))
        os.replace(tmp, p)
    except OSError as e:
        import sys
        print(f"[tier3-warning] cache write failed: {e}", file=sys.stderr)
        with contextlib.suppress(OSError):
            os.unlink(tmp)


def _evict_lru_if_full(cache: Dict[str, Any]) -> None:
    """T28 — when entries exceed _CACHE_MAX_ENTRIES, evict the
    least-recently-touched ones until we're back to the cap."""
    entries = cache.get("entries") or {}
    if len(entries) <= _CACHE_MAX_ENTRIES:
        return
    # Sort by touched_at ascending; evict from the front.
    sorted_keys = sorted(entries.keys(), key=lambda k: entries[k].get("touched_at", 0))
    over = len(entries) - _CACHE_MAX_ENTRIES
    for k in sorted_keys[:over]:
        del entries[k]


# ─── Renderers (T11 / T12) ───────────────────────────────────────────
def _render(entry: Dict[str, Any], fmt: str) -> Dict[str, Any]:
    """Wrap a successful entry into the format the caller asked for."""
    base = {
        "ok": True,
        "answer": entry.get("answer"),
        "cite_chunks": entry.get("cite_chunks", []),
        "ambiguity": entry.get("ambiguity"),
    }
    if fmt == "prose":
        # Prose path — same data, marker so callers can branch on it.
        base["format"] = "prose"
    else:
        base["format"] = "structured"
    return base


# ─── Real LLM call (T24 — production Ollama; placeholder until then) ─
class _ProviderUnreachable(RuntimeError):
    pass


class _ProviderRateLimited(RuntimeError):
    pass


def _real_llm_call(question: str, chunks: List[Dict[str, Any]], cfg: Dict[str, Any]) -> str:
    """Production LLM call — Ollama HTTP. Wired in T24.

    Until T24 lands, this raises so test paths that don't inject a
    mock get a clear signal that production wiring isn't done.
    """
    raise NotImplementedError(
        "Real Ollama HTTP call is wired in T24 (live integration). "
        "Tests should inject _llm_call=<mock> to exercise the surrounding flow."
    )
