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
from . import search as _search_module


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

    # Collect the set of file paths in the depth-bounded subgraph. Always
    # include the root's own file. BFS over edges in both directions.
    paths: Set[str] = {root["path"]}
    frontier_paths: Set[str] = {root["path"]}
    edges = graph.get("edges", [])

    for _ in range(depth):
        next_frontier: Set[str] = set()
        for edge in edges:
            if not edge.get("resolved"):
                continue
            from_path = edge.get("from_path")
            to_path = edge.get("to_path")
            if from_path in frontier_paths and to_path and to_path not in paths:
                paths.add(to_path)
                next_frontier.add(to_path)
            if to_path in frontier_paths and from_path and from_path not in paths:
                paths.add(from_path)
                next_frontier.add(from_path)
        frontier_paths = next_frontier
        if not frontier_paths:
            break

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
            "depth": depth,
        }
    return result
