"""T9 — Editing a cited file flips corpus signature → cache miss (AC5).

When any file under .sdd/ changes, the corpus_signature flips. The
cache key includes that signature, so cached entries from before the
change become stale and the next ask re-fires the LLM with the new
content.
"""

from __future__ import annotations

import os
import sys
import time
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries import synthesise  # noqa: E402
from tests.conftest import make_temp_project  # noqa: E402


_CALLS = {"n": 0}


def _mock_llm_counted(question, chunks, cfg):
    _CALLS["n"] += 1
    return "Postgres — see [[001-waitlist]] §5."


class TestSynthesiseCacheInvalidate(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)
        _CALLS["n"] = 0

    def tearDown(self):
        self._cleanup()

    def test_corpus_edit_invalidates_cached_entry(self):
        """First call caches; corpus edit; second call re-fires."""
        args = {"slug": "001-waitlist", "question": "same q", "format": "structured"}
        synthesise(self.root, args, _llm_call=_mock_llm_counted)
        # Sanity: second call with no edit hits cache
        synthesise(self.root, args, _llm_call=_mock_llm_counted)
        self.assertEqual(_CALLS["n"], 1, msg="sanity: cache hit after first call")

        # Edit the spec.md (the cited content)
        spec_path = os.path.join(
            self.root, ".sdd", "features", "001-waitlist", "spec.md"
        )
        with open(spec_path, "a", encoding="utf-8") as f:
            f.write("\n\n## new section added at " + str(time.time()) + "\n")

        # Deterministic mtime bump — replaces the flaky time.sleep(0.02)
        # path that fails on filesystems with coarse (1s) mtime resolution
        # (CR feedback). os.utime guarantees the file's mtime advances
        # by ≥2s, ensuring the corpus signature recomputes.
        st = os.stat(spec_path)
        os.utime(spec_path, (st.st_atime, st.st_mtime + 2))

        # Now ask again — must be a cache miss → LLM called for a 2nd time
        synthesise(self.root, args, _llm_call=_mock_llm_counted)
        self.assertEqual(
            _CALLS["n"], 2,
            msg="corpus edit must invalidate cache; expected 2 LLM calls total"
        )
