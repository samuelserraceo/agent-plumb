"""T11 — structured format returns valid JSON shape (AC7 part 1).

The structured response carries the keys the agent reads directly:
answer · cite_chunks · ambiguity · ok · format.
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


def _mock_clean(question, chunks, cfg):
    return "Postgres — see [[001-waitlist]] §5."


class TestSynthesiseStructuredShape(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_structured_has_required_keys(self):
        """The four required structured-shape keys are all present."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock_clean,
        )
        self.assertTrue(result.get("ok"))
        for key in ("answer", "cite_chunks", "ambiguity", "ok"):
            self.assertIn(key, result, msg=f"structured shape missing key {key!r}")

    def test_structured_is_json_serialisable(self):
        """The agent reads this as data — must round-trip through JSON."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock_clean,
        )
        encoded = json.dumps(result)
        decoded = json.loads(encoded)
        self.assertEqual(decoded.get("ok"), result.get("ok"))
        self.assertEqual(decoded.get("answer"), result.get("answer"))

    def test_structured_format_marker_present(self):
        """The response carries `format: structured` so callers can branch."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock_clean,
        )
        self.assertEqual(result.get("format"), "structured")
