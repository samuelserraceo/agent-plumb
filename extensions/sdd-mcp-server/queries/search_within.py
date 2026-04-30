"""search_within — semantic search bounded to a graph subset.

Tier 2b: same embedding pipeline as `search`, but the candidate chunks are
filtered to files within `depth` hops of `slug`. Higher precision than
top-K across the whole .sdd/ when the user knows roughly where to look.

Args:
    slug: anchor node (feature folder or notebook entry slug)
    query: natural-language query
    depth: 1, 2, or 3 (default 1; >3 silently capped)
    top_k: how many results to return (default 5)

Returns on success:
    {
        "slug": "<resolved>",
        "query": "...",
        "subgraph": {"files_searched": [...], "depth": N},
        "matches": [{path, snippet, score, start_line, end_line}, ...],
        "stats": {"chunks_searched": N, "from_cache": M, "embedded_this_run": K}
    }

Errors mirror `get_neighbours` for slug resolution and `search` for
embedding failures.
"""

from __future__ import annotations

import os
from typing import Any, Dict, List, Set

from . import _graph_cache
# NOTE: cannot use `from . import search as _search_module` here because
# __init__.py re-exports the `search` function under the same name as the
# submodule, shadowing the module in the package namespace. importlib gets
# the underlying module reliably regardless of __init__.py re-exports.
import importlib
_search_module = importlib.import_module(__package__ + ".search")


def search_within(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    slug = (args or {}).get("slug")
    if not slug or not isinstance(slug, str):
        return {"error": "missing arg 'slug'"}
    query = (args or {}).get("query")
    if not query or not isinstance(query, str):
        return {"error": "missing arg 'query'"}

    requested_depth = (args or {}).get("depth", 1)
    if not isinstance(requested_depth, int) or requested_depth < 1:
        requested_depth = 1
    depth = min(requested_depth, 3)

    graph = _graph_cache.load(project_root)
    root = _graph_cache.find_node(graph, slug)
    if root is None:
        return {
            "error": f"slug not found: {slug!r}",
            "slug": slug,
            "available": _graph_cache.list_nodes(graph)[:30],
        }

    # CR Major #4 fix — slug-scoped BFS, not path-scoped.
    #
    # Path-scoped BFS over-collects when the seed is a notebook heading
    # (pattern / entity / decision): every heading inside `patterns.md`
    # shares the path `.sdd/patterns.md`, so the BFS would expand the
    # same set of files for every pattern slug. The query advertised
    # node-level precision but delivered file-level precision.
    #
    # Approach: walk the slug graph (wiki-link edges, slug-keyed). Map
    # each visited slug to its node's file path; that's the allowlist.
    # File-level md-link edges are added at the end as "also includes",
    # so the search isn't artificially narrow either.
    edges = graph.get("edges", [])
    by_slug = {n["slug"]: n for n in graph.get("nodes", [])}

    visited_slugs: Set[str] = {root["slug"]}
    frontier_slugs: Set[str] = {root["slug"]}
    for _ in range(depth):
        next_frontier: Set[str] = set()
        for edge in edges:
            if not edge.get("resolved") or edge.get("kind") != "wiki-link":
                continue
            from_slug = _slug_for_from_path(graph, edge["from_path"])
            to_slug = edge.get("to_slug")
            if not to_slug:
                continue
            if from_slug in frontier_slugs and to_slug not in visited_slugs:
                visited_slugs.add(to_slug)
                next_frontier.add(to_slug)
            elif to_slug in frontier_slugs and from_slug and from_slug not in visited_slugs:
                visited_slugs.add(from_slug)
                next_frontier.add(from_slug)
        frontier_slugs = next_frontier
        if not frontier_slugs:
            break

    # Translate slugs back to file paths for the search allowlist. Always
    # include the root's path (the seed file is searched even at depth 0).
    paths: Set[str] = {root["path"]}
    for s in visited_slugs:
        n = by_slug.get(s)
        if n and n.get("path"):
            paths.add(n["path"])
    # Add file-level md-links that touch any of the collected files.
    for edge in edges:
        if not edge.get("resolved") or edge.get("kind") != "md-link":
            continue
        from_p = edge.get("from_path")
        to_p = edge.get("to_path")
        if to_p in paths and from_p:
            paths.add(from_p)
        if from_p in paths and to_p:
            paths.add(to_p)

    # Normalise paths to absolute for the search module's path filter.
    abs_paths = {os.path.normpath(os.path.join(project_root, p)) for p in paths}

    # Delegate to the existing search.py — pass the path filter via args.
    # search.py doesn't accept a path filter today, so we use a small
    # work-around: temporarily monkey-patch its file walker. Cleaner long
    # term is to add a `path_allowlist` arg to search.py; for v1.0 this
    # internal-only call site is acceptable.
    # Read top_k from args; default to 5.
    sub_args = {
        "query": query,
        "top_k": (args or {}).get("top_k", 5),
        # Internal-only hint: search.py honours this when present.
        "_path_allowlist": sorted(abs_paths),
    }
    result = _search_module.search(project_root, sub_args)

    # Augment result with subgraph metadata so caller knows what was searched.
    if "matches" in result:
        result["slug"] = root["slug"]
        result["subgraph"] = {
            "files_searched": sorted(paths),
            "slugs_visited": sorted(visited_slugs),
            "depth": depth,
        }
    return result


def _slug_for_from_path(graph: Dict[str, Any], path: str) -> str:
    """Reverse-lookup: which feature owns `path`? Notebook files have many
    headings but no single owning slug, so we use the basename."""
    for n in graph.get("nodes", []):
        if n.get("path") == path and n.get("kind") == "feature":
            return n["slug"]
    return os.path.splitext(os.path.basename(path))[0]
