---
description: Promote a QUEUED work item to actively-worked-on. Flips PHASE: QUEUED → the playbook's first stage and sets it as INDEX.md's Active.
argument-hint: "<work-item-id-or-slug>"
---

# /promote-to-active

Closes [#169](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/169). When you scaffold work items in advance with `/start --queued ...` (or via `project-queue-features`), they sit in `## Backlog` with `[PHASE: QUEUED]` — folder + spec.md exist, but the framework refuses `/next` on them. When you're ready to start one for real, run this command.

## Usage

```
/promote-to-active 002-profile-setup
/promote-to-active 002              # bare NNN works too (lenient match)
/promote-to-active profile-setup    # bare slug also works
```

## What it does

1. Locates the queued work item by ID or slug (lenient match across `.sdd/features/`, `.sdd/bugs/`, `.sdd/refactors/`, etc.).
2. Reads the work item's playbook from spec.md frontmatter and finds the playbook's first stage (typically `SPEC` for features, `REPRO` for bugs).
3. Edits the spec.md:
   - `[PHASE: QUEUED]` → `[PHASE: <first-stage-id>]`
   - `**Active blocker:**` line rewritten to point at §1 of the first stage
4. Edits INDEX.md:
   - Moves the row from `## Backlog` to `## In flight`
   - Sets `**Active:**` to this work item
5. Tells you the exact `/next` to run.

## What it does NOT do

- Does NOT auto-create or switch git branches (that's still `/next`'s first action when needed).
- Does NOT touch the spec.md body — only the PHASE line + Active blocker pointer change.
- Does NOT run on items that aren't QUEUED — refuses with a plain-English error if the target's PHASE is already SPEC / BUILD / SHIPPED / etc.

## Errors (plain English)

- *"No work item matched <arg>."* → Run `/status` to see what's open. Pass the exact `NNN-slug`, the bare `NNN`, or a unique slug substring.
- *"Multiple work items matched <arg>."* → Two folders share the slug fragment. Use the full `NNN-slug` to disambiguate.
- *"Work item is not in QUEUED phase."* → Already promoted (or was never queued). Nothing to do; `/next` should advance it normally.

## Implementation

The slash command body invokes `bash .sdd/scripts/promote-to-active.sh "<arg>"`.
