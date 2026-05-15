---
description: Capture a bug as a new SDD work item using the bug playbook.
argument-hint: "<one-line title for the bug>"
---

# /sdd-bug

Capture a bug as a new SDD work item. Equivalent to running `/sdd-start [BUG] <title>` — routes to the bug playbook instead of the feature playbook.

Run `bash .sdd/scripts/start.sh "[BUG] $ARGUMENTS"`. The bug playbook is a lighter SPEC than feature: 5 sections (problem, repro, root-cause, fix, regression-test) walked in a single ceremony.
