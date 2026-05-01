"""T21 — Empty corpus spelled out (AC16, best-effort).

5 representative test cases for what an LLM might say when the corpus
contains nothing relevant. The behavioural floor is 'no silent return'
— the response must surface either an explicit no-result message OR
fall back to raw chunks; never an empty answer pretending it found
something.
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


# 5 LLM responses for the empty / nothing-relevant case
_EMPTY_RESPONSES = [
    "Nothing in your project covers that.",
    "I couldn't find anything in your project. The closest thing is [[001-waitlist]] but it's tangential.",
    "No relevant content found in .sdd/. Want me to broaden?",
    "Couldn't find an answer. Closest match: [[001-waitlist]] (not really about that).",
    "I don't see anything that addresses that. Want me to search more broadly?",
]


class TestEmptyCorpus(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_five_empty_response_shapes(self):
        """Best-effort: each must produce a result that's either ok=True
        with content, OR ok=False with a clear reason — never silent."""
        for i, response in enumerate(_EMPTY_RESPONSES):
            result = synthesise(
                self.root,
                {"slug": "001-waitlist", "question": f"empty-q-{i}", "format": "structured"},
                _llm_call=lambda q, c, cfg, _r=response: _r,
            )
            # Either ok=True with non-empty answer, or ok=False with a reason.
            if result.get("ok"):
                self.assertTrue(
                    (result.get("answer") or "").strip() != "",
                    msg=f"case {i}: ok=True but answer is empty"
                )
            else:
                self.assertTrue(
                    (result.get("reason") or "").strip() != "",
                    msg=f"case {i}: ok=False but no reason given"
                )

    def test_explicit_no_result_response_passes_cite_check(self):
        """An empty-corpus response with NO citations is still ok=True
        (no broken cite-check; no synthesis, just an honest 'nothing found')."""
        result = synthesise(
            self.root,
            {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=lambda q, c, cfg: "Nothing in your project covers that.",
        )
        self.assertTrue(result.get("ok"),
                        msg="empty-result answer with no cites should pass cite-check trivially")
        self.assertEqual(result.get("cite_chunks"), [])
