"""T13 — synthesise() reads provider/endpoint/model from config (AC8)."""

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


class TestConfigLoad(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_provider_endpoint_model_passed_to_llm(self):
        """The cfg dict the LLM call receives carries the configured fields."""
        captured = {}

        def _spy_llm(question, chunks, cfg):
            captured.update(cfg)
            return "x — see [[001-waitlist]]."

        synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_spy_llm,
        )
        self.assertEqual(captured.get("provider"), "ollama-chat")
        self.assertEqual(captured.get("endpoint"), "http://127.0.0.1:11434")
        self.assertEqual(captured.get("model"), "gemma2:2b")
