"""T17 — Three failure modes produce clean errors (AC12).

provider unreachable · rate-limited · malformed AI response. Each
returns a clean error rather than crashing the framework. The cache
disk-write failure path is exercised under
test_synthesise_cache_eviction.py (write loop) and the in-process
_save_synthesis_cache contract (initialises tmp before the try, suppresses
unlink errors) — see queries/synthesise.py:_save_synthesis_cache.
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
from queries.synthesise import _ProviderUnreachable, _ProviderRateLimited  # noqa: E402
from tests.conftest import make_temp_project  # noqa: E402


class TestFailureModes(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_provider_unreachable_clean_error(self):
        def _unreachable(q, c, cfg):
            raise _ProviderUnreachable("connection refused on localhost:11434")

        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_unreachable,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("unreachable", (result.get("reason") or "").lower())

    def test_rate_limited_clean_error(self):
        def _rate_limit(q, c, cfg):
            raise _ProviderRateLimited("429 — too many requests")

        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_rate_limit,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("rate-limit", (result.get("reason") or "").lower())

    def test_malformed_response_clean_error(self):
        """LLM returns non-string → treated as malformed, fallback path."""
        def _malformed(q, c, cfg):
            return None  # not a string

        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_malformed,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("malformed", (result.get("reason") or "").lower())

    def test_arbitrary_exception_caught_cleanly(self):
        """Any other exception from the LLM call is caught + reported."""
        def _explode(q, c, cfg):
            raise ValueError("something went wrong")

        result = synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_explode,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("malformed", (result.get("reason") or "").lower())
