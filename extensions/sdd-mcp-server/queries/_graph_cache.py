"""Graph cache — derived index of wiki-links across .sdd/ markdown.

The markdown content is the source of truth. This cache is a 1:1 derivation
that any walker could reproduce from markdown alone — exists purely to make
backlink lookups fast on large projects (a 50-feature project would otherwise
eat ~200ms scanning every file on every Tier 1 query).

Cache discipline (matches the embedding-cache pattern from search.py):
- `source_signature` = sha256 of every markdown file's content concatenated
  in sorted-path order. Cache invalidates if anything that could contain a
  wiki-link has changed.
- Atomic write (tempfile + os.replace).
- Cache lives at .sdd/.cache/graph.json and is .gitignored.
- Rebuilt lazily by the first query that needs it in a given turn — no
  background daemon, no separate build step.

Wiki-link grammar (REFUSED if extended — keeps the graph stable):
- `[[001-waitlist]]` → feature folder
- `[[entity:User]]` → data-model.md entity
- `[[pattern:auth-retry-logic]]` → patterns.md heading
- NO section anchors (`[[file#section]]`)
- NO display aliases (`[[target|display]]`)

Slug resolution (4-tier priority — first match wins):
1. Exact filename match (feature folder under .sdd/features/)
2. Pattern slug (slugified H3 in .sdd/patterns.md)
3. Data-model entity slug (slugified H2/H3 in .sdd/data-model.md)
4. Decision slug (slugified heading in .sdd/decisions.md)

Path-form `[text](relative/path.md)` is also recognised when the path
resolves under .sdd/. Cross-file slug collisions are NOT ambiguous
(different files = different nodes); same-priority same-slug IS.
"""

from __future__ import annotations

import contextlib
import hashlib
import json
import os
import re
import tempfile
from typing import Any, Dict, List, Optional, Tuple


_CACHE_VERSION = 3  # bumped — node set now includes bug + refactor work-item slugs (was features-only); v2 caches must regenerate

# Files under these subdirs aren't part of the searchable graph (agent-internal,
# template scaffolds, gitignored).
_EXCLUDED_DIRS = {".cache", "archive", "ideas", "_template"}

# Wiki-link pattern. Refuses anchors and aliases by construction:
# `[[slug]]` only, where slug is `<chars>` or `<prefix>:<chars>` with no `|` or `#`.
_WIKI_LINK_RE = re.compile(r"\[\[([a-z0-9][a-z0-9._:\-]*)\]\]", re.IGNORECASE)

# Markdown-link pattern, used for graph edges that point at .md files explicitly.
# Captures: link text, path. Anchor (#…) optional but ignored by the graph.
_MD_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s#]+\.md)(?:#[^)]*)?\)")

# Heading patterns for nodes the graph recognises as targets.
_H_RE = re.compile(r"^(#{2,6})\s+(.+?)\s*$")


def _slugify(text: str) -> str:
    """Same algorithm `get_pattern.py` uses: lowercase, non-alphanum → hyphens."""
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s


def _cache_path(project_root: str) -> str:
    return os.path.join(project_root, ".sdd", ".cache", "graph.json")


def _walk_markdown(project_root: str) -> List[str]:
    """Return absolute paths of every .md file under .sdd/ that participates
    in the graph (excludes .cache/, archive/, ideas/, _template/)."""
    sdd_root = os.path.join(project_root, ".sdd")
    if not os.path.isdir(sdd_root):
        return []
    paths: List[str] = []
    for dirpath, dirnames, filenames in os.walk(sdd_root):
        dirnames[:] = [d for d in dirnames if d not in _EXCLUDED_DIRS]
        for fn in filenames:
            if fn.endswith(".md"):
                paths.append(os.path.join(dirpath, fn))
    paths.sort()
    return paths


def _file_signature(project_root: str, paths: List[str]) -> str:
    """Hash of all (relative_path + content) tuples.

    Invalidates the cache when:
    - any file's content changes
    - a file is added or removed
    - a feature folder is renamed (path changes even though content doesn't —
      CR Major #1 fix; rename `.sdd/features/001-waitlist/` to
      `.sdd/features/001-signup/` and the slug-resolution graph changes
      without any content edit)

    Path is hashed before content with a NUL separator so a path-only change
    invalidates the signature even if the file's bytes are byte-identical to
    a different file's bytes.
    """
    h = hashlib.sha256()
    for p in paths:
        # Hash the relative path first so a folder rename invalidates the
        # cache even when content is unchanged.
        rel = os.path.relpath(p, project_root).replace(os.sep, "/")
        h.update(rel.encode("utf-8"))
        h.update(b"\x00")
        try:
            with open(p, "rb") as f:
                h.update(f.read())
            h.update(b"\x00")
        except OSError:
            continue
    return h.hexdigest()


