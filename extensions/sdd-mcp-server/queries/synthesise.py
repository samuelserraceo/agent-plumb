"""Tier 3 LLM-driven synthesis — stub (T1 scaffold).

This is the v1.1 Tier 3 query that takes a slug + question + format
and returns a synthesised answer with cited corpus chunks. The full
spec is at .sdd/features/001-tier-3-llm-driven-synthesis/spec.md.

Build sequence (per §14 plan-decompose):
  T1 (this file)       — scaffold + registry entry; stub returns
                          {ok: False, reason: "not implemented"}
  T5 onwards           — replace the stub body with the real flow:
                          retrieval → AI call → cite-check → cache write

Until T5 lands, callers (the agent's MCP query path; the /ask slash
command wrapper) get the sentinel below so Tier 3 not-being-wired
fails closed with a clear message rather than crashing the framework.

Per CLAUDE.md test-first discipline:
  - Every BUILD task lands a test FIRST that fails RED, then code,
    then GREEN. T1's test is at tests/test_synthesise_scaffold.py.
"""

from __future__ import annotations

from typing import Any, Dict


def synthesise(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    """Tier 3 synthesis stub — returns the not-implemented sentinel.

    Args:
        project_root: absolute path to the SDD project root (the
            directory containing the `.sdd/` tree). Will be used by
            T5+ to locate the corpus + graph cache.
        args: per-query argument dict. Future shape (per §6 data
            contract): `slug`, `question` (optional), `format`
            ("structured" | "prose"). Ignored in T1 stub.

    Returns:
        Canonical not-implemented response. Future shape (per §5
        flow + §6 data contract):
            {answer, cite_chunks, ambiguity, ok, reason?}
    """
    return {"ok": False, "reason": "not implemented"}
