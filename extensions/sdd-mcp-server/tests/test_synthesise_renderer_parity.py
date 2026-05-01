"""T12 — Structured + prose render produce matching cite_chunks (AC7).

Same (slug, question) called once with each format must produce the
SAME cite_chunks — proving the "two views, one core call" promise
from §5.
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


def _mock_clean(question, chunks, cfg):
    return "Postgres — see [[001-waitlist]] §5."


class TestSynthesiseRendererParity(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_structured_and_prose_have_matching_cite_chunks(self):
        """Two views, same data — cite_chunks identical between formats."""
        common_args = {"slug": "001-waitlist", "question": "x"}
        struct = synthesise(
            self.root,
            {**common_args, "format": "structured"},
            _llm_call=_mock_clean,
        )
        prose = synthesise(
            self.root,
            {**common_args, "format": "prose"},
            _llm_call=_mock_clean,
        )
        self.assertTrue(struct.get("ok"))
        self.assertTrue(prose.get("ok"))
        struct_slugs = sorted(c["slug"] for c in struct.get("cite_chunks") or [])
        prose_slugs = sorted(c["slug"] for c in prose.get("cite_chunks") or [])
        self.assertEqual(
            struct_slugs, prose_slugs,
            msg="structured + prose render paths must produce matching cite_chunks"
        )

    def test_prose_format_marker(self):
        """The prose response carries `format: prose`."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "prose"},
            _llm_call=_mock_clean,
        )
        self.assertEqual(result.get("format"), "prose")

    def test_invalid_format_rejected(self):
        """Unknown format strings are refused with a clear error."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "yaml"},
            _llm_call=_mock_clean,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("format", (result.get("reason") or "").lower())
