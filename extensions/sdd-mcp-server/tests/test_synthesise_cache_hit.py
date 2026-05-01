"""T8 — Cache miss → write → hit returns identical answer without
firing the LLM (AC4).

The second call to synthesise() with the same (question, corpus) must
not invoke the LLM. The cached answer is returned directly.
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


_CALLS = {"n": 0}


def _mock_llm_clean_counted(question, chunks, cfg):
    _CALLS["n"] += 1
    return "Postgres was picked — see [[001-waitlist]] §5."


class TestSynthesiseCacheHit(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)
        _CALLS["n"] = 0

    def tearDown(self):
        self._cleanup()

    def test_first_call_fires_llm_second_doesnt(self):
        """LLM should be called exactly once for two identical asks."""
        args = {"slug": "001-waitlist", "question": "same q", "format": "structured"}
        first = synthesise(self.root, args, _llm_call=_mock_llm_clean_counted)
        second = synthesise(self.root, args, _llm_call=_mock_llm_clean_counted)
        self.assertTrue(first.get("ok"))
        self.assertTrue(second.get("ok"))
        self.assertEqual(_CALLS["n"], 1,
                         msg="cache hit on second call should not fire LLM")

    def test_cached_answer_matches_first(self):
        """Both calls return the same answer text (cache returns the original)."""
        args = {"slug": "001-waitlist", "question": "same q", "format": "structured"}
        first = synthesise(self.root, args, _llm_call=_mock_llm_clean_counted)
        second = synthesise(self.root, args, _llm_call=_mock_llm_clean_counted)
        self.assertEqual(first.get("answer"), second.get("answer"))
