---
type: action
slug: mark-shipped
tag: AGENT-LED
title: "mark-shipped"
short_label: "Shipped"
steps:
  - { id: mark, action: write_shipped_marker_update_INDEX_shipped_block, field: ".shipped", triggers: [ship_complete] }
used_by: [feature]
references: [push-pr, verify-ci-green]
touches: [.sdd/INDEX.md]
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

2. **Compose the richer `## Shipped` entry.** v0.9 catalog format — a multi-line block with cross-references that lets future sessions see what was built without cold-reading the spec.md:

   ```markdown
   - **<id>-<slug>** — <one-line summary>
     - Shipped: <YYYY-MM-DD> · PR: <URL>
     - Data-model: <Entity>.<field> (added/modified) [if §6 contributed]
     - Extends: <id>-<slug>  [or `(root)` if none]
     - Lesson: <one-line lesson> [if §learn produced one — link patterns.md]
   ```

   Notes:
   - **Extends:** read the spec.md frontmatter `extends:` field; if absent, write `(root)`.
   - **Data-model:** scan §6 (data-contract) for entities/fields the spec added or changed. List the entity name + field; if no schema change, omit the line.
   - **Lesson:** copy the lesson title from §learn (the lesson body lives in `patterns.md` — INDEX.md just names it). If skipped, omit.
   - One blank line between shipped entries for readability.
   - Keep the line count under the `size_warn: 200` (config.md `file_rules:`) by archiving older entries to `.sdd/archive/INDEX.md` once that warn fires (deferred to `/compress index`).

3. **Remove the work item line from `## In flight`.**

4. **Drop marker file:** `touch .sdd/<work_item_folder>/<id>-<slug>/.shipped` — signals CLAUDE.md's "shipped features are cold" rule that future sessions should NOT re-read this folder unless explicitly asked.

5. **Commit:** `git add .sdd/INDEX.md .sdd/<work_item_folder>/<id>-<slug>/.shipped && git commit -m "[SDD] index: <id>-<slug> shipped"`

**Sync requirement (pre-commit-rules.sh `touches:` enforcement):** the `touches: [.sdd/INDEX.md]` declaration ensures INDEX.md is staged in this commit.

**Why richer entries (Memory-at-scale pillar):** the catalog block is the only durable, agent-readable index of what's been built. Future sessions extending or tweaking a feature read INDEX.md (already injected via UserPromptSubmit hook), match by name or substring, and follow the `Extends:` chain — all without cold-reading shipped specs. The `Data-model:` line points at `data-model.md`'s entity definitions; the `Lesson:` line points at `patterns.md`. Cross-references replace re-reading.

**Output:** fill `spec.md` under `### mark-shipped` with `**Shipped:** [x]`.

**End the turn with:** `Feature <id>-<slug> shipped. SHIP phase complete.` Optional one-line celebration. Then auto-end the session — the user typically runs `/start` for the next feature when they're ready.
