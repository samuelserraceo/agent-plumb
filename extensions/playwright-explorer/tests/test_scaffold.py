"""Tests for the playwright-explorer scaffold.

Today these test that the protocol surface is in place and returns the
deferred-shape responses correctly. Real exploration tests land with the
agentic implementation in the follow-up SPEC.
"""

from __future__ import annotations

import json
import os
import sys
import unittest

# Make the parent directory importable
_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from server import handle_message, TOOLS, SERVER_NAME, SERVER_VERSION  # noqa: E402


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

    def test_explore_returns_deferred_shape(self):
        resp = handle_message({
            "jsonrpc": "2.0", "id": 3,
            "method": "tools/call",
            "params": {"name": "explore", "arguments": {"url": "https://example.com", "spec_path": "spec.md"}},
        })
        # Every deferred response sets isError=False (it's a status, not a failure
        # the caller should treat as broken). The CONTENT carries the deferred flag.
        decoded = json.loads(resp["result"]["content"][0]["text"])
        self.assertTrue(decoded.get("deferred"))
        self.assertEqual(decoded["query"], "explore")
        self.assertIn("scaffold", decoded["status"])
        self.assertIn("see", decoded)

    def test_unknown_query_returns_error(self):
        resp = handle_message({
            "jsonrpc": "2.0", "id": 4,
            "method": "tools/call",
            "params": {"name": "make_coffee", "arguments": {}},
        })
        decoded = json.loads(resp["result"]["content"][0]["text"])
        self.assertIn("error", decoded)
        self.assertTrue(resp["result"]["isError"])

    def test_simplified_protocol_path(self):
        # Same simplified-shape path as sdd-mcp-server: callers can pass
        # `{"query": ..., "args": ...}` and skip the JSON-RPC envelope.
        resp = handle_message({"query": "report_status", "args": {}})
        self.assertTrue(resp.get("deferred"))
        self.assertEqual(resp["query"], "report_status")

    def test_unknown_method(self):
        resp = handle_message({"jsonrpc": "2.0", "id": 5, "method": "tools/breathe"})
        self.assertIn("error", resp)
        self.assertEqual(resp["error"]["code"], -32601)

    def test_summarise_findings_returns_deferred(self):
        resp = handle_message({
            "jsonrpc": "2.0", "id": 6,
            "method": "tools/call",
            "params": {"name": "summarise_findings", "arguments": {"findings": []}},
        })
        decoded = json.loads(resp["result"]["content"][0]["text"])
        self.assertTrue(decoded.get("deferred"))
        self.assertEqual(decoded["query"], "summarise_findings")


if __name__ == "__main__":
    unittest.main()
