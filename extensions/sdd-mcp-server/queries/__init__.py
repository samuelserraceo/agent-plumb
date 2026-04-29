"""SDD MCP query layer.

Each query is a pure function: takes (project_root, args) -> dict.
project_root is the absolute path to the SDD project (the directory
that contains the `.sdd/` tree); args is the per-query argument
dict received over the wire.

Queries never raise on bad input — they return a result dict whose
shape is documented in docs/query-reference.md. A top-level `error`
key signals failure; everything else signals success.
"""

from .get_active_step import get_active_step
from .get_by_tag import get_by_tag
from .get_pattern import get_pattern
from .get_references import get_references
from .get_decisions_since import get_decisions_since
from .search import search

REGISTRY = {
    "get_active_step": get_active_step,
    "get_by_tag": get_by_tag,
    "get_pattern": get_pattern,
    "get_references": get_references,
    "get_decisions_since": get_decisions_since,
    "search": search,
}

__all__ = ["REGISTRY", *REGISTRY.keys()]
