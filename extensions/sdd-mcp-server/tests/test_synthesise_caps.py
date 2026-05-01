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
from queries.synthesise import _reset_run_counters_for_test  # noqa: E402
from tests.conftest import make_temp_project, CONFIG_MD_WITH_TIER3  # noqa: E402


def _mock_clean(question, chunks, cfg):
    return "x — see [[001-waitlist]] §1."


class TestSynthesiseCaps(unittest.TestCase):

    def setUp(self):
        # Reset per-process run counters so tests start clean — otherwise
        # earlier-test bumps would carry into later tests.
        _reset_run_counters_for_test()
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()
        _reset_run_counters_for_test()

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

    def test_max_calls_per_run_refuses_after_threshold(self):
        """max_calls_per_run=2 → the 3rd call in the same MCP server
        process is refused. CR cycle 5: prove the cap actually fires;
        previous coverage only checked max_input_tokens_per_call."""
        self._patch_config(
            "max_calls_per_run: 2\nmax_input_tokens_per_call: 8000\nmax_total_tokens_per_run: 100000"
        )
        # First 2 calls succeed (run-counter goes 0 → 1 → 2).
        for i in range(2):
            r = synthesise(
                self.root,
                {"slug": "001-waitlist", "question": f"q{i}", "format": "structured"},
                _llm_call=_mock_clean,
            )
            self.assertTrue(r.get("ok"), msg=f"call {i+1}/2 should pass; got {r.get('reason')}")
        # 3rd call refused — the cap-check runs BEFORE the counter bump
        # so it sees 2 + 1 = 3 > 2.
        r = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "q3", "format": "structured"},
            _llm_call=_mock_clean,
        )
        self.assertIs(r.get("ok"), False)
        self.assertIn("max_calls_per_run", r.get("reason") or "")

    def test_max_total_tokens_per_run_refuses_after_threshold(self):
        """max_total_tokens_per_run=50 with chunks larger than that →
        first call passes (tokens=0 + chunk-tokens), second call refused
        because the run-counter now exceeds the cap. CR cycle 5."""
        # Set the cap small enough that two chunks of normal corpus
        # content (each ~150 chars / ~37 tokens) trip it on call 2.
        self._patch_config(
            "max_calls_per_run: 100\nmax_input_tokens_per_call: 8000\nmax_total_tokens_per_run: 50"
        )
        # First call — _RUN_COUNTERS.tokens_used starts at 0; the cap
        # checks 0 + chunk-tokens vs 50. Whether it passes or fails on
        # call 1 depends on chunk size; either is fine, but if it
        # passes call 1 then call 2 must fail.
        r1 = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "q1", "format": "structured"},
            _llm_call=_mock_clean,
        )
        # Second call — even if the first passed, the second sees the
        # bumped run-counter from r1 and must trip max_total_tokens_per_run
        # OR the first already tripped it. Either way SOMETHING must be
        # refused for the cap to be real.
        r2 = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "q2", "format": "structured"},
            _llm_call=_mock_clean,
        )
        either_refused = (
            (r1.get("ok") is False and "max_total_tokens_per_run" in (r1.get("reason") or ""))
            or (r2.get("ok") is False and "max_total_tokens_per_run" in (r2.get("reason") or ""))
        )
        self.assertTrue(
            either_refused,
            msg=f"max_total_tokens_per_run cap must fire on at least one of two calls; got r1={r1.get('reason')!r} r2={r2.get('reason')!r}",
        )
