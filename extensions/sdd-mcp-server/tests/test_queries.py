"""Unit tests for the 6 SDD MCP queries + the protocol shim.

Run from extensions/sdd-mcp-server/:

    python3 -m unittest discover

Each query gets at least 2 tests: a happy path (real fixture answers
the question) and an edge case (missing file, bad arg, empty section).
"""

from __future__ import annotations

import json
import os
import sys
import unittest

# Make the parent directory importable so `from queries import ...` works
# regardless of how the test runner is invoked.
_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries import (  # noqa: E402
    get_active_step,
    get_by_tag,
    get_pattern,
    get_references,
    get_decisions_since,
    search,
)
from queries.search import _chunk_text, _normalize_endpoint  # noqa: E402
from server import handle_message  # noqa: E402

from tests.conftest import make_temp_project  # noqa: E402


class _FixtureBase(unittest.TestCase):
    with_semantic_search = False

    def setUp(self):
        self.root, self._cleanup = make_temp_project(
            with_semantic_search=self.with_semantic_search
        )

    def tearDown(self):
        self._cleanup()


# -- get_active_step ----------------------------------------------------------

class GetActiveStepTests(_FixtureBase):
    def test_happy_path_returns_first_open_step(self):
        result = get_active_step(self.root, {})
        self.assertNotIn("error", result, msg=result)
        self.assertEqual(result["feature_path"], ".sdd/features/001-waitlist")
        self.assertEqual(result["phase"], "BUILD")
        self.assertEqual(result["step_id"], "task-003")
        self.assertIn("success state", result["step_prompt"])
        # field is parsed off the "→ tests/task-003.mjs" suffix
        self.assertEqual(result["step_field"], "tests/task-003.mjs")

    def test_no_active_feature_returns_error(self):
        # Overwrite INDEX.md to clear the Active line.
        path = os.path.join(self.root, ".sdd", "INDEX.md")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("# Project Index\n\n**Active:** _(none)_\n")
        result = get_active_step(self.root, {})
        self.assertIn("error", result)
        self.assertIn("no active feature", result["error"])

    def test_missing_index_returns_error(self):
        os.remove(os.path.join(self.root, ".sdd", "INDEX.md"))
        result = get_active_step(self.root, {})
        self.assertIn("error", result)
        self.assertIn("INDEX.md not found", result["error"])


# -- get_by_tag ---------------------------------------------------------------

class GetByTagTests(_FixtureBase):
    def test_in_flight_finds_one_feature(self):
        result = get_by_tag(self.root, {"tag": "in-flight"})
        self.assertEqual(result["tag"], "in-flight")
        self.assertEqual(len(result["matches"]), 1)
        match = result["matches"][0]
        self.assertEqual(match["id"], "001-waitlist")
        self.assertEqual(match["phase"], "BUILD")
        self.assertIn("waitlist", match["summary"])

    def test_shipped_finds_bootstrap(self):
        result = get_by_tag(self.root, {"tag": "shipped"})
        self.assertEqual(len(result["matches"]), 1)
        self.assertEqual(result["matches"][0]["id"], "000-bootstrap")

    def test_unknown_tag_returns_error(self):
        result = get_by_tag(self.root, {"tag": "deleted"})
        self.assertIn("error", result)
        self.assertIn("unknown tag", result["error"])

    def test_missing_tag_arg_returns_error(self):
        result = get_by_tag(self.root, {})
        self.assertIn("error", result)


# -- get_pattern --------------------------------------------------------------

class GetPatternTests(_FixtureBase):
    def test_finds_pattern_by_slug(self):
        result = get_pattern(self.root, {"slug": "auth-retry-logic"})
        self.assertEqual(result["slug"], "auth-retry-logic")
        self.assertEqual(result["heading"], "Auth retry logic")
        self.assertIn("exponential backoff", result["content"])
        self.assertEqual(result["feature_source"], "002-login")

    def test_finds_pattern_with_loose_slug_match(self):
        # Spaces / mixed case still resolve.
        result = get_pattern(self.root, {"slug": "Auth Retry Logic"})
        self.assertEqual(result["slug"], "auth-retry-logic")

    def test_unknown_slug_returns_available_list(self):
        result = get_pattern(self.root, {"slug": "nonexistent"})
        self.assertIn("error", result)
        self.assertIn("available", result)
        slugs = {p["slug"] for p in result["available"]}
        self.assertIn("auth-retry-logic", slugs)
        self.assertIn("email-delivery-batching", slugs)


