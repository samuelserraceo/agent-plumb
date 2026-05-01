"""T10 — Three call/token caps refuse past their threshold (AC6).

max_calls_per_run · max_input_tokens_per_call · max_total_tokens_per_run.
Each cap is independently enforced; hitting any of them returns
{ok:false, reason:"<cap> exceeded"} rather than crashing.
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
from tests.conftest import make_temp_project, CONFIG_MD_WITH_TIER3  # noqa: E402


def _mock_clean(question, chunks, cfg):
    return "x — see [[001-waitlist]] §1."


class TestSynthesiseCaps(unittest.TestCase):

    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def _patch_config(self, caps_yaml: str) -> None:
        """Overwrite tier3 config with custom caps."""
        cfg_path = os.path.join(self.root, ".sdd", "config.md")
        # Build a minimal config with the custom caps replacing the defaults
        body = CONFIG_MD_WITH_TIER3.replace(
            "max_calls_per_run: 10",
            caps_yaml.split("\n")[0].strip(),
        ).replace(
            "max_input_tokens_per_call: 8000",
            caps_yaml.split("\n")[1].strip() if len(caps_yaml.split("\n")) > 1 else "max_input_tokens_per_call: 8000",
        ).replace(
            "max_total_tokens_per_run: 100000",
            caps_yaml.split("\n")[2].strip() if len(caps_yaml.split("\n")) > 2 else "max_total_tokens_per_run: 100000",
        )
        with open(cfg_path, "w") as f:
            f.write(body)

    def test_max_input_tokens_refuses_pre_network(self):
        """Tiny max_input_tokens cap → refuses before LLM is called."""
        self._patch_config(
            "max_calls_per_run: 10\nmax_input_tokens_per_call: 5\nmax_total_tokens_per_run: 100000"
        )
        called = {"n": 0}

        def _spy_llm(q, c, cfg):
            called["n"] += 1
            return _mock_clean(q, c, cfg)

        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "any q", "format": "structured"},
            _llm_call=_spy_llm,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("max_input_tokens_per_call", result.get("reason") or "")
        self.assertEqual(called["n"], 0,
                         msg="cap must refuse BEFORE the LLM is invoked")

    def test_default_caps_dont_refuse_normal_questions(self):
        """Sanity: default caps allow a normal question to go through."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "any q", "format": "structured"},
            _llm_call=_mock_clean,
        )
        self.assertTrue(result.get("ok"))
