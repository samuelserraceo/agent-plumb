"""T29 — Question validation (AC22, §15 sweep): empty / control chars / null / huge."""

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


def _mock(q, c, cfg):
    return "x — see [[001-waitlist]]."


class TestQuestionValidation(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_empty_question_rejected(self):
        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "", "format": "structured"},
            _llm_call=_mock,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("question invalid", (result.get("reason") or "").lower())

    def test_huge_question_rejected(self):
        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "x" * 10000, "format": "structured"},
            _llm_call=_mock,
        )
        self.assertIs(result.get("ok"), False)

    def test_control_char_question_rejected(self):
        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "hello\x07world", "format": "structured"},
            _llm_call=_mock,
        )
        self.assertIs(result.get("ok"), False)

    def test_null_byte_question_rejected(self):
        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "hello\x00world", "format": "structured"},
            _llm_call=_mock,
        )
        self.assertIs(result.get("ok"), False)
