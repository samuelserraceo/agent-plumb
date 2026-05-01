"""End-to-end tests for the explore loop.

The tests use MockLLMDriver + MockBrowserDriver so the loop runs
deterministically — no LLM credentials, no real Chromium. The mocks
were tested separately in test_drivers.py; here we verify the
orchestration: budget gates, finding detection, AC coverage, the
8-category sweep.
"""

from __future__ import annotations

import os
import sys
import tempfile
import textwrap
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from drivers import MockLLMDriver, MockBrowserDriver  # noqa: E402
from explorer import (  # noqa: E402
    DEFAULT_CATEGORIES,
    explore,
    read_spec_acs,
    summarise_findings,
    _slugify,
    _covered_by_acs,
)


# -- fixtures -----------------------------------------------------------------

# Pages: a tiny "signup form" that the explorer can hammer.
def _email_fill_overrides(v):
    # Different "buggy" responses depending on the value, so different
    # probe shapes can elicit different `actual` strings — exercises both
    # the uncovered (no AC overlap) and covered (≥3-token AC overlap)
    # paths from the same fixture.
    if not v:
        return {"console_errors": ["validate(): missing required field"]}
    if "@" not in v:
        return {"console_errors": ["invalid email format — inline error required"]}
    return {}


_PAGES = {
    "https://example.test/signup": {
        "title": "Signup",
        "text": "Welcome — enter your email to join the waitlist",
        "selectors": {"#email": "fillable", ".submit": "clickable"},
        "on_fill": {"#email": _email_fill_overrides},
        # Clicking submit while #email is empty surfaces a network error and
        # leaves the user on /signup; with a value it navigates to /welcome.
        "on_click": {
            ".submit": lambda: {"url": "https://example.test/welcome"},
        },
        "status_code": 200,
    },
    "https://example.test/welcome": {
        "title": "Welcome",
        "text": "Thanks — check your inbox for a confirmation email",
        "selectors": {},
        "status_code": 200,
    },
}


_SPEC_BODY = """\
# 001-test feature

## §1 Problem
people sign up

## §11 Acceptance criteria
- AC1: form renders
- AC2: invalid email shows inline error
- AC3: success state appears after submit
"""


class _SpecFixture:
    def __enter__(self):
        self.tmp = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8")
        self.tmp.write(_SPEC_BODY)
        self.tmp.close()
        return self.tmp.name

    def __exit__(self, *args):
        try:
            os.unlink(self.tmp.name)
        except OSError:
            pass


def _probe_for_empty_signup() -> dict:
    """Probe that fills #email with empty string — should surface the validate error."""
    return {
        "action": "fill", "target": "#email", "value": "",
        "expected": "form rejects empty email and shows validation message",
        "rationale": "spec has no AC for empty email submission",
    }


def _probe_for_network_failure() -> dict:
    """Probe that clicks .submit on an unfilled form — should fail."""
    return {
        "action": "click", "target": ".submit",
        "expected": "submission while form is incomplete is blocked",
        "rationale": "spec doesn't cover client-side guarding",
    }


def _probe_unknown_selector() -> dict:
    """Probe whose selector doesn't exist — should record last_error."""
    return {
        "action": "click", "target": ".nonexistent",
        "expected": "the cancel button cancels the flow",
        "rationale": "spec mentions cancel but no selector",
    }


# -- read_spec_acs ------------------------------------------------------------

class ReadSpecAcsTests(unittest.TestCase):
    def test_extracts_ac_lines_from_section_11(self):
        with _SpecFixture() as path:
            acs = read_spec_acs(path)
        self.assertEqual(len(acs), 3)
        # Each entry is a full line, not just the AC label, so coverage
        # detection has tokens to match against.
        self.assertTrue(any("AC1" in line and "renders" in line for line in acs))
        self.assertTrue(any("invalid email" in line for line in acs))

    def test_missing_file_returns_empty(self):
        self.assertEqual(read_spec_acs("/no/such/file.md"), [])

    def test_no_section_11_returns_empty(self):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as fh:
            fh.write("# nothing here\n## §1 Problem\nbody\n")
            path = fh.name
        try:
            self.assertEqual(read_spec_acs(path), [])
        finally:
            os.unlink(path)

    def test_empty_path_returns_empty(self):
        self.assertEqual(read_spec_acs(""), [])


# -- helpers ------------------------------------------------------------------

