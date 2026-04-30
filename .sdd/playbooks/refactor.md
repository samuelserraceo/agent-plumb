---
type: playbook
slug: refactor
title: "Refactor without changing behaviour"
when_to_use: "the existing behaviour is correct but the code shape is wrong (duplication, leaky abstraction, hard-to-test seam) and you want to clean it up safely with regression coverage + minimal-diff discipline"
work_item_folder: refactors/
work_item_id_pattern: "{NNN}-{slug}"
terminal_state: SHIPPED
stages:
  - id: SPEC
    actions:
      - refactor-scope
      - regression-coverage
      - refactor-approach
      - minimal-diff-verify
    exit_checks:
      - { id: C-spec-scope,      check: "scope captured in §1 (what's being moved/extracted/renamed)" }
      - { id: C-spec-coverage,   check: "regression coverage listed in §2 (existing tests + any new T-tests for shared shape)" }
      - { id: C-spec-approach,   check: "approach approved in §3" }
  - id: BUILD
    actions:
      - run-mode-chosen
      - build-task
    exit_checks:
      - { id: C-build-tasks-green, check: "every task is GREEN (regression tests still passing post-refactor)" }
  - id: SHIP
    actions:
      - verify-test-run
      - learn
      - push-pr
      - verify-ci-green
      - mark-shipped
    exit_checks:
      - { id: C-ship-pr-url, check: "PR URL recorded in INDEX.md Shipped section" }
      - { id: C-ship-marked, check: ".shipped marker file exists in refactor folder" }
---

# Refactor without changing behaviour

## When this playbook fits

You're cleaning up code shape — extracting a helper, removing duplication, splitting a long function, renaming for clarity, moving a file. **The user-visible behaviour stays exactly the same.** What changes is the internal structure, the readability, the test surface, the cognitive load when someone reads the diff in 6 months.

This playbook is **not** for:
- Building something new (new behaviour, new entity) → use `feature.md`
- Fixing broken behaviour → use `bug.md` (`/start [BUG] "..."`)
- A behavioural change disguised as a refactor — that's the most common refactor anti-pattern. Halt and switch to `feature.md`.

If `/start --playbook=refactor "..."` is invoked, the framework auto-routes here.

## What to expect

Three stages, lighter than `feature.md`:

1. **SPEC** — 4 sections. Most are 1-2 paragraphs. Total time: 15-45 minutes (longer than a bug because regression coverage takes thinking).
2. **BUILD** — implement the refactor in the smallest commits possible. Test discipline still applies: every commit must keep the regression tests GREEN.
3. **SHIP** — verify-test-run + learn + push-pr + ship. Skips adversarial-review (replaced by §2 regression-coverage from SPEC) and edge-case-sweep (refactors don't change behaviour, no new edges).

If the SPEC reveals you're actually about to change behaviour (new edge cases, new return values, new side effects), the framework halts and asks: *"this looks like a feature, not a refactor — switch?"*

## How the agent runs each step

Same 4-step inner loop as feature.md (LOCATE → EXECUTE → SYNC → ADVANCE). One `[ ]` row in `spec.md` per atomic step; one step = one commit.

## What's locked, what's not

- Section order is fixed (scope → regression-coverage → approach → minimal-diff-verify). Refusal to advance phase while any `[ ]` remains in the current phase.
- `refactor-approach` defaults to `requires_user_approval: true`. The shape of the new code is the load-bearing decision; the user signs off before BUILD starts.
- `minimal-diff-verify` is **mechanical**: at the end of SPEC the agent runs `git diff --shortstat` against the branch base and halts if the line-count delta is positive (additions > deletions). Refactors should shrink the codebase or hold it steady; if a refactor adds lines, that's a hint it's actually a feature.

## Why no §user-stories / §UX brief / §data-contract / §acceptance-criteria

Refactors don't introduce new behaviour, new entities, new user-facing capability. The "acceptance criterion" is implicit: **the regression tests stay GREEN before and after the refactor**. §2 captures which tests prove that; §4 captures that the diff actually shrank.

If a refactor reveals a missing entity or a behaviour gap, you've found a feature-shaped problem hiding inside a refactor. Switch playbooks; come back to the refactor after the feature ships.