def _build_nodes_and_edges(project_root: str, paths: List[str]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Walk markdown, extract nodes (slugs) and edges (wiki-links + md-links).

    A node is a place the graph can point AT:
    - Each feature folder (slug = folder name under .sdd/features/)
    - Each H2/H3 heading in patterns.md / data-model.md / decisions.md

    An edge is a place the graph points FROM:
    - Every `[[slug]]` occurrence in any markdown file
    - Every `[text](relative/path.md)` whose path resolves under .sdd/
    """
    nodes: List[Dict[str, Any]] = []
    edges: List[Dict[str, Any]] = []
    sdd_root = os.path.join(project_root, ".sdd")

    # Collect work-item folder nodes (priority 1) — features, bugs,
    # refactors. Each work-item folder is keyed by its slug; the kind
    # tag carries which playbook produced it. v1.0 added bug + refactor
    # playbooks alongside feature; this resolver was originally
    # features-only and silently dropped bugs/refactors slugs (caught
    # in INDEX.md after the first SDD-shipped bug landed — bugs/001).
    work_item_roots = {
        "features": "feature",
        "bugs": "bug",
        "refactors": "refactor",
    }
    for sub, kind in work_item_roots.items():
        root = os.path.join(sdd_root, sub)
        if not os.path.isdir(root):
            continue
        for entry in sorted(os.listdir(root)):
            full = os.path.join(root, entry)
            if os.path.isdir(full) and not entry.startswith("_") and not entry.startswith("."):
                nodes.append({
                    "slug": entry,
                    "kind": kind,
                    "path": os.path.relpath(os.path.join(full, "spec.md"), project_root),
                    "priority": 1,
                })

    # Collect heading nodes from the four well-known notebook files.
    notebook_files = {
        os.path.join(sdd_root, "patterns.md"): ("pattern", 2),
        os.path.join(sdd_root, "data-model.md"): ("entity", 3),
        os.path.join(sdd_root, "decisions.md"): ("decision", 4),
    }
    for nb_path, (kind, prio) in notebook_files.items():
        if not os.path.isfile(nb_path):
            continue
        try:
            with open(nb_path, encoding="utf-8") as f:
                lines = f.read().split("\n")
        except (OSError, UnicodeDecodeError):
            # CR cycle-9 — corrupted / non-UTF-8 notebook files are skipped
            # rather than crashing the whole graph build.
            continue
        for i, line in enumerate(lines, start=1):
            m = _H_RE.match(line)
            if not m:
                continue
            level = len(m.group(1))
            heading = m.group(2).strip()
            if level not in (2, 3):
                continue
            slug = _slugify(heading)
            if not slug:
                continue
            nodes.append({
                "slug": slug,
                "kind": kind,
                "path": os.path.relpath(nb_path, project_root),
                "heading": heading,
                "level": level,
                "line": i,
                "priority": prio,
            })

    # Build a slug → primary-node map for resolving wiki-links during edge
    # extraction. Lower priority wins (= higher precedence).
    #
    # CR cycle-7 Major — same-priority same-slug collisions used to bind
    # to whichever node appeared first in walk order. The doctrine says
    # they're ambiguous and should fail invariant 8. Track collisions
    # explicitly; mark the slug as ambiguous (None) so wiki-links pointing
    # at it surface as broken edges rather than silently picking one
    # candidate at random.
    by_slug: Dict[str, Optional[Dict[str, Any]]] = {}
    ambiguous: set = set()
    for n in nodes:
        slug = n["slug"]
        keys = [slug]
        # Prefixed forms: `pattern:auth-retry`, `entity:user`.
        if n["kind"] in ("pattern", "entity", "decision"):
            keys.append(f"{n['kind']}:{slug}")
        for key in keys:
            existing = by_slug.get(key)
            if existing is None:
                by_slug[key] = n
            elif n["priority"] < existing["priority"]:
                # New node has higher precedence; takes the slot. Drop any
                # previous ambiguity flag — the higher-priority node wins
                # cleanly even if there were lower-priority collisions.
                by_slug[key] = n
                ambiguous.discard(key)
            elif n["priority"] == existing["priority"]:
                # Same-priority collision — ambiguous per doctrine.
                ambiguous.add(key)
    # Mark ambiguous keys as unresolved so wiki-links to them break
    # invariant 8 instead of silently binding to one of the candidates.
    for key in ambiguous:
        by_slug[key] = None

    # CR cycle-9 — pre-compute per-path indices so each edge can carry a
    # stable `from_slug` (the heading-aware slug of the node that owns the
    # source line, NOT a synthetic file-level placeholder). This stops BFS
    # in get_neighbours / search_within from polluting the frontier with
    # `_file:patterns`-style synthetic tokens.
    _feature_path_to_slug: Dict[str, str] = {
        n["path"]: n["slug"] for n in nodes if n.get("kind") == "feature"
    }
    _headings_by_path: Dict[str, List[Tuple[int, str, str]]] = {}
    for n in nodes:
        if "line" not in n:
            continue
        _headings_by_path.setdefault(n["path"], []).append(
            (n["line"], n["slug"], n["kind"])
        )
    for _p in _headings_by_path:
        _headings_by_path[_p].sort()

    def _resolve_from(rel_path: str, line_no: int) -> Tuple[Optional[str], str]:
        """Return (slug, kind) of the node that owns this (path, line),
        or (None, 'file') for orphan content (text before the first heading
        in a notebook file, or a non-feature/non-notebook file)."""
        if rel_path in _feature_path_to_slug:
            return (_feature_path_to_slug[rel_path], "feature")
        headings = _headings_by_path.get(rel_path, [])
        best: Optional[Tuple[str, str]] = None
        for h_line, h_slug, h_kind in headings:
            if h_line <= line_no:
                best = (h_slug, h_kind)
            else:
                break
        if best is None:
            return (None, "file")
        return best

    # Inline-code span pattern. CR cycle-2/3 — the original `[^`\n]*` form
    # only handled SINGLE-backtick spans, so a multi-backtick form like
    # ``[[pattern:fake]]`` (used to embed text containing backticks)
    # leaked wiki-links straight into the graph.
    #
    # CommonMark inline code spans use 1-N backticks as delimiter; the
    # closer must match the opener exactly. Match a run of N backticks,
    # then any non-newline content that doesn't contain that exact run,
    # then the same N-backtick closer. Greedy-match all four shapes
    # (1, 2, 3, 4 backticks) — covers every real-world inline use.
    _INLINE_CODE_RE = re.compile(
        r"(`{4})(?:(?!\1).)+\1"
        r"|(`{3})(?:(?!\2).)+\2"
        r"|(`{2})(?:(?!\3).)+\3"
        r"|`[^`\n]+`"
    )

    # CommonMark §6.1 also allows backtick spans to cross newlines.
    # The single-line regex above stops at `\n` (correct for line-by-line
    # walking), but that misses spans where the closing backtick is on a
    # later line. Closes #105.
    #
    # `[\s\S]` matches anything including newlines (re.DOTALL would
    # affect the whole pattern, including the inner negative lookahead
    # which we don't want). Match the longest backtick run first (4, 3,
    # 2, 1) so a 4-tick fence-style span isn't ended early by an inner
    # 3-tick run.
    _INLINE_CODE_MULTILINE_RE = re.compile(
        r"(`{4})(?:(?!\1)[\s\S])+\1"
        r"|(`{3})(?:(?!\2)[\s\S])+\2"
        r"|(`{2})(?:(?!\3)[\s\S])+\3"
        r"|`[^`]+`"
    )

    def _mask_inline_code_in_content(content: str) -> str:
        """Replace inline-code spans (single OR multi-line) with same-
        length whitespace BUT preserve newline characters within each
        span — so the line-by-line walker downstream sees the right
        line numbers. Closes #105.

        Same masking discipline as `_strip_inline_code`: replace, don't
        delete (otherwise `[[pa\`code\`tt]]` would synthesize a
        spurious `[[patt]]` match).
        """
        def _mask(m: "re.Match[str]") -> str:
            span = m.group()
            return "".join(c if c == "\n" else " " for c in span)
        return _INLINE_CODE_MULTILINE_RE.sub(_mask, content)

    def _strip_inline_code(line: str) -> str:
        """Mask `inline code` spans (any backtick count) with same-length
        whitespace so wiki-link / md-link regex matchers won't pick them
        up — but won't bridge non-code chars across deletions either.

        CR cycle-4 fix: a naive `.sub("", line)` *deletes* the matched
        span, which can synthesize a spurious match. Example: the markdown
        `[[pa\`code\`tt]]` becomes `[[patt]]` after deletion — a wiki-link
        that never existed in the source. Replacing with same-length
        whitespace preserves character positions so the wiki-link regex
        can never match across a stripped span.

        Note: this is the LINE-LEVEL pass that runs after
        `_mask_inline_code_in_content` (which handles multi-line spans
        on the full content). Single-line spans within one logical line
        still need to be masked here because the multi-line pass
        deliberately leaves newlines in place; an inline span starting
        and ending on the same line within a multi-line file is
        equally well caught by either pass."""
        return _INLINE_CODE_RE.sub(lambda m: " " * len(m.group()), line)

    # Fence delimiter pattern. CR cycle-2/3 — earlier code only tracked
    # the FIRST character (` or ~) so the inner triple-backtick line in
    # a 4-backtick fence (a common docs pattern when showing fenced-
    # markdown examples) closed the outer block prematurely. CommonMark
    # actually requires the closer to use the same character AND at
    # least as many of them; we match by the full run length.
    _FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})")

    def _fenced_line_set(text: str) -> set:
        """Return the set of 1-based line numbers that fall inside a fenced
        code block. Tracks the full fence delimiter (character + length)
        so a ```` outer fence can wrap an inner ``` example without the
        inner closer cutting the outer block short.

        Same fence-tracking discipline `get_pattern.py`'s `_walk_headings`
        already uses, but length-aware.
        """
        inside: set = set()
        in_fence = False
        fence_delim = None  # the exact delimiter run that opened the block
        for idx, line in enumerate(text.split("\n"), start=1):
            m = _FENCE_RE.match(line)
            if m:
                run = m.group(1)
                # CR cycle-3 fence-suffix check — per CommonMark §4.5, an
                # opening fence may carry an info string (e.g. ``` python),
                # but a CLOSING fence must have only optional whitespace
                # after the delimiter. Without this check, a line like
                # ``` python (which is a NEW opening) would be mistaken
                # for a closer when one is already open, prematurely
                # ending the block.
                suffix = line[m.end():]
                if not in_fence:
                    in_fence = True
                    fence_delim = run
                elif (
                    run[0] == fence_delim[0]
                    and len(run) >= len(fence_delim)
                    and suffix.strip() == ""
                ):
                    # Closer must use the same fence char AND be at least
                    # as long as the opener AND have no info string after
                    # the delimiter (CommonMark §4.5).
                    in_fence = False
                    fence_delim = None
                # Fence delimiters themselves aren't "inside the fence" —
                # but they're not edge content either. Treat them as fence
                # so wiki-links accidentally on the same line as a fence
                # delimiter don't slip through.
                inside.add(idx)
                continue
            if in_fence:
                inside.add(idx)
        return inside

    # Walk every markdown file for outgoing edges.
    for src_path in paths:
        try:
            with open(src_path, encoding="utf-8") as f:
                content = f.read()
        except (OSError, UnicodeDecodeError):
            # CR cycle-9 — same defensive skip as notebook reads above.
            continue
        rel_src = os.path.relpath(src_path, project_root)
        # v1.0 step 4 — pre-compute fenced-line set so the link extractors
        # below skip wiki-links and md-links inside ``` / ~~~ code blocks.
        # Without this, every documentation example showing wiki-link
        # syntax (in CLAUDE.md, action prose, etc.) gets walked as a real
        # edge and trips invariant 8 / the CI graph-integrity gate.
        fenced_lines = _fenced_line_set(content)
        # Closes #105 — pre-mask MULTI-LINE inline-code spans on the full
        # content first. The line-by-line walker below can't see a span
        # that crosses newlines (CommonMark §6.1 allows them), so a
        # backtick that opens on line 5 and closes on line 7 would let
        # any `[[…]]` between them be walked as a real edge. Masking on
        # the full content with newlines preserved means line numbers
        # downstream stay correct.
        masked_content = _mask_inline_code_in_content(content)
        # Wiki-link edges. Normalise to lowercase for lookup so `[[Entity:User]]`
        # and `[[entity:user]]` both resolve to the same node.
        # v1.0 step 4 — walk line-by-line so we can strip inline `code`
        # spans before regex matching. Wiki-links inside inline code are
        # documentation examples (e.g. `[[entity:User]]` in prose), not
        # real edges.
        for line_no, raw_line in enumerate(masked_content.split("\n"), start=1):
            if line_no in fenced_lines:
                continue
            stripped_line = _strip_inline_code(raw_line)
            # Wiki-link edges on this line.
            for m in _WIKI_LINK_RE.finditer(stripped_line):
                slug = m.group(1).lower()
                target = by_slug.get(slug)  # may be None if slug is ambiguous
                from_slug, from_kind = _resolve_from(rel_src, line_no)
                edge = {
                    "from_path": rel_src,
                    "from_line": line_no,
                    "from_slug": from_slug,
                    "from_kind": from_kind,
                    "raw": slug,
                    "kind": "wiki-link",
                }
                if target is None:
                    edge["to_slug"] = None
                    edge["resolved"] = False
                else:
                    edge["to_slug"] = target["slug"]
                    edge["to_path"] = target["path"]
                    edge["to_kind"] = target["kind"]
                    edge["resolved"] = True
                edges.append(edge)
            # Markdown-link edges on this line (also fence- and inline-code-aware
            # via the same stripped_line).
            for m in _MD_LINK_RE.finditer(stripped_line):
                link_path = m.group(2)
                base = os.path.dirname(src_path)
                target_abs = os.path.normpath(os.path.join(base, link_path))
                if not target_abs.startswith(sdd_root + os.sep) and target_abs != sdd_root:
                    continue
                target_rel = os.path.relpath(target_abs, project_root)
                edges.append({
                    "from_path": rel_src,
                    "from_line": line_no,
                    "to_path": target_rel,
                    "kind": "md-link",
                    "resolved": os.path.exists(target_abs),
                })
        # (Wiki-link AND md-link extraction now happens inside the
        # line-by-line walk above so both share the fenced-block and
        # inline-code skip logic.)

    return nodes, edges


