#!/usr/bin/env python3
"""SDD MCP server — JSON-RPC over stdio (with a simplified single-line fallback).

Read one JSON message per line from stdin, write one JSON response per
line to stdout. Two protocol shapes are accepted on the same socket — we
auto-detect by inspecting the inbound message.

1. **Minimal MCP** — JSON-RPC 2.0 messages with `jsonrpc: "2.0"`. Three
   methods are implemented:

   - `initialize` — handshake; returns server name/version/capabilities.
   - `tools/list` — returns the 6 query names + arg schemas.
   - `tools/call` — `{name, arguments}` invokes the query and returns
     `{content: [{type: "text", text: <json-encoded result>}]}` per the
     MCP tool-result convention.

2. **Simplified SDD** — `{"query": "<name>", "args": {...}}` per line.
   Returns `{"result": <data>}` on success or `{"error": "<reason>"}`.

Both shapes share the same query layer in `queries/`; the protocol shim
just dispatches. We default to the simplified shape when the inbound
message has a `query` key, and to MCP when it has `jsonrpc`.

`CLAUDE_PROJECT_DIR` (env var) overrides the project root; otherwise
we use the current working directory. This matches the rest of the
SDD framework's scripts (e.g. next-action.sh, resolve-parameters.sh).
"""

from __future__ import annotations

import json
import os
import sys
import traceback
from typing import Any, Dict

# Ensure the local `queries/` package is importable when the server is
# invoked by absolute path from elsewhere on the filesystem (which is
# how Claude Code's MCP harness will start us).
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from queries import REGISTRY  # noqa: E402  (import after sys.path mutation)


SERVER_NAME = "sdd-mcp-server"
SERVER_VERSION = "0.1.0"

# Per-tool argument schemas. Kept declarative so tools/list responds without
# re-introspecting the query modules (and so the schema is human-readable
# in this file).
_TOOL_SCHEMAS: Dict[str, Dict[str, Any]] = {
    "get_active_step": {
        "description": "Return the active feature's current open [ ] step.",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    "get_by_tag": {
        "description": "List feature entries from an INDEX.md status section.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tag": {
                    "type": "string",
                    "enum": ["in-flight", "shipped", "backlog", "blocked"],
                    "description": "Which INDEX.md section to read.",
                }
            },
            "required": ["tag"],
        },
    },
    "get_pattern": {
        "description": "Fetch one block from .sdd/patterns.md by slug.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "slug": {"type": "string", "description": "Pattern slug, e.g. 'auth-retry-logic'."}
            },
            "required": ["slug"],
        },
    },
    "get_references": {
        "description": "Find every place a slug is referenced across .sdd/.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "slug": {"type": "string", "description": "Feature/action/playbook slug."}
            },
            "required": ["slug"],
        },
    },
    "get_decisions_since": {
        "description": "Return decisions.md entries with timestamp >= since.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "since": {
                    "type": "string",
                    "description": "ISO-8601 UTC, e.g. '2026-04-28T00:00:00Z' or '2026-04-28'.",
                }
            },
            "required": ["since"],
        },
    },
    "search": {
        "description": "Opt-in semantic search over .sdd/ (requires provider config).",
        "inputSchema": {
            "type": "object",
            "properties": {"query": {"type": "string"}},
            "required": ["query"],
        },
    },
}


def _project_root() -> str:
    """Return the .sdd-bearing project root.

    We prefer `CLAUDE_PROJECT_DIR` (the convention the rest of the framework
    follows) and fall back to the current working directory.
    """
    return os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()


def _dispatch(name: str, args: Dict[str, Any]) -> Dict[str, Any]:
    """Run one query by name. Returns the query's dict result or an error dict."""
    fn = REGISTRY.get(name)
    if fn is None:
        return {"error": f"unknown query '{name}' — try one of: {', '.join(sorted(REGISTRY))}"}
    try:
        return fn(_project_root(), args or {})
    except Exception as exc:  # pragma: no cover — defensive surface
        return {
            "error": f"query '{name}' raised {type(exc).__name__}: {exc}",
            "trace": traceback.format_exc().splitlines()[-3:],
        }


# -- MCP-flavoured handlers ---------------------------------------------------

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
    tools = []
    for name in sorted(REGISTRY):
        meta = _TOOL_SCHEMAS.get(name, {})
        tools.append({
            "name": name,
            "description": meta.get("description", ""),
            "inputSchema": meta.get("inputSchema", {"type": "object"}),
        })
    return {"jsonrpc": "2.0", "id": req.get("id"), "result": {"tools": tools}}


def _handle_tools_call(req: Dict[str, Any]) -> Dict[str, Any]:
    params = req.get("params") or {}
    name = params.get("name")
    args = params.get("arguments") or {}
    result = _dispatch(name, args)
    # Presence of an `error` key is the source of truth for failures.
    # Some queries (e.g. get_active_step) return contextual errors that
    # also include success-shaped fields like `feature_path` or `phase` —
    # those previously slipped through as `isError: false`. Don't downgrade
    # any handler error: if the result has an `error` key, it's an error.
    is_error = isinstance(result, dict) and "error" in result
    # Per MCP convention: tool results carry a `content` array of typed parts.
    return {
        "jsonrpc": "2.0",
        "id": req.get("id"),
        "result": {
            "content": [{"type": "text", "text": json.dumps(result, ensure_ascii=False)}],
            "isError": is_error,
        },
    }


def _mcp_error(req: Dict[str, Any], code: int, message: str) -> Dict[str, Any]:
    return {
        "jsonrpc": "2.0",
        "id": req.get("id"),
        "error": {"code": code, "message": message},
    }


def handle_message(req: Dict[str, Any]) -> Dict[str, Any] | None:
    """Route one parsed JSON message to a response dict (or None for notifs).

    Public for testability — `tests/test_queries.py` calls this directly.
    """
    # Simplified shape: {query, args}
    if "query" in req:
        result = _dispatch(req["query"], req.get("args") or {})
        if isinstance(result, dict) and "error" in result and not any(
            k in result for k in ("feature_path", "matches", "entries", "referenced_in")
        ):
            return {"error": result["error"], **{k: v for k, v in result.items() if k != "error"}}
        return {"result": result}

    # MCP-flavoured shape: {jsonrpc, method, id, params}
    method = req.get("method")
    if method == "initialize":
        return _handle_initialize(req)
    if method == "tools/list":
        return _handle_tools_list(req)
    if method == "tools/call":
        return _handle_tools_call(req)
    if method in ("notifications/initialized", "initialized"):
        # Notifications — no response.
        return None
    if method is not None:
        return _mcp_error(req, -32601, f"method not found: {method}")

    return {"error": "unrecognised message — expected {query,args} or {jsonrpc,method,...}"}


def main() -> int:
    """Read JSON lines from stdin, write JSON lines to stdout. One per line."""
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            req = json.loads(raw)
        except json.JSONDecodeError as exc:
            sys.stdout.write(json.dumps({"error": f"invalid JSON: {exc}"}) + "\n")
            sys.stdout.flush()
            continue
        if not isinstance(req, dict):
            sys.stdout.write(json.dumps({"error": "request must be a JSON object"}) + "\n")
            sys.stdout.flush()
            continue
        resp = handle_message(req)
        if resp is None:
            continue  # notification — no reply
        sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