# -- get_references -----------------------------------------------------------

class GetReferencesTests(_FixtureBase):
    def test_finds_extends_and_mentions(self):
        result = get_references(self.root, {"slug": "002-login"})
        paths = [m["path"] for m in result["referenced_in"]]
        # The patterns.md "Source: 002-login" line should match.
        self.assertTrue(any("patterns.md" in p for p in paths))
        # The feature README "References: - 002-login (uses ..." also matches.
        self.assertTrue(any("README" in p for p in paths))

    def test_extends_classification(self):
        result = get_references(self.root, {"slug": "000-bootstrap"})
        kinds = {m["kind"] for m in result["referenced_in"]}
        self.assertIn("extends", kinds)

    def test_missing_slug_returns_error(self):
        result = get_references(self.root, {})
        self.assertIn("error", result)


# -- get_decisions_since ------------------------------------------------------

class GetDecisionsSinceTests(_FixtureBase):
    def test_filters_by_iso_timestamp(self):
        result = get_decisions_since(self.root, {"since": "2026-04-25T00:00:00Z"})
        self.assertEqual(len(result["entries"]), 1)
        self.assertEqual(result["entries"][0]["timestamp"], "2026-04-28T16:23:00Z")
        self.assertEqual(result["entries"][0]["work_item"], "001-waitlist")
        self.assertEqual(result["entries"][0]["action"], "feature/acceptance-criteria")

    def test_returns_all_when_since_is_old(self):
        result = get_decisions_since(self.root, {"since": "2025-01-01"})
        self.assertEqual(len(result["entries"]), 3)
        # Hash pulled out where present.
        first = result["entries"][0]
        self.assertEqual(first["hash"][:8], "a1b2c3d4")

    def test_missing_since_returns_error(self):
        result = get_decisions_since(self.root, {})
        self.assertIn("error", result)

    def test_missing_decisions_file_returns_error(self):
        os.remove(os.path.join(self.root, ".sdd", "decisions.md"))
        result = get_decisions_since(self.root, {"since": "2026-01-01"})
        self.assertIn("error", result)


# -- chunker (internal — line-tracking correctness) ---------------------------

class ChunkerLineTrackingTests(unittest.TestCase):
    """Pin the line-tracking contract for `_chunk_text`. CR cycle-2
    flagged that an earlier implementation drifted line numbers when
    the sentence-fallback or hard-split paths fired. These tests
    document the expected semantics."""

    def test_short_paragraphs_one_chunk_each(self):
        content = "First.\n\nSecond.\n\nThird."
        chunks = _chunk_text(content, max_chars=100)
        # 3 paragraphs separated by blank lines.
        self.assertEqual(len(chunks), 3)
        self.assertEqual(chunks[0]["start_line"], 1)
        self.assertEqual(chunks[1]["start_line"], 3)
        self.assertEqual(chunks[2]["start_line"], 5)

    def test_sentence_split_keeps_source_line_for_inline_sentences(self):
        # Long single-line paragraph → sentence-split. All emitted
        # chunks must point at the SAME source line (they're all on
        # line 1) — not drift down because of the rebuilt buffer.
        para = (" ".join([f"Sentence {i}." for i in range(20)]))
        chunks = _chunk_text(para, max_chars=80)
        self.assertGreater(len(chunks), 1, "expected multiple chunks")
        for c in chunks:
            self.assertEqual(c["start_line"], 1, f"unexpected drift in {c}")
            self.assertEqual(c["end_line"], 1, f"unexpected drift in {c}")

    def test_hard_split_long_run_on_sentence_keeps_source_line(self):
        # Single sentence longer than max_chars on one source line →
        # hard-split into pieces. Every piece stays on line 1.
        content = "x" * 350  # one long line, no whitespace
        chunks = _chunk_text(content, max_chars=100)
        self.assertGreaterEqual(len(chunks), 3)
        for c in chunks:
            self.assertEqual(c["start_line"], 1, f"hard-split drifted: {c}")
            self.assertEqual(c["end_line"], 1, f"hard-split drifted: {c}")

    def test_line_numbers_monotonic_and_in_bounds(self):
        content = "\n".join([f"Line {i}: some content here." for i in range(1, 11)])
        chunks = _chunk_text(content, max_chars=80)
        total_lines = len(content.split("\n"))
        prev_end = 0
        for c in chunks:
            self.assertGreaterEqual(c["start_line"], 1)
            self.assertLessEqual(c["end_line"], total_lines)
            self.assertLessEqual(c["start_line"], c["end_line"])
            self.assertGreaterEqual(c["start_line"], prev_end)
            prev_end = c["end_line"]

    def test_consecutive_blank_lines_dont_drift_line_numbers(self):
        # CR cycle-3 finding: split("\n\n") collapses runs of 3+ newlines
        # into empty strings whose count("\n")+1 = 1, over-advancing the
        # source-line counter. With the re.finditer + offset approach,
        # line numbers stay accurate regardless of blank-line run length.
        content = "A line\n\n\n\nB line"  # 4 newlines = 3 blank lines between
        chunks = _chunk_text(content, max_chars=100)
        self.assertEqual(len(chunks), 2)
        self.assertEqual(chunks[0]["start_line"], 1)
        self.assertEqual(chunks[0]["content"], "A line")
        self.assertEqual(chunks[1]["start_line"], 5)  # not 7 (the old buggy answer)
        self.assertEqual(chunks[1]["content"], "B line")


