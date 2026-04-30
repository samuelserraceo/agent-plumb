---
type: playbook
slug: bug
title: "Ship a bug fix"
when_to_use: "something is broken in shipped behaviour and needs a tight repro → root-cause → minimal-diff fix → regression test"
work_item_folder: bugs/
work_item_id_pattern: "{NNN}-{slug}"
terminal_state: SHIPPED
stages:
  - id: SPEC
    actions:
      - bug-problem
      - bug-repro
      - bug-root-cause
      - bug-fix
      - bug-regression-test
    exit_checks:
      - { id: C-spec-repro,        check: "repro steps captured in §2" }
      - { id: C-spec-cause,        check: "root cause captured in §3" }
      - { id: C-spec-fix,          check: "proposed fix recorded in §4" }
      - { id: C-spec-regression,   check: "regression test drafted in §5" }
  - id: BUILD
    actions:
      - run-mode-chosen
      - build-task
    exit_checks:
      - { id: C-build-tasks-green, check: "every task is GREEN (test passing, code committed)" }
  - id: SHIP
    actions:
      - verify-test-run
      - learn
      - push-pr
      - verify-ci-green
      - mark-shipped
    exit_checks:
      - { id: C-ship-pr-url,  check: "PR URL recorded in INDEX.md Shipped section" }
      - { id: C-ship-marked,  check: ".shipped marker file exists in bug folder" }
---

# Ship a bug fix

## When this playbook fits

Something that USED to work doesn't, OR shipped behaviour is wrong, OR a hidden edge case is biting users. The shape of the work is: write down what's broken, prove you can reproduce it, find the root cause, propose the smallest fix, write a regression test that fails before the fix and passes after.

This playbook is **not** for:
- Building something new → use `feature.md` (`/start "<title>"`)
- A half-formed thought you might investigate later → use `/idea "<one-liner>"`
- A behavioural change that's working as designed but you want to change → use `feature.md` with `--extends`

If `/start [BUG] "..."` is invoked, the framework auto-routes here. Plain `/start "fix the X bug"` walks `feature.md` (slower, more ceremony) — use the `[BUG]` prefix for the dedicated bugfix path.

## What to expect

Three stages, much shorter than `feature.md`:

1. **SPEC** — 5 sections. Most are 1-2 sentences. Total time: 10-30 minutes.
2. **BUILD** — write the regression test (RED), apply the fix (GREEN), commit. The agent does the work.
3. **SHIP** — verify-test-run + learn + push-pr + ship. Same as feature.md but skips adversarial-review, prod-only ACs, and Playwright explore — those don't fit a bugfix's shape.

If the SPEC reveals the "bug" actually requires a real design decision (new behaviour, new entity, etc.), the framework halts and asks: *"this looks like a feature, not a bug — switch to feature.md?"*

## How the agent runs each step

Same 4-step inner loop as feature.md (LOCATE → EXECUTE → SYNC → ADVANCE). One `[ ]` row in `spec.md` per atomic step; one step = one commit.

## What's locked, what's not

- Section order is fixed (problem → repro → root-cause → fix → regression-test). The framework refuses phase advance while any `[ ]` remains in the current phase.
- `bug-fix` defaults to `requires_user_approval: true`. The fix is the load-bearing decision; the user signs off on the proposed minimal-diff approach before code lands. Hash-locking on the fix prevents silent post-approval edits to the approach during BUILD.
- `bug-regression-test` is also user-approved — the AC of "the bug doesn't happen anymore" needs the user to confirm the test actually proves it.

## Why no §user-stories / §data-contract / §UX brief / §acceptance-criteria

Bugs don't introduce new behaviour, new entities, new screens, or new user-facing capability. The "acceptance criterion" for a bug is implicit: *the regression test goes from RED to GREEN and stays GREEN*. The fix is approved (locked); the test proves it works (hash-locked).

If a bug investigation reveals you actually need new entities or new flows, you've found a feature-shaped problem. Switch playbooks.
