"""get_neighbours — outgoing + incoming edges for a node.

Tier 1 graph traversal. Returns the 1-hop subgraph by default; `depth` can
extend up to 3 (silently capped). Useful for "what does this feature
depend on, and what depends on it" — a single call surfaces both sides.

Args:
    slug: the node (bare or qualified)
    depth: 1, 2, or 3 (default 1; >3 silently capped)

Returns on success:
    {
        "slug": "<resolved slug>",
        "node": {path, kind, ...},
        "outgoing": [{to_slug, to_path, to_kind, from_line, kind}, ...],
        "incoming": [{from_slug, from_path, from_line, kind}, ...],
        "depth": <effective depth>,
        "stats": {"outgoing_count": N, "incoming_count": M},
        "warning": "depth capped at 3" (only when relevant)
    }
"""

from __future__ import annotations

from typing import Any, Dict, List, Set

from . import _graph_cache


_MAX_DEPTH = 3


def get_neighbours(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    slug = (args or {}).get("slug")
    if not slug or not isinstance(slug, str):
        return {"error": "missing arg 'slug'"}

    requested_depth = (args or {}).get("depth", 1)
    if not isinstance(requested_depth, int) or requested_depth < 1:
        requested_depth = 1
    capped = requested_depth > _MAX_DEPTH
    depth = min(requested_depth, _MAX_DEPTH)

    graph = _graph_cache.load(project_root)
    root = _graph_cache.find_node(graph, slug)
    if root is None:
        return {
            "error": f"slug not found: {slug!r}",
            "slug": slug,
            "available": _graph_cache.list_nodes(graph)[:30],
        }

    # BFS up to `depth` hops. Track both outgoing and incoming separately.
    edges = graph.get("edges", [])
    out_edges: List[Dict[str, Any]] = []
    in_edges: List[Dict[str, Any]] = []
    seen_out: Set[str] = set()
    seen_in: Set[str] = set()

    frontier = {root["slug"]}
    for _ in range(depth):
        next_frontier: Set[str] = set()
        for edge in edges:
            if not edge.get("resolved"):
                continue
            from_slug = _slug_for_path(graph, edge["from_path"])
            to_slug = edge.get("to_slug")
            # Outgoing: edges whose source is in the current frontier.
            if from_slug in frontier and to_slug not in seen_out and to_slug != root["slug"]:
                out_edges.append({
                    "to_slug": to_slug,
                    "to_path": edge.get("to_path", ""),
                    "to_kind": edge.get("to_kind", ""),
                    "from_path": edge["from_path"],
                    "from_line": edge["from_line"],
                    "kind": edge["kind"],
                })
                seen_out.add(to_slug)
                next_frontier.add(to_slug)
            # Incoming: edges whose target is in the current frontier.
            if to_slug in frontier and from_slug and from_slug not in seen_in and from_slug != root["slug"]:
                in_edges.append({
                    "from_slug": from_slug,
                    "from_path": edge["from_path"],
                    "from_line": edge["from_line"],
                    "kind": edge["kind"],
                })
                seen_in.add(from_slug)
                next_frontier.add(from_slug)
        frontier = next_frontier
        if not frontier:
            break

    result: Dict[str, Any] = {
        "slug": root["slug"],
        "node": {
            "path": root["path"],
            "kind": root["kind"],
            **({"heading": root["heading"]} if "heading" in root else {}),
        },
        "outgoing": out_edges,
        "incoming": in_edges,
        "depth": depth,
        "stats": {
            "outgoing_count": len(out_edges),
            "incoming_count": len(in_edges),
        },
    }
    if capped:
        result["warning"] = f"depth capped at {_MAX_DEPTH} to bound output size"
    return result


def _slug_for_path(graph: Dict[str, Any], path: str) -> str:
    """Reverse-lookup: given a markdown file path, find which feature/notebook
    node 'owns' it. For feature spec.md files, that's the feature folder slug.
    For notebook files (patterns.md / data-model.md / decisions.md), use the
    file's basename without extension as a stable handle."""
    for n in graph.get("nodes", []):
        if n.get("path") == path and n.get("kind") == "feature":
            return n["slug"]
    # Notebook files don't have a single owning slug — they have many headings.
    # Use the bare filename (without .md) as a stable identifier so the caller
    # can at least see "an edge came from patterns.md".
    import os
    return os.path.splitext(os.path.basename(path))[0]