# -- endpoint normalization (avoids double-appended paths) --------------------

class NormalizeEndpointTests(unittest.TestCase):
    """Pin the contract: users may paste any of these endpoint shapes
    in their config.md, and search.py won't mangle the URL into
    /v1/v1/embeddings or /api/api/embeddings. CR cycle-3 finding."""

    def test_openai_bare_base(self):
        self.assertEqual(
            _normalize_endpoint("openai", "http://localhost:11434"),
            "http://localhost:11434/v1/embeddings",
        )

    def test_openai_versioned_base(self):
        # User pasted /v1 but no /embeddings — no double-append.
        self.assertEqual(
            _normalize_endpoint("openai", "http://localhost:11434/v1"),
            "http://localhost:11434/v1/embeddings",
        )

    def test_openai_full_path_left_alone(self):
        self.assertEqual(
            _normalize_endpoint("openai", "http://localhost:11434/v1/embeddings"),
            "http://localhost:11434/v1/embeddings",
        )

    def test_ollama_native_bare_base(self):
        self.assertEqual(
            _normalize_endpoint("ollama-native", "http://localhost:11434"),
            "http://localhost:11434/api/embeddings",
        )

    def test_ollama_native_versioned_base(self):
        # User pasted /api but no /embeddings — no double-append.
        self.assertEqual(
            _normalize_endpoint("ollama-native", "http://localhost:11434/api"),
            "http://localhost:11434/api/embeddings",
        )

    def test_ollama_native_full_path_left_alone(self):
        self.assertEqual(
            _normalize_endpoint("ollama-native", "http://localhost:11434/api/embeddings"),
            "http://localhost:11434/api/embeddings",
        )

    def test_trailing_slash_stripped(self):
        # Cosmetic: trailing slashes don't affect the normalized output.
        self.assertEqual(
            _normalize_endpoint("openai", "http://localhost:11434/"),
            "http://localhost:11434/v1/embeddings",
        )


# -- search (opt-in stub) -----------------------------------------------------

class SearchDisabledTests(_FixtureBase):
    def test_returns_config_shape_when_disabled(self):
        result = search(self.root, {"query": "auth retry"})
        self.assertIn("error", result)
        self.assertIn("config_shape", result)
        # Documents the exact key path the user must add.
        sem = result["config_shape"]["parameters"]["mcp"]["semantic_search"]
        self.assertIn("provider", sem)
        self.assertIn("endpoint", sem)


