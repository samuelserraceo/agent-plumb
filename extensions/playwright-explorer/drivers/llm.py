"""LLM driver abstraction.

The explore loop asks the LLM ONE question per attempt:

    "Here is the page state. Here are the spec's ACs. The current
    edge-case category is <category>. Propose ONE browser probe
    (action + target + expected outcome). Return strict JSON."

A probe is `{action, target, value, expected, rationale}`. The
explorer runs the action, observes the new state, and compares
`actual` to `expected` to decide whether to record a finding —
no second LLM call needed.

Two implementations:

  - MockLLMDriver: returns scripted probes from a queue. Deterministic;
    used by every test in this extension.
  - HttpLLMDriver: posts to an OpenAI-compatible chat endpoint. Works
    with OpenAI, Ollama, vLLM, llama.cpp's server, Anthropic via a
    proxy — anything that speaks the chat-completions shape.

Both implementations refuse silent failure. If the LLM returns
malformed JSON, the driver returns a probe of action="noop" with
the parser error in `rationale`. The explorer treats noop as a
no-finding attempt and moves on, so a single bad response can't
crash a run.
"""

from __future__ import annotations

import json
import os
import socket
import urllib.error
import urllib.request
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional


# -- contract -----------------------------------------------------------------

PROBE_ACTIONS = ("fill", "click", "goto", "wait", "eval", "noop")

# LLMs reach for these synonyms even when the prompt enumerates the
# canonical actions (especially smaller / open-weights models). Map
# them to the framework's vocabulary instead of collapsing to noop —
# silently dropping every "type" probe makes the loop produce zero
# findings against most LLMs in the wild.
_PROBE_SYNONYMS = {
    "type": "fill",
    "input": "fill",
    "set": "fill",
    "enter": "fill",
    "tap": "click",
    "press": "click",
    "submit": "click",
    "navigate": "goto",
    "open": "goto",
    "visit": "goto",
    "load": "goto",
    "sleep": "wait",
    "pause": "wait",
    "delay": "wait",
    "javascript": "eval",
    "js": "eval",
    "evaluate": "eval",
    "exec": "eval",
}


def _normalise_probe(raw: Any) -> Dict[str, Any]:
    """Coerce the LLM's reply into a probe shape. Never raises."""
    if not isinstance(raw, dict):
        return {
            "action": "noop",
            "target": "",
            "value": "",
            "expected": "",
            "rationale": f"llm returned non-dict: {type(raw).__name__}",
        }
    action = str(raw.get("action") or "noop").strip().lower()
    action = _PROBE_SYNONYMS.get(action, action)
    if action not in PROBE_ACTIONS:
        action = "noop"
    return {
        "action": action,
        "target": str(raw.get("target") or ""),
        "value": str(raw.get("value") or ""),
        "expected": str(raw.get("expected") or ""),
        "rationale": str(raw.get("rationale") or ""),
    }


