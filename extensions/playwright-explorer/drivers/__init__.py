"""Driver abstractions for the playwright-explorer.

Two abstract drivers, each with a deterministic mock for tests and a
real implementation for live runs:

  - LLMDriver: proposes browser probes given page state + spec ACs.
  - BrowserDriver: navigates a page and reports observed state.

The MCP server's `explore` tool composes one of each. Tests use the
mock pair; production composes HttpLLMDriver + PlaywrightBrowserDriver.

PlaywrightBrowserDriver is defined in `drivers.browser` but
intentionally NOT re-exported here. The server imports it lazily from
its full module path so that test runs (which only need the mocks)
don't have to install playwright. Callers needing the real driver
import it directly from `drivers.browser`.
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
