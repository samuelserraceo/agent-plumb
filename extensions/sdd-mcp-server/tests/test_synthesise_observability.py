"""T22 — Counters (calls, tokens, cache hits) report correctly (AC17)."""

from __future__ import annotations

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries import synthesise  # noqa: E402
from queries.synthesise import get_counters  # noqa: E402
from tests.conftest import make_temp_project  # noqa: E402


def _mock(q, c, cfg):
    return "x — see [[001-waitlist]]."


class TestObservability(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_counters_zero_at_start(self):
        c = get_counters(self.root)
        self.assertEqual(c["calls_made"], 0)
        self.assertEqual(c["cache_hits"], 0)
        self.assertEqual(c["cache_misses"], 0)
        self.assertEqual(c["cache_hit_rate"], 0.0)

    def test_one_call_one_miss(self):
        synthesise(
            self.root, {"slug": "001-waitlist", "question": "q1", "format": "structured"},
            _llm_call=_mock,
        )
        c = get_counters(self.root)
        self.assertEqual(c["calls_made"], 1)
        self.assertEqual(c["cache_misses"], 1)
        self.assertEqual(c["cache_hits"], 0)

    def test_repeat_yields_cache_hit(self):
        args = {"slug": "001-waitlist", "question": "q1", "format": "structured"}
        synthesise(self.root, args, _llm_call=_mock)
        synthesise(self.root, args, _llm_call=_mock)
        c = get_counters(self.root)
        self.assertEqual(c["calls_made"], 1)        # only first ask fired LLM
        self.assertEqual(c["cache_hits"], 1)        # second was a hit
        self.assertEqual(c["cache_misses"], 1)
        self.assertGreater(c["cache_hit_rate"], 0.4)

    def test_tokens_used_grows_with_calls(self):
        for q in ("q1", "q2", "q3"):
            synthesise(
                self.root, {"slug": "001-waitlist", "question": q, "format": "structured"},
                _llm_call=_mock,
            )
        c = get_counters(self.root)
        self.assertGreater(c["tokens_used"], 0,
                           msg="tokens_used should reflect input chunk size")
