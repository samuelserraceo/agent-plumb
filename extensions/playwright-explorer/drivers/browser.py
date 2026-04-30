"""Browser driver abstraction.

The explorer drives a browser through this interface. Implementations:

  - MockBrowserDriver: in-memory state machine. Lets tests assert that
    the explorer issued the right sequence of actions and observed the
    right state without spinning up Chromium.
  - PlaywrightBrowserDriver: wraps Playwright's sync API. Imports
    playwright lazily so the test path doesn't require it installed.

The driver returns a `state` dict after every action with a stable
shape — `url`, `title`, `text`, `console_errors`, `network_errors`,
`status_code`. The explorer compares state-deltas to the LLM's
`expected` to decide whether to record a finding.

If a real browser action raises (selector not found, timeout, etc.),
the driver catches it and returns a state with `last_error` populated
rather than re-raising. The explorer treats `last_error` as a
candidate finding signal.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional


# Stable state shape — every driver returns one of these per action.
def _empty_state() -> Dict[str, Any]:
    return {
        "url": "",
        "title": "",
        "text": "",
        "console_errors": [],
        "network_errors": [],
        "status_code": 0,
        "last_error": "",
    }


class BrowserDriver(ABC):
    @abstractmethod
    def goto(self, url: str) -> Dict[str, Any]: ...

    @abstractmethod
    def fill(self, selector: str, value: str) -> Dict[str, Any]: ...

    @abstractmethod
    def click(self, selector: str) -> Dict[str, Any]: ...

    @abstractmethod
    def wait(self, ms: int) -> Dict[str, Any]: ...

    @abstractmethod
    def eval_js(self, code: str) -> Dict[str, Any]: ...

    @abstractmethod
    def snapshot(self) -> Dict[str, Any]:
        """Return current state without taking an action."""

    @abstractmethod
    def close(self) -> None: ...


# -- mock (used by tests) -----------------------------------------------------

class MockBrowserDriver(BrowserDriver):
    """In-memory mock. Construct with a `pages` dict keyed by URL.

    Each page entry shape:
        {
          "title": str,
          "text": str,
          "selectors": {"#email": "fillable", ".submit": "clickable", ...},
          "on_fill": {"#email": fn(value) -> dict_overrides_for_state},
          "on_click": {".submit": fn() -> dict_overrides_for_state},
          "console_errors": [...],   # default empty
          "network_errors": [...],
          "status_code": int,
        }

    The mock starts with an empty state until `goto(url)` lands. Any
    action whose selector isn't in the page's `selectors` map sets
    `last_error` to "selector not found: <sel>".
    """

    def __init__(self, pages: Optional[Dict[str, Dict[str, Any]]] = None):
        self._pages = pages or {}
        self._state = _empty_state()
        self._actions_taken: List[Dict[str, Any]] = []
        self._closed = False

    @property
    def actions_taken(self) -> List[Dict[str, Any]]:
        return list(self._actions_taken)

    def _record(self, kind: str, **kwargs) -> None:
        self._actions_taken.append({"kind": kind, **kwargs})

    def _current_page(self) -> Dict[str, Any]:
        return self._pages.get(self._state["url"], {}) or {}

    def goto(self, url: str) -> Dict[str, Any]:
        self._record("goto", url=url)
        page = self._pages.get(url)
        if not page:
            self._state = _empty_state()
            self._state["url"] = url
            self._state["status_code"] = 404
            self._state["last_error"] = f"page not found: {url}"
            return dict(self._state)
        self._state = _empty_state()
        self._state["url"] = url
        self._state["title"] = page.get("title", "")
        self._state["text"] = page.get("text", "")
        self._state["status_code"] = page.get("status_code", 200)
        self._state["console_errors"] = list(page.get("console_errors", []) or [])
        self._state["network_errors"] = list(page.get("network_errors", []) or [])
        return dict(self._state)

    def fill(self, selector: str, value: str) -> Dict[str, Any]:
        self._record("fill", selector=selector, value=value)
        page = self._current_page()
        selectors = page.get("selectors", {})
        if selector not in selectors:
            self._state["last_error"] = f"selector not found: {selector}"
            return dict(self._state)
        # Reset last_error on a successful action.
        self._state["last_error"] = ""
        on_fill = (page.get("on_fill") or {}).get(selector)
        if callable(on_fill):
            overrides = on_fill(value) or {}
            self._apply_overrides(overrides)
        return dict(self._state)

    def click(self, selector: str) -> Dict[str, Any]:
        self._record("click", selector=selector)
        page = self._current_page()
        selectors = page.get("selectors", {})
        if selector not in selectors:
            self._state["last_error"] = f"selector not found: {selector}"
            return dict(self._state)
        self._state["last_error"] = ""
        on_click = (page.get("on_click") or {}).get(selector)
        if callable(on_click):
            overrides = on_click() or {}
            self._apply_overrides(overrides)
        return dict(self._state)

    def wait(self, ms: int) -> Dict[str, Any]:
        self._record("wait", ms=ms)
        return dict(self._state)

    def eval_js(self, code: str) -> Dict[str, Any]:
        self._record("eval_js", code=code)
        return dict(self._state)

    def snapshot(self) -> Dict[str, Any]:
        return dict(self._state)

    def close(self) -> None:
        self._closed = True

    @property
    def closed(self) -> bool:
        return self._closed

    def _apply_overrides(self, overrides: Dict[str, Any]) -> None:
        # Allow callbacks to navigate, push errors, change text, etc.
        for k, v in overrides.items():
            if k in ("console_errors", "network_errors"):
                # Append, don't replace — accumulate over a session.
                self._state[k] = list(self._state.get(k, [])) + list(v or [])
            elif k == "url":
                # Page transition — re-resolve via goto so text/title hydrate.
                target = str(v)
                # Inline navigate without recording a separate goto action.
                page = self._pages.get(target)
                self._state["url"] = target
                if page:
                    self._state["title"] = page.get("title", "")
                    self._state["text"] = page.get("text", "")
                    self._state["status_code"] = page.get("status_code", 200)
                else:
                    self._state["title"] = ""
                    self._state["text"] = ""
                    self._state["status_code"] = 404
                    self._state["last_error"] = f"page not found: {target}"
            else:
                self._state[k] = v


# -- real (lazy-imported playwright) ------------------------------------------

class PlaywrightBrowserDriver(BrowserDriver):
    """Wraps Playwright's sync API. Imports playwright lazily.

    The constructor starts a Chromium instance and a page. If the
    `auth_cookie` kwarg is set, it's added to the browser context
    before the first navigation.

    Console + network errors are accumulated via Playwright event
    listeners across the session — the snapshot returns a copy so
    later actions don't mutate caller state.
    """

    def __init__(
        self,
        *,
        auth_cookie: Optional[Dict[str, str]] = None,
        headless: bool = True,
        viewport: Optional[Dict[str, int]] = None,
    ):
        try:
            from playwright.sync_api import sync_playwright  # type: ignore
        except ImportError as exc:
            raise RuntimeError(
                "playwright is not installed. Install with "
                "`pip install playwright && playwright install chromium`."
            ) from exc
        self._pw = sync_playwright().start()
        self._browser = self._pw.chromium.launch(headless=headless)
        ctx_kwargs: Dict[str, Any] = {}
        if viewport:
            ctx_kwargs["viewport"] = viewport
        self._context = self._browser.new_context(**ctx_kwargs)
        if auth_cookie:
            self._context.add_cookies([auth_cookie])
        self._page = self._context.new_page()
        self._console_errors: List[str] = []
        self._network_errors: List[str] = []
        self._page.on("console", self._on_console)
        self._page.on("requestfailed", self._on_request_failed)
        self._last_status: int = 0

    def _on_console(self, msg) -> None:
        if getattr(msg, "type", "") == "error":
            try:
                self._console_errors.append(str(msg.text))
            except Exception:
                self._console_errors.append("<unreadable console error>")

    def _on_request_failed(self, request) -> None:
        try:
            self._network_errors.append(f"{request.method} {request.url}: {request.failure}")
        except Exception:
            self._network_errors.append("<unreadable request failure>")

    def _read_state(self, last_error: str = "") -> Dict[str, Any]:
        state = _empty_state()
        try:
            state["url"] = self._page.url
            state["title"] = self._page.title()
            state["text"] = (self._page.content() or "")[:8000]
        except Exception as exc:
            state["last_error"] = f"snapshot failed: {exc}"
            return state
        state["console_errors"] = list(self._console_errors)
        state["network_errors"] = list(self._network_errors)
        state["status_code"] = self._last_status
        state["last_error"] = last_error
        return state

    def goto(self, url: str) -> Dict[str, Any]:
        try:
            response = self._page.goto(url, wait_until="domcontentloaded")
            self._last_status = getattr(response, "status", 0) or 0
            return self._read_state()
        except Exception as exc:
            return self._read_state(last_error=f"goto failed: {exc}")

    def fill(self, selector: str, value: str) -> Dict[str, Any]:
        try:
            self._page.fill(selector, value, timeout=5_000)
            return self._read_state()
        except Exception as exc:
            return self._read_state(last_error=f"fill failed: {exc}")

    def click(self, selector: str) -> Dict[str, Any]:
        try:
            self._page.click(selector, timeout=5_000)
            return self._read_state()
        except Exception as exc:
            return self._read_state(last_error=f"click failed: {exc}")

    def wait(self, ms: int) -> Dict[str, Any]:
        try:
            self._page.wait_for_timeout(int(ms))
            return self._read_state()
        except Exception as exc:
            return self._read_state(last_error=f"wait failed: {exc}")

    def eval_js(self, code: str) -> Dict[str, Any]:
        try:
            self._page.evaluate(code)
            return self._read_state()
        except Exception as exc:
            return self._read_state(last_error=f"eval failed: {exc}")

    def snapshot(self) -> Dict[str, Any]:
        return self._read_state()

    def close(self) -> None:
        try:
            self._context.close()
        finally:
            try:
                self._browser.close()
            finally:
                self._pw.stop()
