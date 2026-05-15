---
description: Skip a [SKIPPABLE] action in the active SDD work item with a one-line reason.
argument-hint: "<reason for skipping>"
---

# /sdd-skip

Mark a `[SKIPPABLE]` action as deliberately skipped. Pass a one-line plain-English reason as the argument — the framework refuses to skip without one.

Skips are handled inline by `/sdd-next` in the standard SDD workflow. Use `/sdd-skip` only when the user explicitly wants to skip the current step before /sdd-next has surfaced it. The reason is recorded in spec.md and `decisions.md` as the audit trail.