def build(project_root: str) -> Dict[str, Any]:
    """Build the graph from scratch (don't read or write the cache).
    Returns a dict with `nodes`, `edges`, `source_signature`."""
    paths = _walk_markdown(project_root)
    sig = _file_signature(project_root, paths)
    nodes, edges = _build_nodes_and_edges(project_root, paths)
    return {
        "version": _CACHE_VERSION,
        "source_signature": sig,
        "nodes": nodes,
        "edges": edges,
    }


def load(project_root: str) -> Dict[str, Any]:
    """Return the graph, using the cached copy if its source-signature still
    matches the disk. Builds fresh + writes cache otherwise."""
    paths = _walk_markdown(project_root)
    expected_sig = _file_signature(project_root, paths)
    cache_p = _cache_path(project_root)
    if os.path.isfile(cache_p):
        try:
            with open(cache_p, encoding="utf-8") as f:
                cached = json.load(f)
            if (cached.get("version") == _CACHE_VERSION
                    and cached.get("source_signature") == expected_sig):
                return cached
        except (OSError, json.JSONDecodeError):
            pass
    # Rebuild.
    graph = build(project_root)
    _save(project_root, graph)
    return graph


def _save(project_root: str, graph: Dict[str, Any]) -> None:
    cache_p = _cache_path(project_root)
    cache_dir = os.path.dirname(cache_p)
    os.makedirs(cache_dir, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".graph.tmp.", dir=cache_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(graph, fh, ensure_ascii=False, separators=(",", ":"))
        os.replace(tmp, cache_p)
    except Exception:
        with contextlib.suppress(OSError):
            os.unlink(tmp)
        raise


def find_node(graph: Dict[str, Any], slug: str) -> Optional[Dict[str, Any]]:
    """Return the unique highest-priority node matching `slug`, or None.

    Accepts both bare (`auth-retry-logic`) and qualified
    (`pattern:auth-retry-logic`) forms. Case-insensitive.

    CR cycle-8 — when MULTIPLE candidates tie at the same lowest priority,
    return None (ambiguous) rather than picking one at parse-order whim.
    Mirrors the same-priority collision rule that `_build_nodes_and_edges`
    enforces in its `by_slug` map: the doctrine says these are ambiguous,
    and lookups should surface that to the caller (which surfaces it to
    invariant 8) rather than silently binding."""
    needle = slug.lower()
    candidates = [
        n for n in graph.get("nodes", [])
        if n.get("slug", "").lower() == needle or _qualified(n).lower() == needle
    ]
    if not candidates:
        return None
    min_priority = min(n.get("priority", 99) for n in candidates)
    top = [n for n in candidates if n.get("priority", 99) == min_priority]
    if len(top) > 1:
        return None  # ambiguous — multiple same-priority candidates
    return top[0]


def _qualified(node: Dict[str, Any]) -> str:
    """Return the prefixed slug form for non-feature nodes."""
    kind = node.get("kind")
    if kind in ("pattern", "entity", "decision"):
        return f"{kind}:{node['slug']}"
    return node.get("slug", "")


def list_nodes(graph: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Return every node with its qualified slug."""
    return [{"slug": _qualified(n) or n["slug"], "path": n["path"], "kind": n["kind"]} for n in graph.get("nodes", [])]


def find_broken_edges(graph: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Return wiki-link and md-link edges that don't resolve to a known target."""
    return [e for e in graph.get("edges", []) if not e.get("resolved", False)]
