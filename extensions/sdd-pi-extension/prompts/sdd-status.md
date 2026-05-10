---
description: Print the current SDD workflow state — phase, blocker, suggested next action.
argument-hint: ""
---

# /sdd-status

Print the current SDD workflow state. This is registered as an instant zero-LLM command via `pi.registerCommand` (no model round-trip), so it returns immediately.

Implementation lives in the extension's `pi.registerCommand("sdd-status", …)` handler — it shells out to `bash .sdd/scripts/status.sh` and prints the result verbatim. If no SDD project is found, it falls back to `"no SDD project found — run /sdd-start to initialise"`.
