"""T24 — Live Ollama+Gemma integration (wire-shape tests).

The IMPLEMENTATION is in synthesise.py's `_real_llm_call`. This test
file verifies the HTTP request shape + response parsing + error
mapping using `unittest.mock.patch` on urllib.request.urlopen — so it
runs deterministically without a real Ollama instance.

The actual end-to-end against a real running Ollama is AC18
[PROD-ONLY] — Sam walks that manually after the first deploy per §12.

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_synthesise_ollama_live
"""

from __future__ import annotations

import io
import json
import os
import sys
import unittest
import urllib.error
from unittest.mock import MagicMock, patch

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries.synthesise import (  # noqa: E402
    _real_llm_call,
    _ProviderRateLimited,
    _ProviderUnreachable,
    _build_prompt,
)


def _mock_response(payload: dict) -> MagicMock:
    """Stand-in for urllib's response context manager."""
    resp = MagicMock()
    resp.read.return_value = json.dumps(payload).encode("utf-8")
    resp.__enter__ = lambda self: self
    resp.__exit__ = lambda self, *args: None
    return resp


_DEFAULT_CFG = {
    "endpoint": "http://127.0.0.1:11434",
    "model": "gemma2:2b",
    "auth_header": "",
}


class TestRealLLMCallWireShape(unittest.TestCase):

    def test_posts_to_api_chat_endpoint(self):
        with patch("urllib.request.urlopen") as mock_open:
            mock_open.return_value = _mock_response(
                {"message": {"role": "assistant", "content": "hi"}}
            )
            _real_llm_call("q", [{"slug": "001-x", "path": "x.md", "text": "..."}], _DEFAULT_CFG)
            req = mock_open.call_args[0][0]
            self.assertEqual(req.full_url, "http://127.0.0.1:11434/api/chat")
            self.assertEqual(req.method, "POST")

    def test_body_contains_model_and_messages(self):
        with patch("urllib.request.urlopen") as mock_open:
            mock_open.return_value = _mock_response(
                {"message": {"role": "assistant", "content": "hi"}}
            )
            _real_llm_call("why?", [{"slug": "001-x", "path": "x.md", "text": "data"}], _DEFAULT_CFG)
            req = mock_open.call_args[0][0]
            body = json.loads(req.data.decode("utf-8"))
            self.assertEqual(body["model"], "gemma2:2b")
            self.assertEqual(body["stream"], False)
            self.assertIsInstance(body["messages"], list)
            self.assertEqual(body["messages"][0]["role"], "user")
            self.assertIn("why?", body["messages"][0]["content"])

    def test_response_content_extracted(self):
        with patch("urllib.request.urlopen") as mock_open:
            mock_open.return_value = _mock_response(
                {"message": {"role": "assistant", "content": "Postgres — see [[001-x]]."}}
            )
            result = _real_llm_call("q", [{"slug": "001-x", "path": "x.md", "text": "data"}], _DEFAULT_CFG)
            self.assertEqual(result, "Postgres — see [[001-x]].")

    def test_auth_header_added_when_configured(self):
        cfg = {**_DEFAULT_CFG, "auth_header": "Bearer abc123"}
        with patch("urllib.request.urlopen") as mock_open:
            mock_open.return_value = _mock_response(
                {"message": {"role": "assistant", "content": "hi"}}
            )
            _real_llm_call("q", [{"slug": "001-x", "path": "x.md", "text": "."}], cfg)
            req = mock_open.call_args[0][0]
            self.assertEqual(req.get_header("Authorization"), "Bearer abc123")

    def test_no_auth_header_when_empty(self):
        with patch("urllib.request.urlopen") as mock_open:
            mock_open.return_value = _mock_response(
                {"message": {"role": "assistant", "content": "hi"}}
            )
            _real_llm_call("q", [{"slug": "001-x", "path": "x.md", "text": "."}], _DEFAULT_CFG)
            req = mock_open.call_args[0][0]
            # No Authorization header set
            self.assertIsNone(req.get_header("Authorization"))


class TestRealLLMCallErrorMapping(unittest.TestCase):

    def test_429_maps_to_rate_limited(self):
        err = urllib.error.HTTPError(
            "http://x", 429, "Too Many Requests", {}, io.BytesIO(b"")
        )
        with patch("urllib.request.urlopen", side_effect=err):
            with self.assertRaises(_ProviderRateLimited):
                _real_llm_call("q", [{"slug": "x", "path": "x.md", "text": "."}], _DEFAULT_CFG)

    def test_500_maps_to_unreachable(self):
        err = urllib.error.HTTPError(
            "http://x", 500, "Server Error", {}, io.BytesIO(b"")
        )
        with patch("urllib.request.urlopen", side_effect=err):
            with self.assertRaises(_ProviderUnreachable):
                _real_llm_call("q", [{"slug": "x", "path": "x.md", "text": "."}], _DEFAULT_CFG)

    def test_url_error_maps_to_unreachable(self):
        err = urllib.error.URLError("Connection refused")
        with patch("urllib.request.urlopen", side_effect=err):
            with self.assertRaises(_ProviderUnreachable):
                _real_llm_call("q", [{"slug": "x", "path": "x.md", "text": "."}], _DEFAULT_CFG)

    def test_connection_error_maps_to_unreachable(self):
        with patch("urllib.request.urlopen", side_effect=ConnectionRefusedError("nope")):
            with self.assertRaises(_ProviderUnreachable):
                _real_llm_call("q", [{"slug": "x", "path": "x.md", "text": "."}], _DEFAULT_CFG)

    def test_malformed_json_response(self):
        resp = MagicMock()
        resp.read.return_value = b"not-json"
        resp.__enter__ = lambda self: self
        resp.__exit__ = lambda self, *args: None
        with patch("urllib.request.urlopen", return_value=resp):
            with self.assertRaises(RuntimeError):
                _real_llm_call("q", [{"slug": "x", "path": "x.md", "text": "."}], _DEFAULT_CFG)

    def test_missing_message_content_raises(self):
        with patch("urllib.request.urlopen") as mock_open:
            mock_open.return_value = _mock_response({"done": True})  # no message field
            with self.assertRaises(RuntimeError):
                _real_llm_call("q", [{"slug": "x", "path": "x.md", "text": "."}], _DEFAULT_CFG)


class TestPromptShape(unittest.TestCase):

    def test_prompt_includes_question(self):
        prompt = _build_prompt("why postgres?", [{"slug": "001-x", "path": "x.md", "text": "data"}])
        self.assertIn("why postgres?", prompt)

    def test_prompt_includes_chunks_with_slugs(self):
        prompt = _build_prompt("q", [
            {"slug": "001-foo", "path": "a.md", "text": "alpha"},
            {"slug": "002-bar", "path": "b.md", "text": "beta"},
        ])
        self.assertIn("[[001-foo]]", prompt)
        self.assertIn("[[002-bar]]", prompt)
        self.assertIn("alpha", prompt)
        self.assertIn("beta", prompt)

    def test_prompt_instructs_cite_only(self):
        prompt = _build_prompt("q", [{"slug": "x", "path": "x.md", "text": "."}])
        # Key instruction phrases that constrain the model
        self.assertIn("ONLY", prompt)  # "use ONLY these chunks"
        self.assertIn("Do NOT invent", prompt)
