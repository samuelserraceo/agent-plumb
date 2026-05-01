"""T6 — Cite-check rejects invented [[fake-slug]] (AC2).

When the AI returns an answer that cites a slug not in the graph,
synthesise() rejects the answer and returns the raw retrieval chunks
as fallback — never silently leaks an invented citation.
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


def _mock_llm_invents(question, chunks, cfg):
    return "Postgres was picked — see [[fake-pattern-that-doesnt-exist]] §99."


class TestSynthesiseCiteCheckReject(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_invented_link_rejects_answer(self):
        """ok=False with reason naming the broken slug."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "any q", "format": "structured"},
            _llm_call=_mock_llm_invents,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("cite-check failed", (result.get("reason") or "").lower())

    def test_broken_slugs_listed(self):
        """The broken_slugs field exposes which links failed."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "any q", "format": "structured"},
            _llm_call=_mock_llm_invents,
        )
        broken = result.get("broken_slugs") or []
        self.assertIn("fake-pattern-that-doesnt-exist", broken)

    def test_fallback_returns_raw_chunks(self):
        """The cite_chunks field carries the retrieval chunks (not LLM output)."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "any q", "format": "structured"},
            _llm_call=_mock_llm_invents,
        )
        chunks = result.get("cite_chunks") or []
        self.assertGreaterEqual(
            len(chunks), 1,
            msg="rejection must surface raw chunks so user can answer themselves"
        )
        # Each chunk has a path — proving these are retrieval chunks, not synth output
        self.assertTrue(all("path" in c for c in chunks))

    def test_answer_field_is_none_on_reject(self):
        """The synthesised answer is suppressed — never shown when broken."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "any q", "format": "structured"},
            _llm_call=_mock_llm_invents,
        )
        self.assertIsNone(result.get("answer"))