class HelperTests(unittest.TestCase):
    def test_slugify_handles_punctuation(self):
        self.assertEqual(_slugify("Empty Email!"), "empty-email")

    def test_slugify_truncates_long_text(self):
        slug = _slugify("a" * 200)
        self.assertLessEqual(len(slug), 60)

    def test_slugify_empty_falls_back(self):
        self.assertEqual(_slugify("!!!"), "edge-case")

    def test_covered_by_acs_finds_overlap_on_actual(self):
        # Coverage now uses `actual` only (the observed behaviour), not
        # `expected`. The actual must carry ≥3 meaningful tokens that
        # match AC vocabulary.
        acs = ["AC2: invalid email shows inline error message"]
        idx = _covered_by_acs(
            expected="ignored",
            actual="invalid email shows inline error message displayed",
            acs=acs,
        )
        self.assertEqual(idx, 1)

    def test_covered_by_acs_returns_none_when_no_overlap(self):
        acs = ["AC1: form renders"]
        idx = _covered_by_acs(expected="network timeout", actual="connection refused", acs=acs)
        self.assertIsNone(idx)

    def test_covered_by_acs_ignores_expected_when_actual_diverges(self):
        # Real-world bug surfaced by the live smoke: an XSS finding's
        # `expected` ("submit empty email shows inline error") falsely
        # matched AC2 ("empty email submission rejected with inline
        # error") because both share email/inline/error tokens — even
        # though the `actual` was about XSS, not empty submission. With
        # the actual-only check, the false positive is gone.
        acs = ["AC2: empty email submission is rejected with inline error"]
        idx = _covered_by_acs(
            expected="submit with empty email should show inline validation error",
            actual="console error appeared: XSS payload accepted unsafely",
            acs=acs,
        )
        self.assertIsNone(idx)


# -- explore loop -------------------------------------------------------------

class ExploreLoopTests(unittest.TestCase):
    def setUp(self):
        self.spec = _SpecFixture()
        self.spec_path = self.spec.__enter__()

    def tearDown(self):
        self.spec.__exit__(None, None, None)

    def _make_browser(self):
        return MockBrowserDriver(pages=_PAGES)

    def test_runs_default_8_categories_with_3_attempts_each(self):
        # 8 categories * 3 attempts = 24 LLM calls; budget allows 50.
        # Use noop probes so the loop completes without findings.
        llm = MockLLMDriver(flat_queue=[
            {"action": "noop", "rationale": "no probe"} for _ in range(30)
        ])
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
        )
        per_cat = result["stats"]["attempts_per_category"]
        self.assertEqual(set(per_cat.keys()), set(DEFAULT_CATEGORIES))
        for cat in DEFAULT_CATEGORIES:
            self.assertEqual(per_cat[cat], 3, msg=f"category {cat} got {per_cat[cat]}")
        self.assertEqual(result["stats"]["llm_calls"], 24)
        self.assertEqual(result["stats"]["halt_reason"], "complete")

    def test_finding_detected_for_console_error_after_fill(self):
        # First probe: fill empty email → console error → finding.
        # Remaining: noop so the loop completes cleanly.
        llm = MockLLMDriver(
            probes_by_category={"empty": [_probe_for_empty_signup()]},
            flat_queue=[{"action": "noop"} for _ in range(40)],
        )
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
            attempts_per_category=1, categories=["empty"],
        )
        self.assertEqual(result["found"], 1)
        finding = result["items"][0]
        self.assertEqual(finding["category"], "empty")
        self.assertIn("console error", finding["actual"])
        self.assertIn("go to https://example.test/signup", finding["repro_steps"])
        self.assertEqual(finding["severity"], "med")

    def test_finding_marked_uncovered_when_no_ac_overlap(self):
        llm = MockLLMDriver(probes_by_category={"empty": [_probe_for_empty_signup()]})
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
            attempts_per_category=1, categories=["empty"],
        )
        finding = result["items"][0]
        self.assertEqual(result["uncovered"], 1)
        self.assertIsNone(finding["covered_by_ac"])
        self.assertTrue(finding["ac_link"].startswith("[[ac:"))

    def test_finding_marked_covered_when_ac_overlaps(self):
        # The fixture's AC2 is "invalid email shows inline error".
        # Filling with a value that lacks @ triggers a console error
        # whose tokens overlap AC2 by ≥3 — coverage must match.
        # Coverage now uses `actual` only, so the probe's `expected`
        # vocabulary is irrelevant.
        probe = {
            "action": "fill", "target": "#email", "value": "wrongformat",
            "expected": "ignored by coverage",
            "rationale": "exercise the covered path",
        }
        llm = MockLLMDriver(probes_by_category={"bad-input": [probe]})
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
            attempts_per_category=1, categories=["bad-input"],
        )
        finding = result["items"][0]
        self.assertEqual(finding["covered_by_ac"], 2)
        self.assertEqual(finding["ac_link"], "")  # covered → no new-AC suggestion

    def test_unknown_selector_records_last_error_finding(self):
        llm = MockLLMDriver(probes_by_category={"bad-input": [_probe_unknown_selector()]})
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
            attempts_per_category=1, categories=["bad-input"],
        )
        finding = result["items"][0]
        self.assertIn("action failed", finding["actual"])
        self.assertEqual(finding["severity"], "med")

    def test_halts_on_llm_budget(self):
        llm = MockLLMDriver(flat_queue=[{"action": "noop"} for _ in range(50)])
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
            max_llm_calls=5,
        )
        self.assertEqual(result["stats"]["halt_reason"], "llm_budget")
        self.assertLessEqual(result["stats"]["llm_calls"], 5)

    def test_halts_on_browser_budget(self):
        llm = MockLLMDriver(flat_queue=[
            {"action": "click", "target": ".submit", "expected": "x", "rationale": "y"}
            for _ in range(50)
        ])
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
            max_browser_actions=4,  # initial goto = 1, then 3 clicks = 4
        )
        self.assertEqual(result["stats"]["halt_reason"], "browser_budget")
        self.assertLessEqual(result["stats"]["browser_actions"], 4)

    def test_halts_on_cost_budget(self):
        llm = MockLLMDriver(
            flat_queue=[{"action": "noop"} for _ in range(50)],
            cost_per_call_usd=0.50,
        )
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
            cost_limit_usd=1.00,  # budget exhausted at 2 calls.
        )
        self.assertEqual(result["stats"]["halt_reason"], "cost_budget")

    def test_returns_ac4_shape(self):
        # AC4 of #84: shape is {found, uncovered, items: [{category, repro_steps, expected, actual, severity}]}
        llm = MockLLMDriver(probes_by_category={"empty": [_probe_for_empty_signup()]})
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
            attempts_per_category=1, categories=["empty"],
        )
        self.assertIn("found", result)
        self.assertIn("uncovered", result)
        self.assertIn("items", result)
        item = result["items"][0]
        for required in ("category", "repro_steps", "expected", "actual", "severity"):
            self.assertIn(required, item, msg=f"missing required field: {required}")

    def test_browser_closed_after_run(self):
        browser = self._make_browser()
        llm = MockLLMDriver()
        explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=browser,
            attempts_per_category=1, categories=["empty"],
        )
        self.assertTrue(browser.closed)

    def test_url_required(self):
        with self.assertRaises(ValueError):
            explore(
                url="", spec_path=self.spec_path,
                llm=MockLLMDriver(), browser=self._make_browser(),
            )

    def test_runs_without_spec_file(self):
        # No spec file → empty AC list → all findings are "uncovered".
        llm = MockLLMDriver(probes_by_category={"empty": [_probe_for_empty_signup()]})
        result = explore(
            url="https://example.test/signup", spec_path="/no/such/file.md",
            llm=llm, browser=self._make_browser(),
            attempts_per_category=1, categories=["empty"],
        )
        self.assertEqual(result["uncovered"], result["found"])

    def test_eight_category_default_satisfies_ac2(self):
        # AC2 of #84: ≥3 attempts per category across all 8 categories.
        # Re-asserts the per-category invariant precisely.
        llm = MockLLMDriver(flat_queue=[{"action": "noop"} for _ in range(30)])
        result = explore(
            url="https://example.test/signup", spec_path=self.spec_path,
            llm=llm, browser=self._make_browser(),
        )
        per_cat = result["stats"]["attempts_per_category"]
        self.assertEqual(len(per_cat), 8)
        for cat, n in per_cat.items():
            self.assertGreaterEqual(n, 3, msg=f"{cat} got only {n} attempts")


