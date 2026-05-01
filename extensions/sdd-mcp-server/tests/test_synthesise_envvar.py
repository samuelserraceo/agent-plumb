"""T15 — ${ENV_VAR} indirection in auth_header resolves at runtime (AC10)."""

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


class TestEnvVarIndirection(unittest.TestCase):

    def setUp(self):
        self.root, self._cleanup = make_temp_project(with_tier3=True)
        # Patch the config to use ${MY_TOKEN} indirection
        cfg_path = os.path.join(self.root, ".sdd", "config.md")
        with open(cfg_path) as f:
            text = f.read()
        text = text.replace('auth_header: ""', 'auth_header: "${MY_FAKE_TOKEN}"')
        with open(cfg_path, "w") as f:
            f.write(text)

    def tearDown(self):
        self._cleanup()
        os.environ.pop("MY_FAKE_TOKEN", None)

    def test_envvar_resolved_to_actual_value(self):
        os.environ["MY_FAKE_TOKEN"] = "real-secret-from-env"

        captured = {}

        def _spy(q, c, cfg):
            captured["auth_header"] = cfg.get("auth_header")
            return "x — see [[001-waitlist]]."

        synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_spy,
        )
        self.assertEqual(captured.get("auth_header"), "real-secret-from-env")

    def test_envvar_missing_resolves_to_empty(self):
        """Unset env var → auth_header empty string (not raising)."""
        os.environ.pop("MY_FAKE_TOKEN", None)

        captured = {}

        def _spy(q, c, cfg):
            captured["auth_header"] = cfg.get("auth_header")
            return "x — see [[001-waitlist]]."

        synthesise(
            self.root, {"slug": "001-waitlist", "question": "x", "format": "structured"},
            _llm_call=_spy,
        )
        self.assertEqual(captured.get("auth_header"), "")
