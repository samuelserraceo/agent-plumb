---
type: action
slug: build-task
tag: BUILD-TASK
model_tier: routine
title: "Build a task"
short_label: "Task"
steps:
  - { id: test, action: "write the failing test for this task (RED required before code)", field: "tests/task-NNN.*" }
  - { id: code, action: "write the code that makes the new test pass (GREEN) without breaking other tests", field: "src" }
  - { id: green, action: "mark the task GREEN in spec.md and commit (one task = one commit)", field: "BUILD.task-N.status" }
used_by: [feature, bug, refactor]
references: [acceptance-criteria, plan-decompose]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 90
  max_tokens: 16000
  max_commits: 1
requires_user_approval: false
---

This action repeats once per task in `plan-decompose`. The default mode is **test-first (TDD)**. The alternative is BUILD-SPIKE — see the BUILD-SPIKE action; only use it for spike/exploration tasks the user has explicitly tagged.

**Non-negotiable order:**

1. The test file exists at the path named in the task line (e.g., `features/<id>/tests/task-001.mjs`). If the file doesn't exist yet, create it with the assertions the AC requires, then run it.
2. Run the test → must be **RED**. If the test passes BEFORE code is written, the test is wrong — rewrite it. (A test that's GREEN at the start tests nothing.)
3. Write code to make the test go GREEN.
4. Run the test → must be **GREEN**.
5. Commit. Update the task status from `RED` → `GREEN` in spec.md's plan-decompose section.
6. Move to the next task per the chosen run mode.

**Universal halt rules** (apply in every run mode):

- A test stays RED after 3 attempts at fixing the code → halt and ask the user. Don't spiral.
- A pre-commit hook blocks the commit → read the error, fix the actual blocker, do NOT work around with `--no-verify`.
- You discover a real design gap in `proposed-approach` or data-contract that needs a user decision → halt and ask.
- An infrastructure step needs credentials / keys / accounts the user hasn't set up → halt and ask.

**`touches:` is empty for this action.** Reason: file paths vary per task (T01 touches different files than T02). Theme 4's pre-commit-touches hook applies the empty-touches rule = "no enforcement"; per-task file-staging discipline is on the agent. Phase C can introduce template syntax (e.g., `{task-id}` placeholders) if needed.

**Per-task budget defaults:** 90 minutes / 16K tokens. Override per-task via the task's own line if a specific task is genuinely larger (e.g., a refactor task). Framework warns at budget breach; doesn't block.

**End the turn with one line:** `T<n> GREEN — <short phrase>` and either auto-continue (per run mode) or `Reply <go|stop|details>`.
