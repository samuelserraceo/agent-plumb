---
type: action
slug: mark-shipped
tag: AGENT-LED
model_tier: mechanical
title: "mark-shipped"
short_label: "Shipped"
steps:
  - { id: mark, action: "write the .shipped marker and update INDEX.md's Shipped block", field: ".shipped", triggers: [ship_complete] }
used_by: [feature, bug, refactor]
references: [push-pr, verify-ci-green]
touches: [".sdd/INDEX.md", ".sdd/<work-item>/.shipped"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 1000
  max_commits: 1
requires_user_approval: false
---

Final SHIP action. Move the work item from `## In flight` to `## Shipped` in INDEX.md as a richer catalog entry, drop a `.shipped` marker, commit.

**Actions:**

1. **Read the spec.md frontmatter** (if present) for `extends:`. Note: not every spec has frontmatter — only ones started with `/start --extends=<id>` do.

2. **Compose the richer `## Shipped` entry.** v1.0 catalog format — a multi-line block with cross-references (wiki-links) that lets future sessions see what was built without cold-reading the spec.md:

   ```markdown
   - **[[<id>-<slug>]]** — <one-line summary>
     - Shipped: <YYYY-MM-DD> · PR: <URL>
     - Data-model: [[entity:<Entity>]].<field> (added/modified) [if §6 contributed]
     - Extends: [[<id>-<slug>]]  [or `(root)` if none]
     - Lesson: [[pattern:<lesson-slug>]] — <one-line lesson> [if §learn produced one]
   ```

   Notes:
   - **Slug as wiki-link:** the leading `[[<id>-<slug>]]` makes the INDEX.md row a graph edge from INDEX → feature folder. The MCP server's `get_backlinks` query then surfaces every reference to the feature without grep. Bare slug form (no prefix) — the slug resolves to the feature folder via priority 1 (filename match).
   - **Extends:** read the spec.md frontmatter `extends:` field; if present, wrap the value in `[[…]]`. If absent, write `(root)` (no link — there's nothing to point at).
   - **Data-model:** scan §6 (data-contract) for entities/fields the spec added or changed. Wrap the entity in `[[entity:<Entity>]]`. If no schema change, omit the line.
   - **Lesson:** copy the lesson slug from §learn — if the pattern was added to `patterns.md` under a heading like `### Auth retry logic`, write `[[pattern:auth-retry-logic]]`. If skipped, omit.
   - One blank line between shipped entries for readability.
   - Keep the line count under the `size_warn: 200` (config.md `file_rules:`) by archiving older entries to `.sdd/archive/INDEX.md` once that warn fires (deferred to `/compress index`).

3. **Remove the work item line from `## In flight`.**

4. **Drop marker file:** `touch .sdd/<work_item_folder>/<id>-<slug>/.shipped` — signals CLAUDE.md's "shipped features are cold" rule that future sessions should NOT re-read this folder unless explicitly asked.

5. **Commit:** `git add .sdd/INDEX.md .sdd/<work_item_folder>/<id>-<slug>/.shipped && git commit -m "[SDD] index: <id>-<slug> shipped"`

**Sync requirement (pre-commit-rules.sh `touches:` enforcement):** the `touches: [".sdd/INDEX.md", ".sdd/<work-item>/.shipped"]` declaration ensures both INDEX.md and the `.shipped` marker are staged in this commit. (The `<work-item>` placeholder is currently skipped by the F1 enforcer per the inline rule at `pre-commit-rules.sh`'s touches-validation loop, but it documents intent for the planned per-branch worktree-aware substitution — see issue #42.)

**Why richer entries (Memory-at-scale pillar):** the catalog block is the only durable, agent-readable index of what's been built. Future sessions extending or tweaking a feature read INDEX.md (already injected via UserPromptSubmit hook), match by name or substring, and follow the `Extends:` chain — all without cold-reading shipped specs. The `Data-model:` line points at `data-model.md`'s entity definitions; the `Lesson:` line points at `patterns.md`. Cross-references replace re-reading.

**Output:** fill `spec.md` under `### mark-shipped` with `**Shipped:** [x]`.

**What it looks like:**

We're done — let me record it formally.

Example: *"Move the row from `## In flight` to `## Shipped` in INDEX.md (with the PR link, the date, what it depends on). Drop a `.shipped` marker in the feature folder so future sessions know not to re-read it."* You don't have to do anything — I just confirm it's all written down. (Decisions.md gets its phase-shipped audit entry as part of the SHIP-cycle's audit-log discipline, not as part of mark-shipped's authorised file changes — `touches:` here only declares INDEX.md.)

**End the turn with:** `Feature <id>-<slug> shipped. SHIP phase complete.` Optional one-line celebration. Then auto-end the session — the user typically runs `/start` for the next feature when they're ready.
