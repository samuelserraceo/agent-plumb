"""T1 — Scaffold test for the `synthesise` query (v1.1 Tier 3).

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_synthesise_scaffold

Asserts the scaffold contract from §14 plan-decompose:
  - synthesise function is importable from queries package
  - synthesise is registered in queries.REGISTRY
  - calling synthesise() with no args returns the canonical
    {ok: False, reason: "not implemented"} shape — the stub other
    BUILD tasks layer onto

This test stays mostly stable across BUILD; later tasks add asserts
to other test files for behaviour, but the scaffold contract here
remains valid (the stub is replaced with real behaviour by T5+ but
the import + registration always hold).
"""

from __future__ import annotations

import os
import sys
import unittest

# Make the parent directory importable so `from queries import ...` works
# regardless of how the test runner is invoked.
_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

import queries  # noqa: E402


class TestSynthesiseScaffold(unittest.TestCase):
    """The minimum scaffold that lets later BUILD tasks layer onto."""

    def test_synthesise_is_importable(self):
        """The synthesise function is importable from the queries package."""
        from queries import synthesise  # noqa: F401
        self.assertTrue(callable(synthesise))

    def test_synthesise_is_in_registry(self):
        """REGISTRY exposes synthesise so the MCP server can route to it."""
        self.assertIn("synthesise", queries.REGISTRY)
        self.assertIs(queries.REGISTRY["synthesise"], queries.synthesise)

    def test_stub_returns_not_implemented_shape(self):
        """Calling the stub returns {ok: False, reason: 'not implemented'}.

        Later tasks (T5 onwards) replace this body with the real
        synthesis behaviour. Until then, the stub returns the
        documented sentinel so callers (the agent, the /ask slash
        command) can detect Tier 3 isn't wired yet without crashing.
        """
        result = queries.synthesise(project_root=".", args={})
        self.assertIsInstance(result, dict)
        self.assertIs(result.get("ok"), False)
        self.assertEqual(result.get("reason"), "not implemented")
