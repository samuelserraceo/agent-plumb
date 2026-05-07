---
type: action
slug: run-mode-chosen
tag: USER-LED
prelude_refresh: true
title: "Run mode chosen"
short_label: "Run mode"
steps:
  - { id: mode, prompt: "How do you want to run BUILD? 1=step-by-step, 2=checkpoint-every-5, 3=full autonomous, 4=Shell Ralph headless. Or adjust.", field: "**Run mode:**" }
used_by: [feature, bug, refactor]
references: [plan-decompose]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 1000
  max_commits: 1
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item name + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

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

**What it looks like:**

How do you want me to run the BUILD phase?

Pick one:
1. **One step at a time** — I do one task, show you the result, wait for `/next`. Best when you want to see every commit.
2. **Checkpoint every 5 steps** — I do 5 tasks in a row, then pause for a thumbs-up. Good middle-ground.
3. **Full autonomous** — I run all the way through to GREEN; you review at the end. Best when the work is mechanical.
4. **Headless / Shell Ralph** — you run the existing `./scripts/ralph.sh` in another terminal. Each task spawns a fresh Claude invocation, no token bloat. Best for 2+ hours unattended.

**End the turn with:** the user's choice + *"Starting BUILD in <mode>. Run `/next` to begin T01."*
