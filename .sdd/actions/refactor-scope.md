---
type: action
slug: refactor-scope
tag: USER-LED
title: "§1 Scope"
short_label: "Scope"
steps:
  - { id: scope, prompt: "What's being moved/extracted/renamed? Paste the duplicated or messy code (or the function signature you're extracting). Be specific — file paths + line ranges.", field: "§1.scope" }
used_by: [refactor]
references: []
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 15
  max_tokens: 3500
  max_commits: 1
requires_user_approval: false
---

Capture exactly what code is in scope for this refactor. The narrower the scope, the smaller the diff, the safer the change.

**Required output (fill §1):**

- **Affected files + line ranges** — list every place the code lives today. e.g. *"`scripts/settings.sh:42-58` (atomic-write block in `set` subcommand) + `scripts/settings.sh:91-107` (same block in `reset` subcommand)."*
- **What stays the same** — call out the user-visible behaviour that MUST be preserved through the refactor. *"Both subcommands still create the temp file under `.sdd/.tmp/`, still rename atomically, still emit the same stderr message on failure."*
- **What's NOT in scope** — list anything you considered touching but deliberately left for a later refactor. *"Considered also extracting the YAML-frontmatter parser duplicated across 4 scripts — too much for this refactor; will file a separate item."*

**Push for narrowness.** If the scope description includes the word "while we're there" or "also clean up", flag it. Refactors that grow during scoping become refactors that fail during minimal-diff-verify in §4. The smaller the scope, the higher the chance of a clean ship.

**Halt-on-feature-shaped-refactor.** If the scope description reveals new behaviour (new return values, new side effects, new error cases), this is a feature, not a refactor. Surface that politely:

> *"That description includes new behaviour (X, Y, Z). Refactors must preserve user-visible behaviour exactly — anything new is feature work. Shall we switch to `feature.md`? Reply `switch` to re-scaffold, or describe the refactor without the new behaviour."*

**Output:** fill `spec.md` under `### §1.scope` with file paths + ranges + behaviour-preserved + out-of-scope.

**What it looks like:**

Tell me what's getting moved or renamed, and what's NOT.

Example: *"Refactoring `lib/auth.ts` → `lib/auth/{tokens,session,middleware}.ts`. NOT touching: API endpoints (they keep importing the same exported names), tests (they exercise behaviour, not file paths), public types (re-exported from the new files)."* Be specific — if a refactor touches more than one module + has more than one caller, we slow down and discuss.

**End the turn with:** *"Run `/next` to capture regression coverage in §2."*
