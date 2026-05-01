"""T18 — Default answer ≤ 1024 bytes; longer trimmed at boundary (AC13)."""

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


def _mock_long(q, c, cfg):
    """LLM returns 5000 chars of prose with one valid cite."""
    body = "x" * 5000
    return f"{body} — see [[001-waitlist]]."


def _mock_short(q, c, cfg):
    return "Short — see [[001-waitlist]]."


class TestLengthCap(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_long_answer_trimmed_to_under_1024(self):
        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock_long,
        )
        # AC13: default answer is ≤ 1024 bytes — strictly enforced.
        # The implementation reserves bytes for the expand-suffix INSIDE
        # the 1024 budget (keep = cap - len(suffix) → text + suffix =
        # cap bytes total), so the cap is hard, not "1024 + suffix budget"
        # (CR feedback: previous ≤1100 bound weakened the contract).
        self.assertTrue(result.get("ok"))
        answer_bytes = len((result.get("answer") or "").encode("utf-8"))
        self.assertLessEqual(
            answer_bytes, 1024,
            msg=f"answer exceeds 1024-byte cap: {answer_bytes} bytes"
        )

    def test_long_answer_signals_truncation_with_suffix(self):
        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock_long,
        )
        self.assertIn("expand", (result.get("answer") or "").lower())

    def test_short_answer_not_trimmed(self):
        """Short answer survives the length-cap path unchanged."""
        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock_short,
        )
        self.assertEqual(result.get("answer"), "Short — see [[001-waitlist]].")
