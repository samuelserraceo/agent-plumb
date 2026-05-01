"""T7 — Rejected answer is NOT cached (AC3).

If cite-check fails, the response must NOT be written to the synthesis
cache — otherwise an identical re-ask would return the same broken
answer instead of giving the LLM another chance.
"""

from __future__ import annotations

import json
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


def _mock_llm_invents_counted(question, chunks, cfg):
    _CALLS["n"] += 1
    return "Result — [[totally-fake-slug]] §1."


class TestSynthesiseNoCacheOnReject(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)
        _CALLS["n"] = 0

    def tearDown(self):
        self._cleanup()

    def test_reject_then_reask_fires_llm_again(self):
        """Both calls must trigger the LLM (no cache hit on the second)."""
        args = {"slug": "001-waitlist", "question": "same q", "format": "structured"}
        first = synthesise(self.root, args, _llm_call=_mock_llm_invents_counted)
        second = synthesise(self.root, args, _llm_call=_mock_llm_invents_counted)
        self.assertIs(first.get("ok"), False)
        self.assertIs(second.get("ok"), False)
        self.assertEqual(_CALLS["n"], 2,
                         msg="rejected answer must NOT be cached; re-ask must re-fire LLM")

    def test_cache_file_not_polluted_by_rejection(self):
        """The synthesis.json cache file must not contain the rejected entry."""
        synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "q", "format": "structured"},
            _llm_call=_mock_llm_invents_counted,
        )
        cache_path = os.path.join(self.root, ".sdd", ".cache", "synthesis.json")
        if os.path.isfile(cache_path):
            with open(cache_path) as f:
                cache = json.load(f)
            entries = cache.get("entries", {})
            # No entry should have answer containing 'totally-fake-slug'
            for entry in entries.values():
                self.assertNotIn(
                    "totally-fake-slug", entry.get("answer", "") or "",
                    msg="rejected answer leaked into the cache"
                )
