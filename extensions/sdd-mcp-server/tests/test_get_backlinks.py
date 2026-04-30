"""Unit tests for the `get_backlinks` query (Tier 1 graph traversal).

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_get_backlinks

Each test exercises a documented branch of the contract:
  - happy path: pattern slug with at least one incoming wiki-link
  - bare feature slug returns its backlinks
  - non-existent slug returns the canonical {error, available} shape
  - missing arg slug returns the canonical {error} shape
  - graph with no wiki-links still returns gracefully (empty backlinks)
"""

from __future__ import annotations

import os
import sys
import unittest

# Make the parent directory importable so `from queries import ...` works
# regardless of how the test runner is invoked.
_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from queries import get_backlinks  # noqa: E402

from tests.conftest import make_temp_project  # noqa: E402


class _FixtureBase(unittest.TestCase):
    with_semantic_search = False

    def setUp(self):
        self.root, self._cleanup = make_temp_project(
            with_semantic_search=self.with_semantic_search
        )

    def tearDown(self):
        self._cleanup()


class GetBacklinksTests(_FixtureBase):
    def test_pattern_slug_resolves_with_incoming_backlink(self):
        # `auth-retry-logic` is an H3 in patterns.md and is wiki-linked
        # from BOTH 001-waitlist and 002-login spec.md files via the
        # `[[pattern:auth-retry-logic]]` form.
        result = get_backlinks(self.root, {"slug": "auth-retry-logic"})
        self.assertNotIn("error", result, msg=result)
        self.assertEqual(result["slug"], "auth-retry-logic")
        self.assertEqual(result["node"]["kind"], "pattern")
        self.assertGreaterEqual(result["stats"]["count"], 1)
        from_paths = [bl["from_path"] for bl in result["backlinks"]]
        self.assertTrue(
            any("001-waitlist" in p for p in from_paths),
            f"expected 001-waitlist backlink in {from_paths!r}",
        )
        # Every backlink entry carries the (path, line, kind) triple.
        for bl in result["backlinks"]:
            self.assertIn("from_path", bl)
            self.assertIn("from_line", bl)
            self.assertEqual(bl["kind"], "wiki-link")

    def test_qualified_pattern_slug_also_resolves(self):
        # Same node, different addressing. Both `auth-retry-logic` and
        # `pattern:auth-retry-logic` must point at the same node.
        bare = get_backlinks(self.root, {"slug": "auth-retry-logic"})
        qualified = get_backlinks(self.root, {"slug": "pattern:auth-retry-logic"})
        self.assertNotIn("error", qualified, msg=qualified)
        self.assertEqual(bare["slug"], qualified["slug"])
        self.assertEqual(bare["stats"]["count"], qualified["stats"]["count"])

    def test_bare_feature_slug_returns_backlinks(self):
        # `001-waitlist` is wiki-linked from 002-login/spec.md
        # AND from patterns.md ("Used by: [[001-waitlist]]").
        result = get_backlinks(self.root, {"slug": "001-waitlist"})
        self.assertNotIn("error", result, msg=result)
        self.assertEqual(result["slug"], "001-waitlist")
        self.assertEqual(result["node"]["kind"], "feature")
        self.assertGreaterEqual(result["stats"]["count"], 1)
        from_paths = [bl["from_path"] for bl in result["backlinks"]]
        # At least one backlink must come from a sibling feature spec.
        self.assertTrue(
            any("002-login" in p for p in from_paths)
            or any("patterns.md" in p for p in from_paths),
            f"expected 002-login or patterns.md backlink in {from_paths!r}",
        )

    def test_unknown_slug_returns_available_list(self):
        # The canonical "node not found" shape is {error, slug, available}.
        # `available` is capped at 30 nodes — but in this small fixture
        # we expect well under that, so just sanity-check it's a list.
        result = get_backlinks(self.root, {"slug": "nonexistent-slug-xyz"})
        self.assertIn("error", result)
        self.assertIn("not found", result["error"])
        self.assertEqual(result["slug"], "nonexistent-slug-xyz")
        self.assertIn("available", result)
        self.assertIsInstance(result["available"], list)
        # The fixture has at least the two feature folders + a few
        # patterns headings — assertion is loose so reorderings/additions
        # to the fixture don't ripple into this test.
        slugs = {n["slug"] for n in result["available"]}
        self.assertIn("001-waitlist", slugs)

    def test_missing_slug_arg_returns_error(self):
        result = get_backlinks(self.root, {})
        self.assertIn("error", result)
        self.assertIn("slug", result["error"])

    def test_empty_graph_returns_gracefully(self):
        # Strip the fixture down so only INDEX.md remains. The graph
        # cache must still build (no nodes, no edges) and the query
        # must return the canonical "not found" shape rather than crash.
        sdd = os.path.join(self.root, ".sdd")
        # Remove every other markdown surface and the features tree.
        for name in ("decisions.md", "patterns.md", "config.md"):
            path = os.path.join(sdd, name)
            if os.path.isfile(path):
                os.remove(path)
        import shutil
        shutil.rmtree(os.path.join(sdd, "features"), ignore_errors=True)
        # Bust the graph cache so it rebuilds against the stripped tree.
        cache = os.path.join(sdd, ".cache", "graph.json")
        if os.path.isfile(cache):
            os.remove(cache)
        result = get_backlinks(self.root, {"slug": "anything"})
        self.assertIn("error", result)
        self.assertIn("available", result)
        # Empty graph → empty available list, but the shape is still well-formed.
        self.assertEqual(result["available"], [])


if __name__ == "__main__":
    unittest.main()
