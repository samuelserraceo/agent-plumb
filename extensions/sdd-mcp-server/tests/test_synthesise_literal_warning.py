"""T16 — Literal-token warning on common provider key patterns (AC11).

If a user pastes a real-looking key directly into auth_header (rather
than using ${ENV_VAR} indirection), the framework prints a warning
to stderr so they can fix it before committing.
"""

from __future__ import annotations

import io
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries import synthesise  # noqa: E402
from tests.conftest import make_temp_project  # noqa: E402


class TestLiteralTokenWarning(unittest.TestCase):
    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)

    def tearDown(self):
        self._cleanup()

    def _set_auth(self, value: str) -> None:
        """Replace ONLY the tier3 block's `auth_header` value, not any
        other tier (e.g. semantic_search) that might also have one.

        CR cycle 5: previous form did a global text.replace which would
        scribble over every `auth_header: ""` regardless of which
        nested block it lived under. The test fixture only has one
        today, but future fixtures (or downstream projects mirroring
        the test shape) could have several — fix the replacement to
        scope to the tier3 block.
        """
        cfg_path = os.path.join(self.root, ".sdd", "config.md")
        with open(cfg_path) as f:
            text = f.read()
        # Locate the tier3 block under parameters.mcp. Replace the next
        # `auth_header: ""` after `tier3:` only.
        tier3_idx = text.find("tier3:")
        if tier3_idx == -1:
            raise RuntimeError("tier3 block missing from fixture config.md")
        # Slice into "before tier3" + "tier3 block + after". Replace
        # the first `auth_header: ""` in the second slice only.
        head = text[:tier3_idx]
        tail = text[tier3_idx:]
        tail = tail.replace('auth_header: ""', f'auth_header: "{value}"', 1)
        with open(cfg_path, "w") as f:
            f.write(head + tail)

    def _capture_stderr_during_synth(self) -> str:
        old_stderr = sys.stderr
        sys.stderr = captured = io.StringIO()
        try:
            synthesise(
                self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
                _llm_call=lambda q, c, cfg: "x — see [[001-waitlist]].",
            )
        finally:
            sys.stderr = old_stderr
        return captured.getvalue()

    def test_openai_style_key_triggers_warning(self):
        self._set_auth("sk-AbCdEfGhIjKlMnOpQrStUvWxYz1234567890")
        stderr = self._capture_stderr_during_synth()
        self.assertIn("warning", stderr.lower())
        self.assertIn("auth_header", stderr.lower())

    def test_stripe_live_key_triggers_warning(self):
        self._set_auth("sk_live_AbCdEfGhIjKlMnOpQrStUvWxYz1234567890")
        stderr = self._capture_stderr_during_synth()
        self.assertIn("warning", stderr.lower())

    def test_envvar_indirection_does_not_trigger_warning(self):
        self._set_auth("${SOME_VAR}")
        stderr = self._capture_stderr_during_synth()
        self.assertNotIn("warning", stderr.lower())
