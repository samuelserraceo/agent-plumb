---
type: action
slug: verify-ci-green
tag: AGENT-LED
model_tier: mechanical
title: "verify-ci-green"
short_label: "CI green"
steps:
  - { id: poll-ci, action: "poll PR CI until green; if red, open a bug", field: "§verify-ci-green" }
used_by: [feature, bug, refactor]
references: [push-pr]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 15
  max_tokens: 1000
  max_commits: 1
requires_user_approval: false
---

Poll the PR's CI status until it resolves green or red.

**Action:** `gh pr checks <pr-number> --watch` (or equivalent). Wait up to ~5-10 min for CI to complete.

**If GREEN:** tick the `**CI green:** [x]` box in spec.md and continue.

**If RED:**
- Pull the failing job's logs (`gh run view --log-failed`)
- Identify which check failed (test? lint? type-check? deploy?)
- Show the user the relevant error excerpt (head, not full logs — keep it under 20 lines)
- HALT and ask: *"CI failed on `<check>`. Want me to open a `[BUG]` task in plan-decompose, or do you want to investigate first?"*

**If CI takes >10 min:** ask the user — either wait, or pause and pick up when it's done.

**Output:** fill `spec.md` under `### verify-ci-green` with `**CI green:** [x]`.

**What it looks like:**

Watch CI on the PR and only proceed once every check is green.

Example: *"Checks running on the PR: (1) Framework tests, (2) Graph integrity (wiki-links resolve), (3) Scope guard (UI copy + spec refs), (4) CodeRabbit review. I tail them; if any goes red, I show you exactly which assertion failed and we fix on the branch."*

**End the turn with:** `CI green.` (or BUG details if RED). On GREEN: *"Run `/next` to mark shipped."*
