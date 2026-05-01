"""Protocol surface + dispatch tests for the playwright-explorer MCP server.

The server exposes three tools — `explore`, `summarise_findings`,
`report_status` — over JSON-RPC stdio. These tests mock out the
driver factory so they don't need an LLM endpoint or a browser
install; the loop they exercise is the real explorer code.
"""

from __future__ import annotations

import json
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

import server  # noqa: E402
from server import handle_message, TOOLS, SERVER_NAME, SERVER_VERSION  # noqa: E402
from drivers import MockLLMDriver, MockBrowserDriver  # noqa: E402


_TEST_PAGES = {
    "https://example.test/signup": {
        "title": "Signup",
        "text": "Welcome — enter your email",
        "selectors": {"#email": "fillable", ".submit": "clickable"},
        "on_fill": {
            "#email": lambda v: ({"console_errors": ["validate(): required"]} if not v else {}),
        },
        "status_code": 200,
    },
}


def _mock_factory(_args):
    llm = MockLLMDriver(probes_by_category={
        "empty": [{
            "action": "fill", "target": "#email", "value": "",
            "expected": "form rejects empty email",
            "rationale": "spec misses empty submission",
        }],
    })
    browser = MockBrowserDriver(pages=_TEST_PAGES)
    return llm, browser


class _FactoryOverrideMixin:
    """Patches server._explore_factory for the duration of each test."""

    def setUp(self):
        self._orig_factory = server._explore_factory
        server._explore_factory = _mock_factory
        # Reset last-run state — tests must not pollute each other.
        server._LAST_RUN = {"idle": True}

    def tearDown(self):
        server._explore_factory = self._orig_factory


class ProtocolSurfaceTests(unittest.TestCase):
    def test_initialize_returns_server_info(self):
        resp = handle_message({"jsonrpc": "2.0", "id": 1, "method": "initialize"})
        self.assertEqual(resp["jsonrpc"], "2.0")
        self.assertIn("serverInfo", resp["result"])
        self.assertEqual(resp["result"]["serverInfo"]["name"], SERVER_NAME)
        self.assertEqual(resp["result"]["serverInfo"]["version"], SERVER_VERSION)

    def test_tools_list_includes_three_queries(self):
        resp = handle_message({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        names = {t["name"] for t in resp["result"]["tools"]}
        self.assertEqual(names, {"explore", "summarise_findings", "report_status"})

    def test_unknown_method(self):
        resp = handle_message({"jsonrpc": "2.0", "id": 5, "method": "tools/breathe"})
        self.assertIn("error", resp)
        self.assertEqual(resp["error"]["code"], -32601)

    def test_unknown_query_returns_error(self):
        resp = handle_message({
            "jsonrpc": "2.0", "id": 4,
            "method": "tools/call",
            "params": {"name": "make_coffee", "arguments": {}},
        })
        decoded = json.loads(resp["result"]["content"][0]["text"])
        self.assertIn("error", decoded)
        self.assertTrue(resp["result"]["isError"])

    def test_simplified_protocol_path_for_unknown_query(self):
        # The simplified `{"query": ..., "args": ...}` path still routes.
        resp = handle_message({"query": "make_coffee"})
        self.assertIn("error", resp)


class ExploreDispatchTests(_FactoryOverrideMixin, unittest.TestCase):
    def test_explore_tools_call_returns_findings(self):
        resp = handle_message({
            "jsonrpc": "2.0", "id": 3,
            "method": "tools/call",
            "params": {"name": "explore", "arguments": {
                "url": "https://example.test/signup",
                "spec_path": "/no/such/spec.md",
                "max_llm_calls": 10,
                "max_browser_actions": 10,
            }},
        })
        decoded = json.loads(resp["result"]["content"][0]["text"])
        self.assertFalse(resp["result"]["isError"])
        self.assertGreaterEqual(decoded["found"], 1)
        self.assertIn("items", decoded)
        self.assertIn("stats", decoded)

    def test_explore_simplified_path(self):
        resp = handle_message({
            "query": "explore",
            "args": {
                "url": "https://example.test/signup",
                "spec_path": "/no/such/spec.md",
                "max_llm_calls": 10,
                "max_browser_actions": 10,
            },
        })
        self.assertIn("found", resp)
        self.assertIn("items", resp)

    def test_explore_records_last_run_state(self):
        # Before the run, report_status returns idle.
        idle = handle_message({"query": "report_status"})
        self.assertTrue(idle.get("idle"))
        # Run explore.
        handle_message({
            "query": "explore",
            "args": {
                "url": "https://example.test/signup",
                "spec_path": "",
                "max_llm_calls": 10,
                "max_browser_actions": 10,
            },
        })
        # After the run, report_status returns the stats.
        after = handle_message({"query": "report_status"})
        self.assertFalse(after.get("idle"))
        self.assertIn("stats", after)
        self.assertIn("halt_reason", after["stats"])

    def test_explore_propagates_value_errors(self):
        resp = handle_message({"query": "explore", "args": {"url": "", "spec_path": ""}})
        self.assertIn("error", resp)


class SummariseDispatchTests(unittest.TestCase):
    def test_summarise_simplified_path(self):
        resp = handle_message({
            "query": "summarise_findings",
            "args": {"findings": [{
                "category": "empty",
                "repro_steps": ["go to /x", "fill"],
                "expected": "x",
                "actual": "y",
                "severity": "low",
                "covered_by_ac": None,
                "ac_link": "[[ac:x]]",
            }]},
        })
        self.assertEqual(resp["found"], 1)
        self.assertEqual(resp["candidates"][0]["category"], "empty")
        self.assertIn("triage_hint", resp)

    def test_summarise_rejects_non_list(self):
        resp = handle_message({"query": "summarise_findings", "args": {"findings": "x"}})
        self.assertIn("error", resp)

    def test_summarise_via_jsonrpc(self):
        resp = handle_message({
            "jsonrpc": "2.0", "id": 7,
            "method": "tools/call",
            "params": {"name": "summarise_findings", "arguments": {"findings": []}},
        })
        decoded = json.loads(resp["result"]["content"][0]["text"])
        self.assertEqual(decoded["found"], 0)
        self.assertFalse(resp["result"]["isError"])


class ReportStatusDispatchTests(unittest.TestCase):
    def setUp(self):
        server._LAST_RUN = {"idle": True}

    def test_report_status_idle_when_no_run(self):
        resp = handle_message({"query": "report_status"})
        self.assertTrue(resp.get("idle"))

    def test_report_status_jsonrpc(self):
        resp = handle_message({
            "jsonrpc": "2.0", "id": 8,
            "method": "tools/call",
            "params": {"name": "report_status", "arguments": {}},
        })
        decoded = json.loads(resp["result"]["content"][0]["text"])
        self.assertTrue(decoded.get("idle"))


class DefaultDriverFactoryTests(unittest.TestCase):
    """The default factory wants provider.endpoint + provider.model.
    Live integration is exercised manually; here we just check the
    error path so misconfiguration surfaces a plain-English message.
    """

    def test_missing_provider_raises_value_error(self):
        with self.assertRaises(ValueError) as ctx:
            server._build_default_drivers({"url": "x"})
        self.assertIn("provider.endpoint", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
