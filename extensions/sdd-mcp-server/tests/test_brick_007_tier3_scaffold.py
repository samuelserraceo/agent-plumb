"""T4 — Brick 007 has placeholder Tier 3 sub-questions scaffolded.

Per §11 AC#20: when the user enables the MCP server during /sdd-setup,
the wizard ALSO asks Tier 3 sub-questions (Ollama + Gemma config)
and writes the answers into parameters.mcp.tier3 in config.md.

T4 just scaffolds the QUESTION CONTENT — the actual wiring (the
wizard running them and writing config) is T23's E2E test.

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_brick_007_tier3_scaffold
"""

from __future__ import annotations

import os
import unittest


class TestBrick007Tier3Scaffold(unittest.TestCase):
    """Brick 007 must include a Tier 3 sub-questions section that asks
    about Ollama + Gemma + cost caps; and its frontmatter records_at
    must mention the tier3 config path so the wizard knows where to
    write the answers."""

    @classmethod
    def setUpClass(cls):
        here = os.path.dirname(os.path.abspath(__file__))
        repo_root = here
        for _ in range(8):
            candidate = os.path.join(
                repo_root, "templates", ".sdd", "setup", "007-mcp-server.md"
            )
            if os.path.isfile(candidate):
                cls.path = candidate
                break
            repo_root = os.path.dirname(repo_root)
        else:
            raise FileNotFoundError("brick 007 not found walking up from this test")
        with open(cls.path, encoding="utf-8") as f:
            cls.body = f.read()

    def test_tier3_section_heading_present(self):
        """The brick has a heading naming Tier 3 explicitly."""
        self.assertTrue(
            any(h in self.body for h in [
                "## Tier 3", "### Tier 3", "## Chat-based answers (Tier 3)",
                "### Chat-based answers (Tier 3)",
            ]),
            msg="Brick 007 should have a Tier 3 sub-section heading"
        )

    def test_ollama_named(self):
        """Ollama is named as the v1.1-supported provider."""
        self.assertIn("Ollama", self.body,
                      msg="Brick 007 Tier 3 sub-questions should name Ollama")

    def test_gemma_named(self):
        """Gemma is named as the model family (per the PRD)."""
        self.assertIn("Gemma", self.body,
                      msg="Brick 007 Tier 3 sub-questions should name Gemma")

    def test_records_at_includes_tier3_path(self):
        """The frontmatter records_at must include the tier3 config path
        so the wizard knows where to write the user's answers."""
        # Frontmatter is the first --- … --- block at top of file.
        # Look for a records_at: line that includes 'tier3' string OR
        # a records_at block that has both mcp.enabled (existing) and
        # tier3 paths.
        # Simple substring test: the front matter mentions tier3 somewhere.
        front_idx = self.body.find("---", 1)  # end of frontmatter
        # CR feedback: guard against the find()==-1 case so a stray slice
        # doesn't silently pass an assertion that depended on the slice.
        if front_idx == -1:
            self.fail(
                "missing frontmatter end delimiter '---' in brick 007 — "
                "the file is expected to start with a '---' frontmatter block"
            )
        front = self.body[: front_idx + 3]
        self.assertIn(
            "tier3", front,
            msg=(
                "Brick 007 frontmatter (records_at or agent_infers) should "
                "mention tier3 so the wizard knows where to record Tier 3 answers"
            ),
        )

    def test_v1_1_scope_explicit(self):
        """The brick says clearly that v1.1 supports Ollama+Gemma only;
        other providers are v1.2+ wizard scope."""
        # Look for any mention of v1.2+ or "v1.1 wizard" or "v1.2 widens"
        scope_phrases = [
            "v1.1 wizard", "v1.2+", "v1.1 supports", "v1.1 only",
            "v1.1's only", "wizard widens",
        ]
        self.assertTrue(
            any(p in self.body for p in scope_phrases),
            msg=(
                "Brick 007 Tier 3 section should explicitly state v1.1 "
                "wizard scope (Ollama+Gemma only) — see §5/§6/§9 of the spec"
            ),
        )