class LLMDriver(ABC):
    """Abstract LLM driver. Implementations propose one probe per call."""

    @abstractmethod
    def propose_probe(
        self,
        *,
        category: str,
        state: Dict[str, Any],
        spec_acs: List[str],
        history: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """Return a probe dict {action, target, value, expected, rationale}."""

    @property
    @abstractmethod
    def cost_per_call_usd(self) -> float:
        """Per-call cost estimate in USD. Used by the explorer's cost gate."""


# -- mock (used by tests) -----------------------------------------------------

class MockLLMDriver(LLMDriver):
    """Returns probes from a scripted queue.

    Construct with a list of probe dicts (or category->list mapping).
    Each call to `propose_probe` pops the next probe for the requested
    category; if the queue runs dry, returns a noop probe.
    """

    def __init__(
        self,
        probes_by_category: Optional[Dict[str, List[Dict[str, Any]]]] = None,
        *,
        flat_queue: Optional[List[Dict[str, Any]]] = None,
        cost_per_call_usd: float = 0.0,
    ):
        self._by_cat: Dict[str, List[Dict[str, Any]]] = {
            k: list(v) for k, v in (probes_by_category or {}).items()
        }
        self._flat: List[Dict[str, Any]] = list(flat_queue or [])
        self._calls: int = 0
        self._cost = cost_per_call_usd

    def propose_probe(self, *, category, state, spec_acs, history):
        self._calls += 1
        queue = self._by_cat.get(category)
        if queue:
            probe = queue.pop(0)
            return _normalise_probe(probe)
        if self._flat:
            return _normalise_probe(self._flat.pop(0))
        return _normalise_probe({
            "action": "noop",
            "rationale": f"mock: no scripted probe for category={category}",
        })

    @property
    def calls(self) -> int:
        return self._calls

    @property
    def cost_per_call_usd(self) -> float:
        return self._cost


# -- http (real) --------------------------------------------------------------

_SYSTEM_PROMPT = """You are an exploratory tester probing a deployed web feature for edge cases the spec didn't cover.

You will be given:
  - the page's current state (url, title, visible text, console errors, network errors)
  - the feature's acceptance criteria (the things already verified)
  - the edge-case category to probe right now
  - a short history of probes you have already proposed

Your job: propose ONE concrete browser probe in this category that the spec author probably did not test. Encode both the action AND what should happen (the expected outcome). Reply with strict JSON only — no prose, no markdown fences.

Schema:
{
  "action": "fill" | "click" | "goto" | "wait" | "eval" | "noop",
  "target": "<css selector | url | js snippet | empty>",
  "value":  "<value to fill | empty>",
  "expected": "<one short sentence: what the spec implies should happen>",
  "rationale": "<one short sentence: why this probe targets the category>"
}

Categories you'll be asked to probe: empty, max, bad-input, network, concurrency, auth, mobile, time-based.

Return "noop" if you genuinely cannot think of a fresh probe — do not repeat history.
"""


class HttpLLMDriver(LLMDriver):
    """OpenAI-compatible chat completions driver.

    Works with:
      - OpenAI: endpoint=https://api.openai.com/v1/chat/completions
      - Ollama: endpoint=http://localhost:11434/v1/chat/completions
      - vLLM, llama.cpp server, anything else that speaks the same shape.

    Reads bearer auth from the env var named in `auth_env`. If the var
    is unset (e.g. local Ollama), no Authorization header is sent.
    """

    def __init__(
        self,
        *,
        endpoint: str,
        model: str,
        auth_env: Optional[str] = None,
        timeout_seconds: float = 30.0,
        cost_per_call_usd: float = 0.01,
    ):
        if not endpoint:
            raise ValueError("HttpLLMDriver: endpoint is required")
        if not model:
            raise ValueError("HttpLLMDriver: model is required")
        # Refuse non-http(s) schemes — file://, gopher://, ftp://, etc.
        # let urllib reach surfaces it shouldn't (SSRF / local file read).
        from urllib.parse import urlparse
        parsed = urlparse(endpoint)
        if parsed.scheme not in ("http", "https"):
            raise ValueError(
                "HttpLLMDriver: endpoint must be an http(s) URL "
                f"(got scheme={parsed.scheme!r})"
            )
        self.endpoint = endpoint
        self.model = model
        self.auth_env = auth_env
        self.timeout = timeout_seconds
        self._cost = cost_per_call_usd

    def propose_probe(self, *, category, state, spec_acs, history):
        user_msg = json.dumps({
            "category": category,
            "page_state": state,
            "spec_acs": spec_acs,
            "history": history[-8:],
        })
        body = json.dumps({
            "model": self.model,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": user_msg},
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.7,
        }).encode("utf-8")
        req = urllib.request.Request(
            self.endpoint,
            data=body,
            method="POST",
            headers={"Content-Type": "application/json"},
        )
        if self.auth_env:
            token = os.environ.get(self.auth_env, "")
            if token:
                req.add_header("Authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
        except (
            urllib.error.URLError,
            urllib.error.HTTPError,
            TimeoutError,
            # socket.timeout is a separate class on Python 3.9 — only
            # aliased to TimeoutError from 3.10. Catch both so slow LLMs
            # graceful-degrade to a noop probe instead of crashing.
            socket.timeout,
            ConnectionError,
        ) as exc:
            return _normalise_probe({
                "action": "noop",
                "rationale": f"http error: {exc.__class__.__name__}: {exc}",
            })
        except json.JSONDecodeError as exc:
            return _normalise_probe({
                "action": "noop",
                "rationale": f"json decode error: {exc}",
            })
        try:
            content = payload["choices"][0]["message"]["content"]
            parsed = json.loads(content)
        except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
            return _normalise_probe({
                "action": "noop",
                "rationale": f"bad llm reply: {exc.__class__.__name__}: {exc}",
            })
        return _normalise_probe(parsed)

    @property
    def cost_per_call_usd(self) -> float:
        return self._cost
