---
description: Re-answer or edit a single /sdd-setup question without re-walking the whole wizard.
argument-hint: "<question-id> [new-value]"
---

# /sdd-config

Re-answer or edit a single SDD setup question. Use when the stack changes (new service, new reviewer, new hosting target) and you want to update one piece without re-running the full `/sdd-setup` wizard.

Run `bash .sdd/scripts/sdd-config.sh "$ARGUMENTS"`. Bare `/sdd-config` lists every question. `<question-id>` re-asks just that one. `<question-id> <value>` sets it directly. Same surface as Claude Code's `/sdd-config`.
