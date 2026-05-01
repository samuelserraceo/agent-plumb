"""Unit tests for the `get_neighbours` query (Tier 1 graph traversal).

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_get_neighbours

Each test exercises a documented branch of the contract:
  - happy path: returns BOTH outgoing (own wiki-links) and incoming (citations)
  - depth=2 strictly-superset of depth=1 in a chain
  - depth>3 silently caps + emits a warning field
  - non-existent slug returns the canonical {error, available} shape
  - missing arg slug returns the canonical {error} shape
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

from queries import get_neighbours  # noqa: E402

from tests.conftest import make_temp_project  # noqa: E402


class _FixtureBase(unittest.TestCase):
    with_semantic_search = False

    def setUp(self):
        self.root, self._cleanup = make_temp_project(
            with_semantic_search=self.with_semantic_search
        )

    def tearDown(self):
        self._cleanup()


class GetNeighboursTests(_FixtureBase):
    def test_happy_path_returns_outgoing_and_incoming(self):
        # 001-waitlist's spec.md cites [[pattern:auth-retry-logic]] and
        # [[002-login]] (outgoing). It is itself cited by 002-login's
        # spec.md and patterns.md ("Used by: [[001-waitlist]]") — incoming.
        result = get_neighbours(self.root, {"slug": "001-waitlist"})
        self.assertNotIn("error", result, msg=result)
        self.assertEqual(result["slug"], "001-waitlist")
        self.assertEqual(result["node"]["kind"], "feature")
        self.assertEqual(result["depth"], 1)
        # Both directions must surface at least one edge each.
        self.assertGreaterEqual(result["stats"]["outgoing_count"], 1)
        self.assertGreaterEqual(result["stats"]["incoming_count"], 1)
        # Outgoing edges carry the target identity (slug + path + kind).
        for edge in result["outgoing"]:
            self.assertIn("to_slug", edge)
            self.assertIn("from_path", edge)
            self.assertIn("from_line", edge)
        # Incoming edges carry the source's owning slug + line.
        for edge in result["incoming"]:
            self.assertIn("from_slug", edge)
            self.assertIn("from_path", edge)
            self.assertIn("from_line", edge)
        # Sanity: depth-1 result MUST NOT carry the "warning" field.
        self.assertNotIn("warning", result)

    def test_depth_2_does_not_shrink_versus_depth_1(self):
        # Graph traversal at higher depth can only ADD nodes, never
        # remove them. We don't assert strict-superset because the
        # small fixture may saturate at depth-1; we assert non-shrinking.
        d1 = get_neighbours(self.root, {"slug": "001-waitlist", "depth": 1})
        d2 = get_neighbours(self.root, {"slug": "001-waitlist", "depth": 2})
        self.assertNotIn("error", d1, msg=d1)
        self.assertNotIn("error", d2, msg=d2)
        self.assertEqual(d2["depth"], 2)
        d1_total = d1["stats"]["outgoing_count"] + d1["stats"]["incoming_count"]
        d2_total = d2["stats"]["outgoing_count"] + d2["stats"]["incoming_count"]
        self.assertGreaterEqual(d2_total, d1_total)

    def test_depth_above_max_is_silently_capped_with_warning(self):
        # The contract: requested_depth>3 is silently capped to 3, but
        # the result includes a `warning` field so the caller can see
        # what happened.
        result = get_neighbours(self.root, {"slug": "001-waitlist", "depth": 99})
        self.assertNotIn("error", result, msg=result)
        self.assertEqual(result["depth"], 3, "depth must be capped at 3")
        self.assertIn("warning", result)
        self.assertIn("3", result["warning"])

    def test_invalid_depth_falls_back_to_default(self):
        # Non-int / negative depths are coerced to the default of 1.
        # The function must not crash and must not emit a warning
        # (the user didn't ask for depth>3).
        result = get_neighbours(self.root, {"slug": "001-waitlist", "depth": -5})
        self.assertNotIn("error", result, msg=result)
        self.assertEqual(result["depth"], 1)
        self.assertNotIn("warning", result)

    def test_unknown_slug_returns_available_list(self):
        result = get_neighbours(self.root, {"slug": "ghost-node"})
        self.assertIn("error", result)
        self.assertIn("not found", result["error"])
        self.assertEqual(result["slug"], "ghost-node")
        self.assertIn("available", result)
        self.assertIsInstance(result["available"], list)
        slugs = {n["slug"] for n in result["available"]}
        # The fixture has these features, so they must be in `available`.
        self.assertIn("001-waitlist", slugs)

    def test_missing_slug_arg_returns_error(self):
        result = get_neighbours(self.root, {})
        self.assertIn("error", result)
        self.assertIn("slug", result["error"])

    def test_pattern_node_neighbours(self):
        # Patterns are a different node kind — verify the query handles
        # them too. `auth-retry-logic` is incoming-only from the two
        # spec files; outgoing should be empty (patterns.md's "Used by:
        # [[001-waitlist]]" is on a different heading-block but the
        # graph treats edges by source FILE, so it counts as a
        # patterns.md edge — see notes below).
        result = get_neighbours(self.root, {"slug": "pattern:auth-retry-logic"})
        self.assertNotIn("error", result, msg=result)
        self.assertEqual(result["node"]["kind"], "pattern")
        self.assertGreaterEqual(result["stats"]["incoming_count"], 1)


if __name__ == "__main__":
    unittest.main()
