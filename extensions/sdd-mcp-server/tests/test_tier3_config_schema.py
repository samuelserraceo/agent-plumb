"""T2 — Schema test for `parameters.mcp.tier3` block in templates/.sdd/config.md.

Asserts the §6 data-contract schema landed in the consumer-facing
template config so init.sh ships it to new projects:

  parameters.mcp.tier3:
    enabled: false
    provider: ""
    endpoint: ""
    model: ""
    max_calls_per_run: 10
    max_input_tokens_per_call: 8000
    max_total_tokens_per_run: 100000
    auth_header: ""

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_tier3_config_schema
"""

from __future__ import annotations

import os
import re
import unittest


class TestTier3ConfigSchema(unittest.TestCase):
    """The new tier3 block must exist in the template config with the
    fields the §6 data-contract approved (anti-theatre — no
    cost_limit_usd; only mechanically-counted caps)."""

    @classmethod
    def setUpClass(cls):
        # Walk up from this test file to the repo root, then read
        # templates/.sdd/config.md. Keeps the test independent of the
        # cwd it's run from.
        here = os.path.dirname(os.path.abspath(__file__))
        repo_root = here
        for _ in range(8):
            candidate = os.path.join(repo_root, "templates", ".sdd", "config.md")
            if os.path.isfile(candidate):
                cls.config_path = candidate
                break
            repo_root = os.path.dirname(repo_root)
        else:
            raise FileNotFoundError(
                "Could not find templates/.sdd/config.md walking up from this test"
            )
        with open(cls.config_path, encoding="utf-8") as f:
            cls.body = f.read()

    def _has_yaml_key_under(self, parent: str, key: str) -> bool:
        """Loose check: does the YAML block under parent contain key?

        We don't load the whole file as YAML (config.md is markdown
        wrapping a YAML frontmatter block — loose grep is more
        forgiving across small format drift).
        """
        # Match `parent:` then any number of indented lines then `key:`
        pattern = rf"(?ms)^{re.escape(parent)}:\s*\n(?:[ \t]+\S.*\n)*?[ \t]+{re.escape(key)}:"
        return bool(re.search(pattern, self.body))

    def _scoped_tier3_idx(self) -> int:
        """Return the index of `tier3:` *under parameters → mcp* — not
        any random `tier3:` mention elsewhere (CR feedback).
        """
        params_idx = self.body.find("parameters:")
        if params_idx == -1:
            return -1
        mcp_idx = self.body.find("mcp:", params_idx)
        if mcp_idx == -1:
            return -1
        tier3_idx = self.body.find("tier3:", mcp_idx)
        return tier3_idx

    def _tier3_block(self) -> str:
        """Return the tier3 section content, bounded by the next sibling key
        or top-level YAML key (rather than a brittle fixed N-byte slice).

        CR feedback: the previous fixed 1500-byte slice broke when the
        section grew. Boundary heuristic: read until the next line
        starting at the same or shallower indent (i.e. another key under
        `mcp:` such as `tier4:` if it ever lands, OR a sibling under
        `parameters:` like `voice:`, OR a top-level closing `---` of the
        frontmatter). We use a regex that matches a YAML key at column 0
        (top-level) OR at 4 spaces (sibling of mcp's children) OR the
        frontmatter terminator.
        """
        idx = self._scoped_tier3_idx()
        if idx == -1:
            return ""
        rest = self.body[idx:]
        # Skip the `tier3:` line itself, then look for the first line
        # at indent ≤4 spaces that's also a key (k:) or the `---`
        # frontmatter terminator. That marks the end of the block.
        boundary = re.search(r"\n(?:[a-zA-Z_][a-zA-Z0-9_]*:|    [a-zA-Z_][a-zA-Z0-9_]*:|---\s*$)", rest[len("tier3:"):], re.MULTILINE)
        if boundary is None:
            return rest
        return rest[: len("tier3:") + boundary.start()]

    def test_tier3_block_exists(self):
        """The `tier3:` block exists under `parameters.mcp`."""
        tier3_idx = self._scoped_tier3_idx()
        self.assertGreater(tier3_idx, -1, msg=(
            "parameters.mcp.tier3 block missing from templates/.sdd/config.md "
            "— see §6 data-contract for the approved schema"
        ))

    def test_tier3_has_required_fields(self):
        """All §6-approved fields are present in the schema."""
        required_fields = [
            "enabled",
            "provider",
            "endpoint",
            "model",
            "max_calls_per_run",
            "max_input_tokens_per_call",
            "max_total_tokens_per_run",
            "auth_header",
        ]
        # Locate the scoped tier3 block once (not in the inner loop).
        tier3_idx = self._scoped_tier3_idx()
        self.assertGreater(tier3_idx, -1, "tier3 block missing under parameters.mcp")
        tier3_block = self._tier3_block()
        for field in required_fields:
            with self.subTest(field=field):
                self.assertIn(f"{field}:", tier3_block,
                              msg=f"tier3.{field} not found in the schema block")

    def test_tier3_off_by_default(self):
        """`enabled: false` must be the default (foundation 3 — opt-in)."""
        tier3_idx = self._scoped_tier3_idx()
        self.assertGreater(tier3_idx, -1, "tier3 block missing under parameters.mcp")
        tier3_block = self._tier3_block()
        # match `enabled: false` (any whitespace before, allow comment after)
        self.assertRegex(tier3_block, r"enabled:\s*false",
                         "tier3.enabled must default to false (opt-in)")

    def test_no_cost_limit_usd_field(self):
        """Anti-theatre — `cost_limit_usd` was deliberately removed.

        Sam's catch on 2026-05-01: the framework can't price external
        services without a per-provider table or live ledger, so a USD
        circuit breaker would be theatre. Only call/token caps apply.

        We check for the actual YAML field shape (`cost_limit_usd:` with
        a colon at start of an indented line) rather than mere
        substring presence — that way the explanatory comment in the
        schema (which legitimately mentions the absent field by name)
        doesn't trip the test.
        """
        tier3_idx = self._scoped_tier3_idx()
        self.assertGreater(tier3_idx, -1, "tier3 block missing under parameters.mcp")
        tier3_block = self._tier3_block()
        # Field would appear at start of a line (after indent) with a
        # colon and value — not as a word inside a `#` comment.
        # Match: `^[ \t]+cost_limit_usd:` (multiline)
        self.assertNotRegex(tier3_block, r"(?m)^[ \t]+cost_limit_usd:", msg=(
            "cost_limit_usd was removed by 2026-05-01 anti-theatre audit; "
            "the framework can't enforce dollar amounts. Use "
            "max_calls_per_run + max_input_tokens_per_call + "
            "max_total_tokens_per_run instead."
        ))
