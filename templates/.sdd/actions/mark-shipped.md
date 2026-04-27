---
type: action
slug: mark-shipped
tag: AGENT-LED
title: "mark-shipped"
short_label: "Shipped"
steps:
  - { id: mark, action: write_shipped_marker_update_INDEX_shipped_block, field: ".shipped" }
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

Final SHIP action. Move the feature from `## Active` to `## Shipped` in INDEX.md, drop a `.shipped` marker, commit.

**Actions:**

1. **Update INDEX.md:**
   - Remove the feature line from `## Active`
   - Append to `## Shipped`: `features/<id>-<slug> — <one-line summary> [shipped <date>] (PR: <URL>)`
2. **Drop marker file:** `touch .sdd/features/<id>-<slug>/.shipped`
   - This signals to CLAUDE.md's "shipped features are cold" rule that future sessions should NOT re-read this folder unless explicitly asked.
3. **Commit:** `git add .sdd/INDEX.md .sdd/features/<id>-<slug>/.shipped && git commit -m "[SDD] index: <id>-<slug> shipped"`

**Sync requirement (Theme 4's pre-commit-touches hook):** the `touches: [.sdd/INDEX.md]` declaration ensures INDEX.md is staged in this commit.

**Output:** fill `spec.md` under `### mark-shipped` with `**Shipped:** [x]`.

**End the turn with:** `Feature <id>-<slug> shipped. SHIP phase complete.` Optional one-line celebration. Then auto-end the session — the user typically runs `/start` for the next feature when they're ready.