class SearchEnabledTests(_FixtureBase):
    with_semantic_search = True

    def test_unreachable_endpoint_returns_plain_english_error(self):
        # Fixture points at http://127.0.0.1:1 — port 1 is reserved, so
        # the connection fails fast and predictably without needing a
        # mock server. Verifies the embedding-failure fallback path.
        result = search(self.root, {"query": "auth retry"})
        self.assertIn("error", result)
        # The error must be human-readable and not a Python traceback.
        # The agent reads this and knows what to do next.
        self.assertNotIn("Traceback", result["error"])
        # Fallback hint tells the agent what to do when search is broken.
        self.assertIn("fallback", result)
        # Query is echoed so the caller can correlate.
        self.assertEqual(result["query"], "auth retry")

    def test_missing_query_arg(self):
        result = search(self.root, {})
        self.assertIn("error", result)
        self.assertIn("query", result["error"])

    def test_disabled_provider_rejected_with_config_shape(self):
        # Swap to an unsupported provider mid-test; search must reject
        # cleanly with a plain-English error and the canonical config_shape.
        cfg = os.path.join(self.root, ".sdd", "config.md")
        with open(cfg, encoding="utf-8") as fh:
            text = fh.read()
        text = text.replace("provider: openai", "provider: unsupported-provider")
        with open(cfg, "w", encoding="utf-8") as fh:
            fh.write(text)
        result = search(self.root, {"query": "auth retry"})
        self.assertIn("error", result)
        # Error names which providers ARE supported.
        self.assertIn("openai", result["error"])
        self.assertIn("ollama-native", result["error"])
        # Must include the canonical config_shape so the agent renders
        # the user-facing fix path. Without this, an embedding-failure
        # fallback could pass the substring check above without giving
        # the user a real config blueprint. CR cycle-2 finding.
        self.assertIn("config_shape", result)
        self.assertEqual(
            result["config_shape"]["parameters"]["mcp"]["semantic_search"]["provider"],
            "<openai|ollama-native>",
        )

    def test_missing_provider_rejected_with_config_shape(self):
        # Per framework doctrine, provider is REQUIRED — no silent
        # default. Empty value must be rejected with a clear message
        # naming the supported providers.
        cfg = os.path.join(self.root, ".sdd", "config.md")
        with open(cfg, encoding="utf-8") as fh:
            text = fh.read()
        text = text.replace("provider: openai", "provider: \"\"")
        with open(cfg, "w", encoding="utf-8") as fh:
            fh.write(text)
        result = search(self.root, {"query": "auth retry"})
        self.assertIn("error", result)
        self.assertIn("provider", result["error"])
        self.assertIn("required", result["error"])
        self.assertIn("config_shape", result)

    def test_disallowed_url_scheme_rejected(self):
        # Defence-in-depth: even with a valid provider + model, an
        # endpoint URL using file:// or another scheme must be refused
        # before any network call happens. CR cycle-1 finding.
        cfg = os.path.join(self.root, ".sdd", "config.md")
        with open(cfg, encoding="utf-8") as fh:
            text = fh.read()
        text = text.replace(
            "endpoint: http://127.0.0.1:1",
            "endpoint: file:///etc/passwd",
        )
        with open(cfg, "w", encoding="utf-8") as fh:
            fh.write(text)
        result = search(self.root, {"query": "auth retry"})
        self.assertIn("error", result)
        # Error must mention the scheme problem so the user knows what
        # to fix in config.md, not a Python URLError traceback.
        self.assertNotIn("Traceback", result["error"])


# -- protocol shim (server.handle_message) ------------------------------------

