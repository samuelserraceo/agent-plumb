"""playwright-explorer MCP server.

Exposes three tools over JSON-RPC stdio:

  - `explore`           — drive a deployed feature URL through 8
                          edge-case categories, return findings.
  - `summarise_findings` — turn raw findings into the edge-case-sweep
                          add/drop/later triage shape.
  - `report_status`     — return stats from the last `explore` run
                          (or `{idle: true}` if nothing has run yet).

The server composes one LLMDriver + one BrowserDriver per `explore`
call. By default, drivers are built from the call args:

    {
      "url": "https://stage.example.com/feature",
      "spec_path": "/abs/path/.sdd/features/001-x/spec.md",
      "provider": {"endpoint": "...", "model": "...", "auth_env": "OPENAI_API_KEY"},
      "auth_cookie": {"name": "session", "value": "...", "domain": "stage.example.com", "path": "/"},
      "max_llm_calls": 50,
      "max_browser_actions": 200,
      "cost_limit_usd": 1.00,
      "headless": true,
      "viewport": {"width": 390, "height": 844}
    }

Tests substitute `_explore_factory` to inject mock drivers; this is
the test seam mentioned in #84 AC7.

Run from extensions/playwright-explorer/:

    python3 server.py        # stdio MCP loop
"""

from __future__ import annotations

import json
import os
import sys
import traceback
from typing import Any, Callable, Dict, Optional, Tuple

from drivers import (
    BrowserDriver,
    HttpLLMDriver,
    LLMDriver,
)
from explorer import explore as _run_explore, summarise_findings as _summarise


SERVER_NAME = "sdd-playwright-explorer"
SERVER_VERSION = "1.0.0"

# Last run's stats — populated by `explore`, read by `report_status`.
_LAST_RUN: Dict[str, Any] = {"idle": True}


# -- Tool registry ------------------------------------------------------------

TOOLS = {
    "explore": {
        "description": (
            "Drive a deployed feature URL via Playwright + an LLM, looking "
            "for edge cases the spec author didn't think to test. Returns "
            "structured findings with reproduction steps and a wiki-link "
            "suggestion for new acceptance criteria."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "Deployed feature URL to explore"},
                "spec_path": {"type": "string", "description": "Path to feature spec.md"},
                "provider": {"type": "object", "description": "LLM endpoint + model config"},
                "auth_cookie": {"type": "object", "description": "Optional cookie for authed pages"},
                "max_llm_calls": {"type": "integer", "default": 50},
                "max_browser_actions": {"type": "integer", "default": 200},
                "cost_limit_usd": {"type": "number", "default": 1.00},
                "headless": {"type": "boolean", "default": True},
                "viewport": {"type": "object"},
            },
            "required": ["url", "spec_path"],
        },
    },
    "summarise_findings": {
        "description": (
            "Turn a raw findings list (from `explore`) into the edge-case-sweep "
            "triage shape: each finding becomes a candidate with a category, "
            "severity, proposed AC sentence, and [[ac:<slug>]] wiki-link the "
            "user can `add` / `drop` / `later`."
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
            "Report the last explore run's stats: LLM calls used, browser "
            "actions used, estimated cost, halt reason, attempts per "
            "category, findings counts. Returns `{idle: true}` if no run "
            "has happened yet in this server session."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
}


# -- Driver factory (test seam) -----------------------------------------------

def _build_default_drivers(args: Dict[str, Any]) -> Tuple[LLMDriver, BrowserDriver]:
    """Default factory: HttpLLMDriver + PlaywrightBrowserDriver from args.

    Imports the Playwright driver lazily so the import doesn't fail
    when playwright isn't installed (tests use a mock factory).
    """
    provider = args.get("provider") or {}
    endpoint = provider.get("endpoint") or ""
    model = provider.get("model") or ""
    auth_env = provider.get("auth_env") or None
    if not endpoint or not model:
        raise ValueError(
            "explore: provider.endpoint + provider.model are required for live runs. "
            "Configure parameters.playwright_explorer in .sdd/config.md."
        )
    llm = HttpLLMDriver(endpoint=endpoint, model=model, auth_env=auth_env)
    # Lazy import — keeps the test path free of playwright as a hard dep.
    from drivers.browser import PlaywrightBrowserDriver  # noqa: WPS433
    browser = PlaywrightBrowserDriver(
        auth_cookie=args.get("auth_cookie"),
        headless=bool(args.get("headless", True)),
        viewport=args.get("viewport"),
    )
    return llm, browser


# Tests overwrite this to inject mock drivers without touching the dispatch.
_explore_factory: Callable[[Dict[str, Any]], Tuple[LLMDriver, BrowserDriver]] = _build_default_drivers


# -- Tool dispatch ------------------------------------------------------------

def _do_explore(args: Dict[str, Any]) -> Dict[str, Any]:
    global _LAST_RUN
    try:
        llm, browser = _explore_factory(args)
    except Exception as exc:
        return {"error": f"failed to build drivers: {exc}"}
    try:
        result = _run_explore(
            url=args.get("url") or "",
            spec_path=args.get("spec_path") or "",
            llm=llm,
            browser=browser,
            max_llm_calls=int(args.get("max_llm_calls", 50)),
            max_browser_actions=int(args.get("max_browser_actions", 200)),
            cost_limit_usd=float(args.get("cost_limit_usd", 1.00)),
        )
    except ValueError as exc:
        return {"error": str(exc)}
    _LAST_RUN = {
        "idle": False,
        "found": result["found"],
        "uncovered": result["uncovered"],
        "stats": result["stats"],
    }
    return result


def _do_summarise(args: Dict[str, Any]) -> Dict[str, Any]:
    findings = args.get("findings")
    if not isinstance(findings, list):
        return {"error": "summarise_findings: `findings` must be a list"}
    return _summarise(findings)


def _do_report_status(_args: Dict[str, Any]) -> Dict[str, Any]:
    return dict(_LAST_RUN)


_DISPATCH = {
    "explore": _do_explore,
    "summarise_findings": _do_summarise,
    "report_status": _do_report_status,
}


def _dispatch(name: str, args: Dict[str, Any]) -> Dict[str, Any]:
    if name not in _DISPATCH:
        return {"error": f"unknown query '{name}' — try one of: {', '.join(sorted(TOOLS))}"}
    return _DISPATCH[name](args)


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
        return _dispatch(req.get("query"), req.get("args", {}) or {})
    method = req.get("method", "")
    is_notification = "id" not in req
    if method == "initialize":
        return _handle_initialize(req)
    if method == "tools/list":
        return _handle_tools_list(req)
    if method == "tools/call":
        return _handle_tools_call(req)
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
        if resp is None:
            continue
        sys.stdout.write(json.dumps(resp) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
