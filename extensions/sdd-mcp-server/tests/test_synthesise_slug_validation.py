"""T30 — Slug sanitisation (AC23, §15 sweep): regex match, no path traversal."""

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


def _mock(q, c, cfg):
    return "x — see [[001-waitlist]]."


class TestSlugValidation(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def test_path_traversal_rejected(self):
        result = synthesise(
            self.root, {"slug": "../../etc/passwd", "question": "x", "format": "structured"},
            _llm_call=_mock,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("invalid slug", (result.get("reason") or "").lower())

    def test_space_in_slug_rejected(self):
        result = synthesise(
            self.root, {"slug": "001 waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("invalid slug", (result.get("reason") or "").lower())

    def test_slash_in_slug_rejected(self):
        result = synthesise(
            self.root, {"slug": "001/waitlist", "question": "x", "format": "structured"},
            _llm_call=_mock,
        )
        self.assertIs(result.get("ok"), False)
        self.assertIn("invalid slug", (result.get("reason") or "").lower())

    def test_special_chars_rejected(self):
        for bad in ("$evil", "001;rm -rf", "..\\windows"):
            with self.subTest(slug=bad):
                result = synthesise(
                    self.root, {"slug": bad, "question": "x", "format": "structured"},
                    _llm_call=_mock,
                )
                self.assertIs(result.get("ok"), False, msg=f"slug {bad!r} should be rejected")
                self.assertIn(
                    "invalid slug",
                    (result.get("reason") or "").lower(),
                    msg=f"slug {bad!r} should be rejected with the 'invalid slug' reason, got {result.get('reason')!r}",
                )

    def test_valid_slugs_pass(self):
        for ok_slug in ("001-waitlist", "pattern:auth-retry", "entity:User"):
            with self.subTest(slug=ok_slug):
                result = synthesise(
                    self.root, {"slug": ok_slug, "question": "x", "format": "structured"},
                    _llm_call=_mock,
                )
                # Either ok=True OR ok=False for non-cite-check reasons; the
                # POINT is the slug itself doesn't trip the validator.
                reason = (result.get("reason") or "").lower()
                self.assertNotIn("invalid slug", reason,
                                 msg=f"valid slug {ok_slug!r} wrongly rejected: {reason}")
