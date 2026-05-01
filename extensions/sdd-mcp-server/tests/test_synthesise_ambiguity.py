"""T20 — Ambiguity surfaced (AC15, best-effort).

5 representative test cases — when the LLM produces an answer that
naturally surfaces multiple candidates, the response sets
ambiguity='multi-answer'. Best-effort: relies on the LLM's prompt-
following.
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


# 5 representative shapes the LLM might use to surface ambiguity
_AMBIGUOUS_ANSWERS = [
    "Two answers — [[001-waitlist]] says A, [[002-login]] says B. Which do you mean?",
    "There are two candidates: [[001-waitlist]] and [[002-login]]. Which one do you mean?",
    "Two candidates emerge: [[001-waitlist]] (one view) and [[002-login]] (another). Which do you mean?",
    "Which do you mean — [[001-waitlist]] or [[002-login]]?",
    "I see two answers: [[001-waitlist]] vs [[002-login]]. Which one do you mean?",
]

# Single-answer (no ambiguity) baseline
_UNAMBIGUOUS_ANSWER = "Postgres was picked — see [[001-waitlist]]."


class TestAmbiguity(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_five_representative_ambiguity_shapes(self):
        """Best-effort: 5 cases covering common phrasings — at least
        a majority should be detected as multi-answer."""
        detected = 0
        for i, ans in enumerate(_AMBIGUOUS_ANSWERS):
            # Use unique question per call so cache doesn't kick in
            result = synthesise(
                self.root,
                {"slug": "001-waitlist", "question": f"case-{i}", "format": "structured"},
                _llm_call=lambda q, c, cfg, _a=ans: _a,
            )
            if result.get("ambiguity") == "multi-answer":
                detected += 1
        # All 5 fixtures are deterministic and contain BOTH the 2+ cite
        # condition AND a disambiguation cue from the heuristic's list
        # ("which do you mean" / "two answers" / "two candidates" /
        # "which one"), so the heuristic should fire on every one.
        # CR feedback: keep the assertion equal to the fixture count so
        # any heuristic regression that drops a case fails the test.
        self.assertEqual(
            detected, len(_AMBIGUOUS_ANSWERS),
            msg=f"only {detected}/{len(_AMBIGUOUS_ANSWERS)} ambiguity cases detected; expected all"
        )

    def test_unambiguous_answer_no_ambiguity_marker(self):
        """Single-answer responses should NOT be flagged as ambiguous."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=lambda q, c, cfg: _UNAMBIGUOUS_ANSWER,
        )
        self.assertIsNone(result.get("ambiguity"))
