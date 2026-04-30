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


_CACHE_VERSION = 1

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

    # Collect feature folder nodes (priority 1).
    features_root = os.path.join(sdd_root, "features")
    if os.path.isdir(features_root):
        for entry in sorted(os.listdir(features_root)):
            full = os.path.join(features_root, entry)
            if os.path.isdir(full) and not entry.startswith("_") and not entry.startswith("."):
                nodes.append({
                    "slug": entry,
                    "kind": "feature",
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
        except OSError:
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
    by_slug: Dict[str, Dict[str, Any]] = {}
    for n in nodes:
        slug = n["slug"]
        # Prefixed forms: `pattern:auth-retry`, `entity:user`.
        if n["kind"] in ("pattern", "entity", "decision"):
            prefixed = f"{n['kind']}:{slug}"
            existing = by_slug.get(prefixed)
            if existing is None or n["priority"] < existing["priority"]:
                by_slug[prefixed] = n
        # Bare slug — first match by priority wins.
        existing = by_slug.get(slug)
        if existing is None or n["priority"] < existing["priority"]:
            by_slug[slug] = n

    # Walk every markdown file for outgoing edges.
    for src_path in paths:
        try:
            with open(src_path, encoding="utf-8") as f:
                content = f.read()
        except OSError:
            continue
        rel_src = os.path.relpath(src_path, project_root)
        # Wiki-link edges. Normalise to lowercase for lookup so `[[Entity:User]]`
        # and `[[entity:user]]` both resolve to the same node.
        for m in _WIKI_LINK_RE.finditer(content):
            slug = m.group(1).lower()
            target = by_slug.get(slug)
            line_no = content[:m.start()].count("\n") + 1
            edge = {
                "from_path": rel_src,
                "from_line": line_no,
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
        # Markdown-link edges (only when target path resolves under .sdd/).
        for m in _MD_LINK_RE.finditer(content):
            link_path = m.group(2)
            base = os.path.dirname(src_path)
            target_abs = os.path.normpath(os.path.join(base, link_path))
            if not target_abs.startswith(sdd_root + os.sep) and target_abs != sdd_root:
                continue
            line_no = content[:m.start()].count("\n") + 1
            target_rel = os.path.relpath(target_abs, project_root)
            edges.append({
                "from_path": rel_src,
                "from_line": line_no,
                "to_path": target_rel,
                "kind": "md-link",
                "resolved": os.path.exists(target_abs),
            })

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
    """Return the highest-priority node matching `slug`, or None.

    Accepts both bare (`auth-retry-logic`) and qualified (`pattern:auth-retry-logic`)
    forms. Case-insensitive."""
    needle = slug.lower()
    candidates = [
        n for n in graph.get("nodes", [])
        if n.get("slug", "").lower() == needle or _qualified(n).lower() == needle
    ]
    if not candidates:
        return None
    return min(candidates, key=lambda n: n.get("priority", 99))


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
