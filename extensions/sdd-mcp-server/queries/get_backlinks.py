"""get_backlinks — what cites a given node.

Tier 1 graph traversal: free, deterministic, no LLM. The single most-asked
question in a mature SDD project ("what features rely on this pattern?")
goes from grep + scan + guess to a single query.

Args:
    slug: the node to find inbound edges for. Accepts the bare slug
          (e.g. "auth-retry-logic") or the qualified form (e.g.
          "pattern:auth-retry-logic"). Bare slug uses the 4-tier
          resolution priority (filename > pattern > entity > decision).

Returns on success:
    {
        "slug": "<resolved slug>",
        "node": {path, kind, ...},
        "backlinks": [
            {from_path, from_line, kind: "wiki-link" | "md-link"},
            ...
        ],
        "stats": {"count": N}
    }

Errors:
    {"error": "missing arg 'slug'"}
    {"error": "slug not found", "slug": "<input>",
     "available": [{slug, path, kind}, ...]}
"""

from __future__ import annotations

from typing import Any, Dict

from . import _graph_cache


def get_backlinks(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    slug = (args or {}).get("slug")
    if not slug or not isinstance(slug, str):
        return {"error": "missing arg 'slug'"}

    graph = _graph_cache.load(project_root)
    node = _graph_cache.find_node(graph, slug)
    if node is None:
        return {
            "error": f"slug not found: {slug!r}",
            "slug": slug,
            "available": _graph_cache.list_nodes(graph)[:30],  # cap to avoid huge errors
        }

    target_slug = node["slug"]
    target_path = node["path"]
    target_kind = node["kind"]
    backlinks = []
    for edge in graph.get("edges", []):
        if not edge.get("resolved"):
            continue
        # Wiki-link edges resolve to a specific node (by slug). These are the
        # primary backlinks regardless of the target's kind.
        if edge.get("to_slug") == target_slug:
            backlinks.append({
                "from_path": edge["from_path"],
                "from_line": edge["from_line"],
                "kind": edge["kind"],
            })
            continue
        # CR Major #2 fix — md-link edges target a file path, not a heading.
        # Only attribute md-links as backlinks when the target node IS the
        # file (kind == "feature"; the spec.md is the only thing the file
        # represents). Notebook nodes (pattern / entity / decision) are
        # heading-level; an md-link to `.sdd/patterns.md` cites the file
        # generically, not any specific heading inside it. Counting it as a
        # backlink for every heading would overcount and let drift slip
        # past invariant 8 ("link to patterns.md" looks resolved even when
        # the cited heading was renamed).
        if (edge.get("kind") == "md-link"
                and edge.get("to_path") == target_path
                and target_kind == "feature"):
            backlinks.append({
                "from_path": edge["from_path"],
                "from_line": edge["from_line"],
                "kind": edge["kind"],
            })

    return {
        "slug": target_slug,
        "node": {
            "path": target_path,
            "kind": node["kind"],
            **({"heading": node["heading"]} if "heading" in node else {}),
            **({"line": node["line"]} if "line" in node else {}),
        },
        "backlinks": backlinks,
        "stats": {"count": len(backlinks)},
    }
