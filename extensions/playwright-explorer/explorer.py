"""The exploratory-testing loop.

`explore(...)` cycles the LLM through eight edge-case categories,
asks for one probe per attempt, runs it through the browser driver,
and records anything that diverges from the LLM's expected outcome
or surfaces a new error as a finding. Cost-bounded: any of the three
budgets (LLM calls, browser actions, USD) trips a clean halt.

Findings shape (per AC4 in #84):

    {
      "found": int,
      "uncovered": int,
      "items": [
        {
          "category": str,
          "repro_steps": [str, ...],
          "expected": str,
          "actual": str,
          "severity": "low" | "med" | "high",
          "covered_by_ac": int | None,
          "ac_link": str,        # [[ac:<slug>]] suggestion (may be empty)
        }
      ],
      "stats": {
        "llm_calls": int,
        "browser_actions": int,
        "estimated_cost_usd": float,
        "halt_reason": str,
        "attempts_per_category": {category: count, ...}
      }
    }
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict, List, Optional

from drivers import BrowserDriver, LLMDriver


DEFAULT_CATEGORIES = (
    "empty",
    "max",
    "bad-input",
    "network",
    "concurrency",
    "auth",
    "mobile",
    "time-based",
)


# -- spec parsing -------------------------------------------------------------

_AC_LINE_RE = re.compile(r"(?m)^\s*[-*]?\s*\*?\*?AC\d+\*?\*?[:\s].+$")


def read_spec_acs(spec_path: str) -> List[str]:
    """Extract plain-text AC lines from a feature spec.

    Looks for an `## §11` (or `## 11.`) heading and returns each line
    starting with `AC<n>` until the next `##`. Returns [] if the file
    is missing or has no recognisable §11.
    """
    if not spec_path or not os.path.isfile(spec_path):
        return []
    try:
        with open(spec_path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return []
    # Find a §11 heading. Tolerate a few common forms.
    section_re = re.compile(
        r"(?ms)^##\s+(?:§\s*)?11[.\s].*?(?=^##\s+|\Z)",
    )
    match = section_re.search(text)
    if not match:
        return []
    body = match.group(0)
    return [line.strip() for line in _AC_LINE_RE.findall(body) if line.strip()]


# -- AC coverage heuristic ----------------------------------------------------

_TOKEN_RE = re.compile(r"[a-z0-9]+")


def _tokens(s: str) -> set:
    return set(_TOKEN_RE.findall(s.lower()))


def _covered_by_acs(expected: str, actual: str, acs: List[str]) -> Optional[int]:
    """Return the 1-based AC index whose tokens overlap ≥3 with the
    finding's expected/actual, or None.
    """
    finding_tokens = _tokens(expected) | _tokens(actual)
    finding_tokens -= _STOPWORDS
    if not finding_tokens:
        return None
    for idx, ac in enumerate(acs, start=1):
        ac_tokens = _tokens(ac) - _STOPWORDS
        overlap = len(finding_tokens & ac_tokens)
        if overlap >= 3:
            return idx
    return None


_STOPWORDS = {
    "the", "a", "an", "of", "to", "in", "is", "it", "for", "and", "or", "with",
    "ac", "user", "page", "shows", "show", "submit", "button", "form", "field",
    "value", "expected", "actual", "should", "must", "no", "be", "by", "on",
    "at", "as", "this", "that", "are", "was", "were", "has", "have", "but",
    "if", "from", "not", "do", "does", "when", "what",
}


# -- repro + slug helpers -----------------------------------------------------

_SLUG_NON_ALNUM = re.compile(r"[^a-z0-9]+")


def _slugify(text: str) -> str:
    """Lowercase, hyphen-separated. Used to build [[ac:<slug>]] links."""
    s = text.lower().strip()
    s = _SLUG_NON_ALNUM.sub("-", s)
    return s.strip("-")[:60] or "edge-case"


def _action_to_step(probe: Dict[str, Any]) -> str:
    action = probe.get("action", "noop")
    target = probe.get("target", "")
    value = probe.get("value", "")
    if action == "goto":
        return f"go to {target}"
    if action == "fill":
        return f"fill {target} with {value!r}"
    if action == "click":
        return f"click {target}"
    if action == "wait":
        return f"wait {target or value} ms"
    if action == "eval":
        return f"run js: {target}"
    return f"({action})"


def _severity_for(state: Dict[str, Any]) -> str:
    if state.get("network_errors"):
        return "high"
    if state.get("last_error") and "not found" in state.get("last_error", "").lower():
        return "med"
    if state.get("console_errors"):
        return "med"
    return "low"


# -- finding detection --------------------------------------------------------

def _detect_finding(
    *,
    state_before: Dict[str, Any],
    state_after: Dict[str, Any],
    expected: str,
) -> Optional[str]:
    """If the post-action state diverges from `expected` or surfaces a
    fresh error, return a one-sentence "actual" description. Else None.
    """
    new_console = (
        len(state_after.get("console_errors") or [])
        - len(state_before.get("console_errors") or [])
    )
    new_network = (
        len(state_after.get("network_errors") or [])
        - len(state_before.get("network_errors") or [])
    )
    last_error = state_after.get("last_error") or ""
    if new_network > 0:
        return f"network error appeared: {state_after['network_errors'][-1]}"
    if last_error:
        return f"action failed: {last_error}"
    if new_console > 0:
        return f"console error appeared: {state_after['console_errors'][-1]}"
    # Heuristic divergence: if the LLM said "should X" and the page has
    # no text matching X, flag it. Cheap; the user makes the call.
    if expected:
        expected_tokens = _tokens(expected) - _STOPWORDS
        text_tokens = _tokens(state_after.get("text") or "")
        if expected_tokens and not (expected_tokens & text_tokens):
            return f"expected outcome not visible on page: {expected[:120]}"
    return None


# -- the loop -----------------------------------------------------------------

class _Counters:
    def __init__(self):
        self.llm_calls = 0
        self.browser_actions = 0
        self.cost = 0.0
        self.halt_reason: str = ""
        self.attempts_per_category: Dict[str, int] = {}

    def attempt(self, category: str) -> None:
        self.attempts_per_category[category] = self.attempts_per_category.get(category, 0) + 1


def _run_probe(browser: BrowserDriver, probe: Dict[str, Any]) -> Dict[str, Any]:
    """Dispatch a probe to the right browser method. Returns the new state.

    `noop` returns the current snapshot without an action — no
    browser-action counter increment expected.
    """
    action = probe.get("action", "noop")
    target = probe.get("target", "")
    value = probe.get("value", "")
    if action == "fill":
        return browser.fill(target, value)
    if action == "click":
        return browser.click(target)
    if action == "goto":
        return browser.goto(target)
    if action == "wait":
        try:
            ms = int(value or target or 500)
        except (TypeError, ValueError):
            ms = 500
        return browser.wait(ms)
    if action == "eval":
        return browser.eval_js(target)
    return browser.snapshot()


def explore(
    *,
    url: str,
    spec_path: str,
    llm: LLMDriver,
    browser: BrowserDriver,
    max_llm_calls: int = 50,
    max_browser_actions: int = 200,
    cost_limit_usd: float = 1.00,
    categories: Optional[List[str]] = None,
    attempts_per_category: int = 3,
) -> Dict[str, Any]:
    if not url:
        raise ValueError("explore: url is required")
    cats = list(categories) if categories else list(DEFAULT_CATEGORIES)
    spec_acs = read_spec_acs(spec_path)
    counters = _Counters()
    items: List[Dict[str, Any]] = []
    history: List[Dict[str, Any]] = []
    cost_per_call = float(getattr(llm, "cost_per_call_usd", 0.0) or 0.0)

    def _budget_check() -> bool:
        if counters.llm_calls >= max_llm_calls:
            counters.halt_reason = "llm_budget"
            return False
        if counters.browser_actions >= max_browser_actions:
            counters.halt_reason = "browser_budget"
            return False
        if cost_limit_usd and counters.cost >= cost_limit_usd:
            counters.halt_reason = "cost_budget"
            return False
        return True

    # Initial navigation.
    state = browser.goto(url)
    counters.browser_actions += 1
    initial_url = state.get("url", url)

    try:
        for category in cats:
            if not _budget_check():
                break
            for _attempt in range(attempts_per_category):
                if not _budget_check():
                    break
                state_before = browser.snapshot()
                probe = llm.propose_probe(
                    category=category,
                    state=state_before,
                    spec_acs=spec_acs,
                    history=history,
                )
                counters.llm_calls += 1
                counters.cost += cost_per_call
                counters.attempt(category)
                history.append({"category": category, "probe": probe})
                if probe.get("action") == "noop":
                    continue
                if not _budget_check():
                    break
                state_after = _run_probe(browser, probe)
                counters.browser_actions += 1
                actual = _detect_finding(
                    state_before=state_before,
                    state_after=state_after,
                    expected=probe.get("expected", ""),
                )
                if actual:
                    repro = [f"go to {initial_url}", _action_to_step(probe)]
                    severity = _severity_for(state_after)
                    expected_text = probe.get("expected", "") or "(no expectation supplied)"
                    covered_idx = _covered_by_acs(expected_text, actual, spec_acs)
                    items.append({
                        "category": category,
                        "repro_steps": repro,
                        "expected": expected_text,
                        "actual": actual,
                        "severity": severity,
                        "covered_by_ac": covered_idx,
                        "ac_link": f"[[ac:{_slugify(probe.get('rationale') or expected_text)}]]"
                                   if covered_idx is None else "",
                    })
            # for/else: the `else` runs when the inner attempts loop completes
            # normally; `continue` then proceeds to the next category. If the
            # inner loop broke early (budget hit), `else` is skipped and the
            # `break` below propagates out of the category loop too.
            else:
                continue
            break
    finally:
        try:
            browser.close()
        except Exception:
            pass  # best-effort; close failures shouldn't mask findings

    if not counters.halt_reason:
        counters.halt_reason = "complete"

    uncovered = sum(1 for it in items if it["covered_by_ac"] is None)
    return {
        "found": len(items),
        "uncovered": uncovered,
        "items": items,
        "stats": {
            "llm_calls": counters.llm_calls,
            "browser_actions": counters.browser_actions,
            "estimated_cost_usd": round(counters.cost, 4),
            "halt_reason": counters.halt_reason,
            "attempts_per_category": dict(counters.attempts_per_category),
        },
    }


# -- post-processing for triage ----------------------------------------------

def summarise_findings(findings: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Turn raw findings into the edge-case-sweep `add / drop / later`
    triage shape. The output is what the user sees in the action prose.

    Each candidate gets a short name, a category, a severity, a
    proposed AC sentence, and a wiki-link slug. The user replies
    `add 1,2; drop 3; later 4` to triage.
    """
    candidates = []
    for n, item in enumerate(findings or [], start=1):
        category = item.get("category") or "edge-case"
        actual = item.get("actual") or ""
        expected = item.get("expected") or ""
        severity = item.get("severity") or "low"
        # Short name: first 60 chars of `actual`, sanitised.
        name = actual.split(":", 1)[0].strip().strip(".") or category
        if len(name) > 60:
            name = name[:57] + "..."
        proposed_ac = _propose_ac_text(expected, actual)
        ac_slug = _slugify(name or proposed_ac)
        candidates.append({
            "n": n,
            "category": category,
            "name": name,
            "severity": severity,
            "what": actual,
            "proposed_ac": proposed_ac,
            "ac_slug": ac_slug,
            "ac_link": f"[[ac:{ac_slug}]]",
            "repro_steps": item.get("repro_steps", []),
            "covered_by_ac": item.get("covered_by_ac"),
        })
    return {
        "found": len(candidates),
        "uncovered": sum(1 for c in candidates if c["covered_by_ac"] is None),
        "candidates": candidates,
        "triage_hint": (
            "Reply `add 1,2; drop 3; later 4`. "
            "Each `add` becomes a new AC + a new BUILD task. "
            "Each `drop` is discarded. Each `later` is recorded under "
            "Deferred edge cases for next iteration."
        ),
    }


def _propose_ac_text(expected: str, actual: str) -> str:
    """Compose a one-sentence AC suggestion the user can edit verbatim."""
    if expected:
        return f"AC<n>: {expected.rstrip('.')}."
    if actual:
        return f"AC<n>: page must NOT exhibit: {actual.rstrip('.')}."
    return "AC<n>: <fill in the expected behaviour>."
