"""T28 — Cache eviction policy LRU at 1000 entries (AC21, §15 sweep)."""

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
from queries.synthesise import _CACHE_MAX_ENTRIES  # noqa: E402
from tests.conftest import make_temp_project  # noqa: E402


def _mock(q, c, cfg):
    return "x — see [[001-waitlist]]."


class TestCacheEviction(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_threshold_constant_is_1000(self):
        """The §15 sweep approved 1000 as the eviction threshold."""
        self.assertEqual(_CACHE_MAX_ENTRIES, 1000)

    def test_cache_does_not_grow_unbounded_past_threshold(self):
        """Fire >1000 unique synthesise calls + assert cache size capped.

        Note: queries.synthesise is shadowed by the function (re-exported
        in __init__.py) so import_module gives us the actual module.
        """
        import importlib
        syn_mod = importlib.import_module("queries.synthesise")
        original = syn_mod._CACHE_MAX_ENTRIES
        syn_mod._CACHE_MAX_ENTRIES = 5
        try:
            for i in range(20):
                synthesise(
                    self.root,
                    {"slug": "001-waitlist", "question": f"q-{i}", "format": "structured"},
                    _llm_call=_mock,
                )
            cache_path = os.path.join(self.root, ".sdd", ".cache", "synthesis.json")
            with open(cache_path) as f:
                cache = json.load(f)
            entries = cache.get("entries", {})
            # CR feedback: enforce the EXACT cap. The synchronous eviction
            # path (`_evict_lru_if_full` runs inside every successful
            # _save_synthesis_cache before flush) cuts strictly back to
            # syn_mod._CACHE_MAX_ENTRIES. Anything over is a regression.
            self.assertEqual(
                len(entries), syn_mod._CACHE_MAX_ENTRIES,
                msg=f"cache must equal the patched cap exactly: got {len(entries)}, expected {syn_mod._CACHE_MAX_ENTRIES}",
            )
        finally:
            syn_mod._CACHE_MAX_ENTRIES = original
