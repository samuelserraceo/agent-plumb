# Idea: Cross-branch feature ID collision — three SDD rules collide on git merges

**Captured:** 2026-05-10
**Status:** captured

## What's the idea?
When two long-running branches independently scaffold a feature with the same numeric ID (e.g. both pick `008` because both branched from the same `007`-shipped main), the local merge collides with three SDD framework rules in sequence:

1. **`append-only` on `.sdd/decisions.md`** — blocks rewriting historical wiki-links from `[[008-mine]]` to `[[009-mine]]` after a folder rename, because the rename changes prior content
2. **`cofile-block` (CLAIM × POLICY)** — blocks the merge commit because origin's merged content brings both `verification.json` (CLAIM class) and `manifest.json` / framework scripts (POLICY class) into one commit
3. **wiki-link resolution check** — old entries pointing at the renamed folder break, forcing edits that violate rule 1

These rules are correct individually. They collide on cross-branch parallel work where two features get the same ID via independent /start invocations.

## What problem might it solve?
Today the agent (me, this session) hits a hard stop on local merges when two branches produced the same feature ID. The three rules form a deadlock the agent can't unwind without `--no-verify` (which the system rule-set forbids without explicit user authorisation). This forces the user to take over the merge in GitHub's web UI or via a manual `--no-verify` override locally — a friction the agent can't resolve alone, and that scales badly as parallel-feature work gets more common.

## Why might it matter?
Already happened once (this PR — feature 008 background-while-waiting collided with origin's just-shipped feature 008 pi.dev adapter via PR #214). Will happen again as #42's parallel-features doctrine sees more use. The fix could be doctrine-level (e.g. `/start` reserves IDs via a remote check before scaffolding, or merge commits get a special-case bypass for the three named rules), build-level (new `sdd-merge.sh` helper that handles the collision dance), or process-level (numbering convention that avoids parallel-branch collisions, e.g. branch-prefixed IDs like `008a` / `008b`).

Compounds with idea 005 (auto-advance) and idea 002 (lego models): an autonomous agent finishing more work in parallel hits this collision shape *more often*, not less. Worth solving before "agent runs solo" gets common.

## Confidence
half-baked — pattern is real (we just hit it), but the right fix isn't obvious yet. Could be anywhere from a small `sdd-merge.sh` helper to a deeper rethink of how feature IDs are minted across branches. Needs design pass.

## Related features
- `.sdd/features/008-background-while-waiting/` (this PR — concrete example of the friction)
- [[008-build-the-sdd-on-pi-extension-package]] (origin's already-shipped 008 — the colliding ID)
- #42 parallel-feature work (the doctrine that makes parallel branches first-class — and the doctrine this collision shape gets more frequent under)
- `feedback_full_autonomous_build.md` (autonomous BUILD makes parallel branches more common)
