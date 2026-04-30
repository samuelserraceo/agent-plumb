"""Tests for the LLM and Browser driver abstractions.

The mocks ARE production code — every test in this extension drives
through them, and `test_explorer.py` composes them end-to-end. So we
test their contract here directly.

The real HttpLLMDriver and PlaywrightBrowserDriver have construction
+ smoke tests; full-fidelity tests would need a live LLM endpoint
and a real Chromium install respectively, which CI shouldn't require.
"""

from __future__ import annotations

import json
import os
import sys
import unittest
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from drivers import (  # noqa: E402
    LLMDriver,
    MockLLMDriver,
    HttpLLMDriver,
    BrowserDriver,
    MockBrowserDriver,
)
from drivers.llm import _normalise_probe, PROBE_ACTIONS  # noqa: E402


# -- LLM driver contract ------------------------------------------------------

class NormaliseProbeTests(unittest.TestCase):
    def test_normalises_full_probe(self):
        probe = _normalise_probe({
            "action": "FILL", "target": "#email", "value": "x",
            "expected": "shows error", "rationale": "blank not handled",
        })
        self.assertEqual(probe["action"], "fill")
        self.assertEqual(probe["target"], "#email")

    def test_unknown_action_collapses_to_noop(self):
        probe = _normalise_probe({"action": "scream", "target": "x"})
        self.assertEqual(probe["action"], "noop")

    def test_non_dict_collapses_to_noop_with_diagnostic(self):
        probe = _normalise_probe("not a dict")
        self.assertEqual(probe["action"], "noop")
        self.assertIn("non-dict", probe["rationale"])

    def test_missing_fields_get_empty_strings(self):
        probe = _normalise_probe({"action": "click"})
        self.assertEqual(probe["action"], "click")
        self.assertEqual(probe["target"], "")
        self.assertEqual(probe["value"], "")

    def test_known_action_set_documented(self):
        # If we extend PROBE_ACTIONS later, this test catches doc drift.
        for known in ("fill", "click", "goto", "wait", "eval", "noop"):
            self.assertIn(known, PROBE_ACTIONS)


class MockLLMDriverTests(unittest.TestCase):
    def test_pulls_from_per_category_queue_first(self):
        driver = MockLLMDriver(probes_by_category={
            "empty": [{"action": "fill", "target": "#email", "value": ""}],
        })
        probe = driver.propose_probe(category="empty", state={}, spec_acs=[], history=[])
        self.assertEqual(probe["action"], "fill")
        self.assertEqual(driver.calls, 1)

    def test_falls_back_to_flat_queue_when_category_empty(self):
        driver = MockLLMDriver(flat_queue=[{"action": "click", "target": ".submit"}])
        probe = driver.propose_probe(category="bad-input", state={}, spec_acs=[], history=[])
        self.assertEqual(probe["action"], "click")

    def test_returns_noop_when_queue_dry(self):
        driver = MockLLMDriver()
        probe = driver.propose_probe(category="empty", state={}, spec_acs=[], history=[])
        self.assertEqual(probe["action"], "noop")
        self.assertIn("category=empty", probe["rationale"])

    def test_cost_default_zero(self):
        self.assertEqual(MockLLMDriver().cost_per_call_usd, 0.0)

    def test_cost_configurable(self):
        self.assertAlmostEqual(MockLLMDriver(cost_per_call_usd=0.02).cost_per_call_usd, 0.02)

    def test_implements_abstract_class(self):
        self.assertIsInstance(MockLLMDriver(), LLMDriver)