class ProtocolShimTests(_FixtureBase):
    def setUp(self):
        super().setUp()
        # The server reads CLAUDE_PROJECT_DIR or cwd; force the fixture root.
        self._old_env = os.environ.get("CLAUDE_PROJECT_DIR")
        os.environ["CLAUDE_PROJECT_DIR"] = self.root

    def tearDown(self):
        if self._old_env is None:
            os.environ.pop("CLAUDE_PROJECT_DIR", None)
        else:
            os.environ["CLAUDE_PROJECT_DIR"] = self._old_env
        super().tearDown()

    def test_simplified_shape_dispatches(self):
        resp = handle_message({"query": "get_active_step", "args": {}})
        self.assertIn("result", resp)
        self.assertEqual(resp["result"]["step_id"], "task-003")

    def test_simplified_unknown_query(self):
        resp = handle_message({"query": "make_coffee", "args": {}})
        self.assertIn("error", resp)

    def test_mcp_initialize(self):
        resp = handle_message({"jsonrpc": "2.0", "id": 1, "method": "initialize"})
        self.assertEqual(resp["jsonrpc"], "2.0")
        self.assertIn("serverInfo", resp["result"])
        self.assertEqual(resp["result"]["serverInfo"]["name"], "sdd-mcp-server")

    def test_mcp_tools_list_includes_all_six(self):
        resp = handle_message({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        names = {t["name"] for t in resp["result"]["tools"]}
        self.assertEqual(
            names,
            {
                "get_active_step",
                "get_by_tag",
                "get_pattern",
                "get_references",
                "get_decisions_since",
                "search",
            },
        )

    def test_mcp_tools_call_returns_text_content(self):
        resp = handle_message({
            "jsonrpc": "2.0", "id": 3,
            "method": "tools/call",
            "params": {"name": "get_active_step", "arguments": {}},
        })
        content = resp["result"]["content"]
        self.assertEqual(content[0]["type"], "text")
        # The text part is JSON — decoding it should give the same shape.
        decoded = json.loads(content[0]["text"])
        self.assertEqual(decoded["step_id"], "task-003")

    def test_mcp_unknown_method(self):
        resp = handle_message({"jsonrpc": "2.0", "id": 4, "method": "tools/breathe"})
        self.assertIn("error", resp)
        self.assertEqual(resp["error"]["code"], -32601)

    def test_mcp_tools_call_contextual_error_sets_isError(self):
        """Regression: any handler-returned `error` key must set isError=True,
        even when the result also carries success-shaped context fields like
        `feature_path` or `phase`. The earlier shim used `"feature_path" not in result`
        to gate isError, which silently downgraded contextual errors to successful
        results. Now the shim only checks for the `error` key. This test guards
        against regressing back to the old behaviour.
        """
        # Build a fixture, then rewrite spec.md so the phase exists but
        # has no open [ ] steps. get_active_step returns a contextual
        # error of the exact bug shape: {feature_path, phase, error}.
        # This is what the earlier shim's `"feature_path" not in result`
        # gate silently downgraded to success.
        proj, cleanup = make_temp_project()
        try:
            spec_path = os.path.join(proj, ".sdd", "features", "001-waitlist", "spec.md")
            with open(spec_path, "w", encoding="utf-8") as fh:
                fh.write(
                    "# 001-waitlist\n\n"
                    "[PHASE: BUILD]\n\n"
                    "## PHASE: BUILD\n\n"
                    "- [x] task-001: completed step\n"
                    "- [x] task-002: also completed\n"
                )
            os.environ["CLAUDE_PROJECT_DIR"] = proj
            try:
                resp = handle_message({
                    "jsonrpc": "2.0",
                    "id": 99,
                    "method": "tools/call",
                    "params": {"name": "get_active_step", "arguments": {}},
                })
            finally:
                os.environ.pop("CLAUDE_PROJECT_DIR", None)
            # The shim must mark this as an error, even though the inner result
            # ALSO carries feature_path and phase context (the exact shape
            # that the earlier "feature_path not in result" gate downgraded).
            self.assertTrue(
                resp["result"]["isError"],
                "tools/call must set isError=True when result has 'error' key — "
                "even if result also contains success-shaped fields"
            )
            decoded = json.loads(resp["result"]["content"][0]["text"])
            self.assertIn("error", decoded)
            # Stronger guard: verify the result actually has the success-shaped
            # context fields that originally triggered the bug. If the handler
            # later stops returning feature_path/phase on error paths, this
            # test will fail and force a rethink rather than silently passing.
            self.assertIn("feature_path", decoded,
                          "contextual-error result should still carry feature_path "
                          "(otherwise the bug shape isn't exercised)")
            self.assertIn("phase", decoded,
                          "contextual-error result should still carry phase "
                          "(otherwise the bug shape isn't exercised)")
        finally:
            cleanup()

    def test_simplified_protocol_contextual_error_returns_top_level_error(self):
        """Parallel regression test for the simplified `{"query": ..., "args": ...}`
        protocol path. The MCP `tools/call` path was fixed to honour the `error`
        key as the source of truth; this test guards that the simplified path
        does the same — a contextual error from get_active_step must appear at
        the TOP LEVEL of the response (not nested under "result"), so callers
        of the simplified path can detect failures the same way.
        """
        proj, cleanup = make_temp_project()
        try:
            spec_path = os.path.join(proj, ".sdd", "features", "001-waitlist", "spec.md")
            os.remove(spec_path)
            os.environ["CLAUDE_PROJECT_DIR"] = proj
            try:
                resp = handle_message({
                    "query": "get_active_step",
                    "args": {},
                })
            finally:
                os.environ.pop("CLAUDE_PROJECT_DIR", None)
            # Simplified path returns the result dict at the top level.
            # The `error` key signals failure — callers must be able to see it.
            self.assertIn("error", resp,
                          "simplified protocol must surface 'error' at the top level "
                          "for contextual errors, not nest it under 'result'")
        finally:
            cleanup()


if __name__ == "__main__":
    unittest.main()
