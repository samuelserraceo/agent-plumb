---
description: Advance the active SDD work item by one atomic step.
argument-hint: ""
---

# /sdd-next

Advance the active SDD work item by exactly one step. Resolve the current blocker via `bash .sdd/scripts/next-action.sh`, then ask, propose, or act per the action's tag (USER-LED / AGENT-LED / BUILD-TASK).

One `/sdd-next` = one atomic step = one commit. Never chain steps in a single turn. If the action is USER-LED, ask the user the question and wait. If AGENT-LED, draft 2-3 options and ask the user to pick. If BUILD-TASK, run the test → write code → run test GREEN → commit per the test-first rule.

Same loop as Claude Code's `/next`; the active blocker, action prose, and commit shape are read from the same `.sdd/` brain.
