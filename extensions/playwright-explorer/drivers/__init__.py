"""Driver abstractions for the playwright-explorer.

Two abstract drivers, each with a deterministic mock for tests and a
real implementation for live runs:

  - LLMDriver: proposes browser probes given page state + spec ACs.
  - BrowserDriver: navigates a page and reports observed state.

The MCP server's `explore` tool composes one of each. Tests use the
mock pair; production composes HttpLLMDriver + PlaywrightBrowserDriver.

Real Playwright is imported lazily inside PlaywrightBrowserDriver so
the mock-only test path runs without playwright installed.
"""

from .llm import LLMDriver, MockLLMDriver, HttpLLMDriver
from .browser import BrowserDriver, MockBrowserDriver

__all__ = [
    "LLMDriver",
    "MockLLMDriver",
    "HttpLLMDriver",
    "BrowserDriver",
    "MockBrowserDriver",
]
