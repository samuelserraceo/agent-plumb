"""T3 — Confirm Tier3Config + SynthesisCache entries are in data-model.md.

The §6 data-contract was approved with two new framework-domain
entities. They were synced into `.sdd/data-model.md` during the SPEC
walk on 2026-05-01. This test asserts they're still there.

Run from extensions/sdd-mcp-server/:

    python3 -m unittest tests.test_data_model_tier3_entries
"""

from __future__ import annotations

import os
import unittest


class TestDataModelTier3Entries(unittest.TestCase):
    """Both entities + their key field names + the v1.1-wizard-Ollama-only
    note must remain in `.sdd/data-model.md` once shipped."""

    @classmethod
    def setUpClass(cls):
        here = os.path.dirname(os.path.abspath(__file__))
        repo_root = here
        for _ in range(8):
            candidate = os.path.join(repo_root, ".sdd", "data-model.md")
            if os.path.isfile(candidate):
                cls.path = candidate
                break
            repo_root = os.path.dirname(repo_root)
        else:
            raise FileNotFoundError(
                ".sdd/data-model.md not found walking up from this test"
            )
        with open(cls.path, encoding="utf-8") as f:
            cls.body = f.read()

    def test_synthesis_cache_entity_present(self):
        """SynthesisCache is named as a framework-domain entity."""
        self.assertIn("### SynthesisCache", self.body, msg=(
            ".sdd/data-model.md should declare SynthesisCache as a framework "
            "entity per §6 data-contract"
        ))

    def test_tier3_config_entity_present(self):
        """Tier3Config is named as a framework-domain entity."""
        self.assertIn("### Tier3Config", self.body, msg=(
            ".sdd/data-model.md should declare Tier3Config as a framework "
            "entity per §6 data-contract"
        ))

    @staticmethod
    def _section_block(body: str, heading: str) -> str:
        """Extract from `heading` to the next H3 (or EOF). Avoids the
        brittle fixed 2000-byte slice CR flagged."""
        idx = body.find(heading)
        if idx == -1:
            return ""
        # Find next H3 boundary (start-of-line "### ") after this heading.
        nxt = body.find("\n### ", idx + len(heading))
        if nxt == -1:
            return body[idx:]
        return body[idx:nxt]

    def test_synthesis_cache_describes_corpus_signature_keying(self):
        """The cache description names corpus signature as part of the key."""
        idx = self.body.find("### SynthesisCache")
        self.assertGreater(idx, -1)
        block = self._section_block(self.body, "### SynthesisCache")
        self.assertIn("corpus_signature", block,
                      msg="SynthesisCache description should mention corpus_signature in the key shape")

    def test_synthesis_cache_describes_eviction_policy(self):
        """Per §15 sweep, the cache LRU-evicts at 1000 entries; documented here."""
        idx = self.body.find("### SynthesisCache")
        self.assertGreater(idx, -1)
        block = self._section_block(self.body, "### SynthesisCache")
        self.assertIn("LRU", block, msg=(
            "SynthesisCache description should mention LRU eviction policy "
            "(added by §15 edge-case sweep on 2026-05-01)"
        ))

    def test_tier3_config_describes_v1_1_ollama_scope(self):
        """The config description names the v1.1 wizard scope (Ollama+Gemma only)."""
        idx = self.body.find("### Tier3Config")
        self.assertGreater(idx, -1)
        block = self._section_block(self.body, "### Tier3Config")
        self.assertIn("v1.1", block,
                      msg="Tier3Config description should reference v1.1 wizard scope")
        self.assertIn("Ollama", block,
                      msg="Tier3Config description should name Ollama as the v1.1-supported provider")

    def test_tier3_config_no_cost_limit_usd_mention_as_field(self):
        """Anti-theatre — no cost_limit_usd field is listed for Tier3Config."""
        idx = self.body.find("### Tier3Config")
        self.assertGreater(idx, -1)
        block = self._section_block(self.body, "### Tier3Config")
        # The description may legitimately mention the ABSENT field by name
        # (anti-theatre note); it must not list it as a present field.
        # Heuristic: look for `cost_limit_usd:` (with colon) — would be a
        # YAML-style field listing.
        self.assertNotRegex(block, r"\bcost_limit_usd:", msg=(
            "Tier3Config description must not list cost_limit_usd as a field — "
            "removed by 2026-05-01 anti-theatre audit"
        ))
