"""T5 — Clean answer flow (the load-bearing honesty floor).

AC1: every `[[link]]` in a Tier 3 answer points at something real in
your project.

This test mocks the LLM provider to return canned text containing a
valid `[[…]]` citation — confirming the cite-check passes when all
links resolve, and the response shape is correct.

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_synthesise_clean_answer
"""

from __future__ import annotations

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries import synthesise  # noqa: E402

from tests.conftest import make_temp_project  # noqa: E402


def _mock_llm_clean(question, chunks, cfg):
    """Stand-in for the real Ollama call. Returns a canned answer with
    a single valid `[[001-waitlist]]` citation."""
    return (
        "The waitlist signup uses a single-page form writing to "
        "Postgres — see [[001-waitlist]]."
    )


class TestSynthesiseCleanAnswer(unittest.TestCase):
    """When the AI returns an answer with all citations resolving,
    synthesise() returns ok=True with the cited chunks."""

    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_clean_answer_returns_ok(self):
        """Happy path: answer with valid `[[001-waitlist]]` cite — ok=True."""
        result = synthesise(
            self.root,
            {
                "slug": "001-waitlist",
                "question": "how does the waitlist signup work?",
                "format": "structured",
            },
            _llm_call=_mock_llm_clean,
        )
        self.assertTrue(result.get("ok"),
                        msg=f"expected ok=True, got: {result}")
        self.assertIsNotNone(result.get("answer"))
        self.assertIn("Postgres", result["answer"])

    def test_cite_chunks_populated(self):
        """The response carries cite_chunks listing every resolved link."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "any q", "format": "structured"},
            _llm_call=_mock_llm_clean,
        )
        self.assertTrue(result.get("ok"))
        cite_chunks = result.get("cite_chunks") or []
        self.assertGreaterEqual(len(cite_chunks), 1,
                                msg="expected at least 1 cite_chunk")
        # Each cite_chunk has slug + path
        for cc in cite_chunks:
            self.assertIn("slug", cc)
            self.assertIn("path", cc)

    def test_cite_chunks_resolve_to_real_nodes(self):
        """AC1 — every cite_chunk slug must actually exist in the graph."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "any q", "format": "structured"},
            _llm_call=_mock_llm_clean,
        )
        self.assertTrue(result.get("ok"))
        # The citation in the mock answer is [[001-waitlist]], which
        # exists as a feature folder in the fixture project.
        slugs = {cc["slug"] for cc in (result.get("cite_chunks") or [])}
        self.assertIn("001-waitlist", slugs)

    def test_disabled_tier3_returns_clean_error(self):
        """When tier3.enabled=false, synthesise() returns a clean
        not-enabled error — never crashes (covers AC9 partly)."""
        # Rebuild fixture with tier3 disabled
        self._cleanup()
        self.root, self._cleanup = make_temp_project(tier3_disabled=True)
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock_llm_clean,
        )
        self.assertIs(result.get("ok"), False)
        # "tier 3" or "tier3" both acceptable — both refer to the same feature
        reason_lower = (result.get("reason") or "").lower()
        self.assertTrue(
            "tier 3" in reason_lower or "tier3" in reason_lower,
            msg=f"expected 'tier 3' or 'tier3' in reason; got: {reason_lower!r}"
        )
        self.assertIn("not enabled", reason_lower)

    def test_no_config_returns_clean_error(self):
        """When the project has no .sdd/config.md at all, synthesise()
        returns a clean error rather than crashing."""
        import tempfile
        import shutil
        empty = tempfile.mkdtemp(prefix="sdd-mcp-empty-")
        try:
            result = synthesise(
                empty,
                {"slug": "x", "question": "y", "format": "structured"},
                _llm_call=_mock_llm_clean,
            )
            self.assertIs(result.get("ok"), False)
            self.assertIsInstance(result, dict)
        finally:
            shutil.rmtree(empty, ignore_errors=True)

    def test_format_structured_returns_dict(self):
        """format='structured' returns the raw dict — agent reads
        cite_chunks/ambiguity directly without parsing prose."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock_llm_clean,
        )
        self.assertTrue(result.get("ok"))
        # Has the structured-shape keys
        for key in ("answer", "cite_chunks", "ok"):
            self.assertIn(key, result)
