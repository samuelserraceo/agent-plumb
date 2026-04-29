"""playwright-explorer MCP server — scaffold + protocol surface only.

⚠️ STATUS: scaffold (v0.13.x). The agentic Playwright-driving logic is
deferred to a follow-up SPEC. Calling the `explore` query today returns
a `{"deferred": ...}` response with a pointer at the open work.

Once the follow-up SPEC ships:

  - `explore` runs the actual exploration loop (LLM picks inputs,
    Playwright drives the browser, findings collected)
  - `summarise_findings` turns raw findings into the edge-case-sweep
    `add` / `drop` / `later` triage shape
  - `report_status` reports cost / actions used / findings count
    midway through long runs

Until then this server is a deliberate stub: it registers, accepts
JSON-RPC tool/call requests on stdio, and returns structured "deferred"
errors so callers know the surface exists but isn't backed yet.

Run from extensions/playwright-explorer/:

    python3 server.py        # stdio MCP loop

Same protocol shape as extensions/sdd-mcp-server/.
"""

from __future__ import annotations

import json
import os
import sys
import traceback
from typing import Any, Dict, Optional


SERVER_NAME = "sdd-playwright-explorer"
SERVER_VERSION = "0.0.1-scaffold"

# --- Tool registry -----------------------------------------------------------

TOOLS = {
    "explore": {
        "description": (
            "Drive a deployed feature URL via Playwright + an LLM, looking "
            "for edge cases the spec author didn't think to test. Returns a "
            "list of findings flagged as 'covered by current ACs' or 'NEW'. "
            "STATUS: scaffold; agentic logic deferred (see README)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "Deployed feature URL to explore"},
                "spec_path": {"type": "string", "description": "Path to feature spec.md"},
                "max_llm_calls": {"type": "integer", "default": 50},
                "max_browser_actions": {"type": "integer", "default": 200},
            },
            "required": ["url", "spec_path"],
        },
    },
    "summarise_findings": {
        "description": (
            "Turn a raw findings list (from `explore`) into the edge-case-sweep "
            "triage shape: each finding gets a category, severity, and "
            "proposed-AC text the user can `add` / `drop` / `later`. "
            "STATUS: scaffold."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "findings": {"type": "array"},
            },
            "required": ["findings"],
        },
    },
    "report_status": {
        "description": (
            "Report current run status: LLM calls used / budget, browser "
            "actions used / budget, findings collected so far. "
            "STATUS: scaffold."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
}


def _deferred_response(query_name: str) -> Dict[str, Any]:
    return {
        "deferred": True,
        "query": query_name,
        "status": "scaffold — agentic implementation pending follow-up SPEC",
        "next": (
            "Open via `/start \"Playwright-explorer agentic implementation\"` "
            "to start the SPEC. The MCP protocol surface is in place; the "
            "implementation fills in the explore loop + LLM provider + "
            "Playwright driver."
        ),
        "see": "extensions/playwright-explorer/README.md",
    }


def _dispatch(name: str, args: Dict[str, Any]) -> Dict[str, Any]:
    if name not in TOOLS:
        return {"error": f"unknown query '{name}' — try one of: {', '.join(sorted(TOOLS))}"}
    # Until the follow-up SPEC lands, every query returns a deferred response.
    # The shape of the response is the contract; the contents are what gets
    # filled in later.
    return _deferred_response(name)


# --- MCP-flavoured handlers --------------------------------------------------

def _handle_initialize(req: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "jsonrpc": "2.0",
        "id": req.get("id"),
        "result": {
            "protocolVersion": "2024-11-05",
            "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            "capabilities": {"tools": {"listChanged": False}},
        },
    }


def _handle_tools_list(req: Dict[str, Any]) -> Dict[str, Any]:
    tools = [
        {"name": name, "description": tool["description"], "inputSchema": tool["inputSchema"]}
        for name, tool in TOOLS.items()
    ]
    return {
        "jsonrpc": "2.0",
        "id": req.get("id"),
        "result": {"tools": tools},
    }


def _handle_tools_call(req: Dict[str, Any]) -> Dict[str, Any]:
    params = req.get("params", {}) or {}
    name = params.get("name")
    args = params.get("arguments", {}) or {}
    result = _dispatch(name, args)
    is_error = isinstance(result, dict) and "error" in result
    return {
        "jsonrpc": "2.0",
        "id": req.get("id"),
        "result": {
            "content": [{"type": "text", "text": json.dumps(result)}],
            "isError": is_error,
        },
    }


def handle_message(req: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Dispatch a single JSON-RPC request. Returns None for notifications
    (no `id` field), per JSON-RPC 2.0 — notifications must NOT receive a
    response. Supports the simplified `{"query": ..., "args": ...}` path
    (same as sdd-mcp-server) for callers that don't speak full MCP."""
    if "query" in req and "method" not in req:
        # Simplified path — always returns a result (this is our own
        # convention, not JSON-RPC, so notifications don't apply).
        result = _dispatch(req.get("query"), req.get("args", {}) or {})
        return result
    method = req.get("method", "")
    is_notification = "id" not in req
    if method == "initialize":
        return _handle_initialize(req)
    if method == "tools/list":
        return _handle_tools_list(req)
    if method == "tools/call":
        return _handle_tools_call(req)
    # Common MCP notification: notifications/initialized has no id and
    # expects no response.
    if is_notification:
        return None
    return {
        "jsonrpc": "2.0",
        "id": req.get("id"),
        "error": {"code": -32601, "message": f"Method not found: {method}"},
    }


def main():
    """Stdio loop: read one JSON message per line, write one response."""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception as exc:
            sys.stdout.write(json.dumps({"error": f"bad JSON: {exc}"}) + "\n")
            sys.stdout.flush()
            continue
        try:
            resp = handle_message(req)
        except Exception:
            resp = {"error": traceback.format_exc().splitlines()[-1]}
        # Notifications return None — JSON-RPC says we MUST NOT respond
        # to them, so skip the write and continue the loop.
        if resp is None:
            continue
        sys.stdout.write(json.dumps(resp) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
