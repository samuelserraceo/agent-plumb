---
description: Ship the active SDD work item — push branch, open or update PR, watch CI.
argument-hint: ""
---

# /sdd-ship

Ship the active SDD work item. Push the branch, open or update the PR, poll CI, and either mark shipped on green or capture a bug on failure.

First find the active feature with `bash .sdd/scripts/resolve-active.sh` (parse the `active` field). Then walk the SHIP-phase actions one at a time via `bash .sdd/scripts/next-action.sh .sdd/<active>/spec.md` — each action lands as its own commit on the active branch. The terminal `mark-shipped` action writes the `.shipped` marker and updates `INDEX.md`'s Shipped section.

Same flow as Claude Code's `/ship` — the underlying scripts, hooks, and audit trail are reused unchanged from `.sdd/`.