class HttpLLMDriverConstructionTests(unittest.TestCase):
    def test_rejects_missing_endpoint(self):
        with self.assertRaises(ValueError):
            HttpLLMDriver(endpoint="", model="gpt-4")

    def test_rejects_missing_model(self):
        with self.assertRaises(ValueError):
            HttpLLMDriver(endpoint="http://x/v1/chat", model="")

    def test_default_cost_is_one_cent(self):
        driver = HttpLLMDriver(endpoint="http://x", model="m")
        self.assertAlmostEqual(driver.cost_per_call_usd, 0.01)

    def test_http_error_returns_noop_probe_not_raise(self):
        driver = HttpLLMDriver(endpoint="http://127.0.0.1:1/v1/chat/completions", model="m", timeout_seconds=0.1)
        probe = driver.propose_probe(category="empty", state={}, spec_acs=[], history=[])
        self.assertEqual(probe["action"], "noop")
        self.assertIn("error", probe["rationale"].lower())

    def test_malformed_response_returns_noop(self):
        # Construct a fake response that returns invalid JSON in the message content.
        fake_payload = json.dumps({
            "choices": [{"message": {"content": "this is not json"}}]
        }).encode("utf-8")

        class _FakeResp:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self):
                return fake_payload

        driver = HttpLLMDriver(endpoint="http://x/v1/chat", model="m")
        with mock.patch("urllib.request.urlopen", return_value=_FakeResp()):
            probe = driver.propose_probe(category="empty", state={}, spec_acs=[], history=[])
        self.assertEqual(probe["action"], "noop")
        self.assertIn("bad llm reply", probe["rationale"])


# -- Browser driver contract --------------------------------------------------

_PAGE_FIXTURE = {
    "https://example.test/signup": {
        "title": "Signup",
        "text": "Welcome — enter your email",
        "selectors": {"#email": "fillable", ".submit": "clickable"},
        "on_click": {".submit": lambda: {"url": "https://example.test/welcome"}},
        "on_fill": {"#email": lambda v: {"console_errors": [f"validate({v})"]} if "@" not in v else {}},
        "status_code": 200,
    },
    "https://example.test/welcome": {
        "title": "Welcome",
        "text": "Thanks — check your inbox",
        "selectors": {},
        "status_code": 200,
    },
}


class MockBrowserDriverTests(unittest.TestCase):
    def setUp(self):
        self.driver = MockBrowserDriver(pages=_PAGE_FIXTURE)

    def test_goto_returns_state_for_known_page(self):
        state = self.driver.goto("https://example.test/signup")
        self.assertEqual(state["status_code"], 200)
        self.assertEqual(state["title"], "Signup")
        self.assertIn("Welcome", state["text"])

    def test_goto_unknown_page_returns_404_state(self):
        state = self.driver.goto("https://example.test/missing")
        self.assertEqual(state["status_code"], 404)
        self.assertIn("page not found", state["last_error"])

    def test_fill_unknown_selector_records_last_error(self):
        self.driver.goto("https://example.test/signup")
        state = self.driver.fill("#nope", "x")
        self.assertIn("selector not found", state["last_error"])

    def test_fill_runs_on_fill_callback(self):
        self.driver.goto("https://example.test/signup")
        state = self.driver.fill("#email", "no-at-sign")
        self.assertIn("validate(no-at-sign)", state["console_errors"])
        self.assertEqual(state["last_error"], "")  # successful action clears

    def test_click_can_navigate_via_overrides(self):
        self.driver.goto("https://example.test/signup")
        self.driver.fill("#email", "ok@example.com")
        state = self.driver.click(".submit")
        self.assertEqual(state["url"], "https://example.test/welcome")
        self.assertEqual(state["title"], "Welcome")

    def test_actions_taken_records_each_call(self):
        self.driver.goto("https://example.test/signup")
        self.driver.fill("#email", "x")
        self.driver.click(".submit")
        kinds = [a["kind"] for a in self.driver.actions_taken]
        self.assertEqual(kinds, ["goto", "fill", "click"])

    def test_close_marks_closed(self):
        self.assertFalse(self.driver.closed)
        self.driver.close()
        self.assertTrue(self.driver.closed)

    def test_snapshot_does_not_record_action(self):
        self.driver.goto("https://example.test/signup")
        before = len(self.driver.actions_taken)
        self.driver.snapshot()
        self.assertEqual(len(self.driver.actions_taken), before)

    def test_implements_abstract_class(self):
        self.assertIsInstance(self.driver, BrowserDriver)

    def test_wait_and_eval_record_actions(self):
        self.driver.wait(500)
        self.driver.eval_js("window.scrollTo(0, 100)")
        kinds = [a["kind"] for a in self.driver.actions_taken]
        self.assertEqual(kinds, ["wait", "eval_js"])


if __name__ == "__main__":
    unittest.main()
