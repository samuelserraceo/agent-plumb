"""T14 — Disabled state returns clean error, no crash (AC9)."""

from __future__ import annotations

import os
import sys
import tempfile
import shutil
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries import synthesise  # noqa: E402
from tests.conftest import make_temp_project  # noqa: E402


def _mock(q, c, cfg):
    return "x — see [[001-waitlist]]."


class TestDisabled(unittest.TestCase):

    def test_enabled_false_returns_not_enabled(self):
        root, cleanup = make_temp_project(tier3_disabled=True)
        try:
            result = synthesise(
                root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
                _llm_call=_mock,
            )
            self.assertIs(result.get("ok"), False)
            self.assertIn("not enabled", (result.get("reason") or "").lower())
        finally:
            cleanup()

    def test_no_tier3_block_at_all_treated_as_disabled(self):
        """Old projects upgraded without re-running /sdd-config (no tier3 block in config) get the same clean disabled response — anti-theatre re §15 sub-test."""
        root = tempfile.mkdtemp(prefix="sdd-mcp-no-tier3-")
        try:
            os.makedirs(os.path.join(root, ".sdd"), exist_ok=True)
            with open(os.path.join(root, ".sdd", "config.md"), "w") as f:
                f.write("---\ntype: config\nparameters:\n  budget:\n    max_minutes: 5\n---\n")
            result = synthesise(
                root, {"slug": "x", "question": "x", "format": "structured"},
                _llm_call=_mock,
            )
            self.assertIs(result.get("ok"), False)
        finally:
            shutil.rmtree(root, ignore_errors=True)
