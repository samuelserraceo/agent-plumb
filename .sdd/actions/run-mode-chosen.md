---
type: action
slug: run-mode-chosen
tag: USER-LED
title: "Run mode chosen"
short_label: "Run mode"
steps:
  - { id: mode, prompt: "How do you want to run BUILD? 1=step-by-step, 2=checkpoint-every-5, 3=full autonomous, 4=Shell Ralph headless. Or adjust.", field: "**Run mode:**" }
used_by: [feature]
references: [plan-decompose]
touches: []
trust: framework
budget:
  max_minutes: 5
  max_tokens: 1000
  max_commits: 1
requires_user_approval: false
---

Fires once at BUILD entry. Sets the pace for the rest of BUILD.

Ask the user (verbatim text — keep options consistent):

> Before we start BUILD, how do you want to run it? (Universal halting rules always apply — these options just control pace.)
>
> 1. **Step-by-step (conversation mode)** — I pause after every task GREEN, you reply `/next`. Best for learning or high-risk tasks.
> 2. **Checkpoint every 5 (recommended)** — I auto-loop, pause every 5 tasks for review. You reply `go`.
> 3. **Full autonomous (conversation)** — I only stop on universal halting rules. Best for 30-60 min unattended.
> 4. **Shell Ralph (headless)** — you run `./scripts/ralph.sh` in a terminal. Each task is a fresh Claude invocation, no token bloat. Best for 2+ hours unattended.
>
> Reply `1`, `2`, `3`, or `4`. Or adjust (e.g. *"checkpoint every 3"*).

**If user picks 4 (Ralph):** tell them *"Run `cd <project-root> && ./scripts/ralph.sh` now. I'll end my turn — Ralph drives from here."* Then stop. Don't execute tasks yourself.

**Output:** record chosen mode in `spec.md` as `**Run mode:** <chosen>` line.

**Universal halting rules** (apply in every mode):
- Test stays RED after 3 fix attempts → halt
- Pre-commit hook blocks → fix the underlying cause, don't `--no-verify`
- §5 or §6 reveals a real design gap → halt
- Need credentials/keys/accounts the user hasn't provided → halt

**End the turn with:** the user's choice + *"Starting BUILD in <mode>. Run `/next` to begin T01."*