# -- summarise_findings -------------------------------------------------------

class SummariseFindingsTests(unittest.TestCase):
    def test_empty_input_returns_empty_candidates(self):
        out = summarise_findings([])
        self.assertEqual(out["found"], 0)
        self.assertEqual(out["candidates"], [])
        self.assertIn("triage_hint", out)

    def test_each_candidate_has_add_drop_later_shape(self):
        raw = [{
            "category": "empty",
            "repro_steps": ["go to /signup", "fill #email with ''"],
            "expected": "form rejects empty submission",
            "actual": "console error: validate(): email is required",
            "severity": "med",
            "covered_by_ac": None,
            "ac_link": "[[ac:empty-email-validation]]",
        }]
        out = summarise_findings(raw)
        self.assertEqual(out["found"], 1)
        self.assertEqual(out["uncovered"], 1)
        cand = out["candidates"][0]
        for key in ("n", "category", "name", "severity", "what",
                    "proposed_ac", "ac_slug", "ac_link", "repro_steps"):
            self.assertIn(key, cand)
        self.assertTrue(cand["proposed_ac"].startswith("AC<n>:"))
        self.assertTrue(cand["ac_link"].startswith("[[ac:"))

    def test_triage_hint_mentions_add_drop_later(self):
        out = summarise_findings([])
        hint = out["triage_hint"]
        for word in ("add", "drop", "later"):
            self.assertIn(word, hint)

    def test_covered_findings_carry_their_index(self):
        raw = [{
            "category": "empty", "repro_steps": [], "expected": "x", "actual": "y",
            "severity": "low", "covered_by_ac": 2, "ac_link": "",
        }]
        out = summarise_findings(raw)
        self.assertEqual(out["uncovered"], 0)
        self.assertEqual(out["candidates"][0]["covered_by_ac"], 2)


if __name__ == "__main__":
    unittest.main()
