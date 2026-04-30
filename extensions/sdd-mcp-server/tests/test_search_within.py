"""Unit tests for the `search_within` query (Tier 2b: bounded semantic search).

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_search_within

Each test exercises a documented branch of the contract:
  - semantic search disabled (default): returns the same error shape as
    plain `search` (graph resolution still happens, then delegation fails)
  - semantic search enabled but endpoint unreachable: plain-English error
  - non-existent slug returns the canonical {error, available} shape
  - missing arg slug / query returns the canonical {error} shape
  - the path allowlist is computed correctly: the seed slug's own file
    appears in `_path_allowlist` passed down to `search.py`
"""

from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import patch
import importlib

# Make the parent directory importable so `from queries import ...` works
# regardless of how the test runner is invoked.
_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries import search_within  # noqa: E402

from tests.conftest import make_temp_project  # noqa: E402


class _FixtureBase(unittest.TestCase):
    with_semantic_search = False

    def setUp(self):
        self.root, self._cleanup = make_temp_project(
            with_semantic_search=self.with_semantic_search
        )

    def tearDown(self):
        self._cleanup()


class SearchWithinDisabledTests(_FixtureBase):
    """Default fixture: semantic_search.enabled is unset / false.

    `search_within` resolves the slug locally, then delegates the actual
    embedding work to `search.py`. With search disabled, the delegated
    call returns the canonical {error, config_shape} shape — and
    `search_within` propagates it unchanged.
    """

    def test_returns_config_shape_when_search_disabled(self):
        result = search_within(self.root, {
            "slug": "001-waitlist",
            "query": "auth retry",
        })
        self.assertIn("error", result)
        # The error path comes from search.py — it must include the
        # canonical config_shape so the agent knows how to fix it.
        self.assertIn("config_shape", result)
        self.assertIn("not configured", result["error"])

    def test_missing_slug_arg_returns_error(self):
        result = search_within(self.root, {"query": "anything"})
        self.assertIn("error", result)
        self.assertIn("slug", result["error"])

    def test_missing_query_arg_returns_error(self):
        result = search_within(self.root, {"slug": "001-waitlist"})
        self.assertIn("error", result)
        self.assertIn("query", result["error"])

    def test_unknown_slug_returns_available_list(self):
        # Slug resolution happens BEFORE the disabled-search check, so
        # an unknown slug short-circuits with the graph-level error
        # shape, not the search-level config error.
        result = search_within(self.root, {
            "slug": "ghost-node",
            "query": "anything",
        })
        self.assertIn("error", result)
        self.assertIn("not found", result["error"])
        self.assertIn("available", result)
        self.assertIsInstance(result["available"], list)
        # Must NOT have a config_shape — this is the graph-level
        # rejection path, not the search-level rejection path.
        self.assertNotIn("config_shape", result)

    def test_path_allowlist_includes_seed_slug_path(self):
        # Smoke-test the core delegation contract: search_within must
        # compute the depth-bounded subgraph and pass it to search.py
        # via the internal `_path_allowlist` arg. We don't care about
        # the actual semantic match — only that the allowlist contains
        # the seed slug's own file (since paths is initialized with
        # `{root["path"]}` and BFS only adds more).
        captured = {}

        def fake_search(_root, args):
            captured["allowlist"] = args.get("_path_allowlist")
            captured["query"] = args.get("query")
            captured["top_k"] = args.get("top_k")
            return {"matches": [], "stats": {}, "query": args.get("query")}

        # `search_within._search_module` is the queries.search submodule,
        # bound at import time via importlib. Patch the `search` attribute
        # on that module object directly (patch.object avoids the dotted-
        # string import lookup that fails when the leftmost segment isn't
        # a package).
        search_module = importlib.import_module("queries.search")
        with patch.object(search_module, "search", side_effect=fake_search):
            result = search_within(self.root, {
                "slug": "001-waitlist",
                "query": "form submission",
                "depth": 1,
            })

        self.assertNotIn("error", result, msg=result)
        self.assertIn("subgraph", result)
        self.assertEqual(result["subgraph"]["depth"], 1)
        # The seed slug's own file path must appear in `files_searched`.
        files_searched = result["subgraph"]["files_searched"]
        self.assertTrue(
            any("001-waitlist" in f and f.endswith("spec.md") for f in files_searched),
            f"seed slug's spec.md not in files_searched: {files_searched!r}",
        )
        # The internal `_path_allowlist` arg must be passed to search.py
        # and it must be an absolute-path list containing the seed file.
        self.assertIsInstance(captured["allowlist"], list)
        self.assertTrue(
            any(p.endswith(os.path.join("001-waitlist", "spec.md"))
                for p in captured["allowlist"]),
            f"seed file not in _path_allowlist: {captured['allowlist']!r}",
        )
        # query passes through verbatim; top_k defaults to 5.
        self.assertEqual(captured["query"], "form submission")
        self.assertEqual(captured["top_k"], 5)


class SearchWithinEnabledTests(_FixtureBase):
    """Search enabled but endpoint points at port 1 (reserved + unreachable).

    Same fast-fail pattern as test_queries.SearchEnabledTests — verifies
    the query produces a plain-English error, not a Python traceback,
    when the network call fails.
    """

    with_semantic_search = True

    def test_unreachable_endpoint_returns_plain_english_error(self):
        result = search_within(self.root, {
            "slug": "001-waitlist",
            "query": "auth retry",
        })
        self.assertIn("error", result)
        # No raw traceback should leak through.
        self.assertNotIn("Traceback", result["error"])
        # The error originates inside search.py, which adds a `fallback`
        # hint when the embedding call fails — search_within passes that
        # error dict through unchanged.
        self.assertIn("fallback", result)


if __name__ == "__main__":
    unittest.main()
