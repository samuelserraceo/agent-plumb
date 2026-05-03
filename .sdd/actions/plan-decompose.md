---
type: action
slug: plan-decompose
tag: AGENT-LED
title: "plan-decompose"
short_label: "Plan"
steps:
  - { id: tasks, action: "convert acceptance criteria into ordered build tasks (one test file per task)", field: "BUILD.tasks" }
used_by: [feature]
references: [acceptance-criteria, success, user-stories, ux-brief]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

Convert `acceptance-criteria` into ordered tasks. Each task = one test file + one commit. This is what BUILD will execute.

**Coverage check FIRST — and it's a TWO-STEP process when gaps exist.** Before drafting any tasks, verify every constraint in `ux-brief` (mobile, accessibility, i18n, locale, dark mode, etc.) is reflected in ≥1 AC in §11. Surface ALL gaps in one go, don't drip them.

**§11 is section-locked** (`requires_user_approval: true`) — its content is hashed at approval time and the moat refuses any commit that diverges from the hash. So you can't silently add new ACs; that would break section-locking. Split the work into two atomic steps:

1. **(a) If new ACs are needed:** propose them, the user approves them via natural conversation, then re-approve §11 via the inline `/re-approve` flow in `/next.md` (a v0.9 doctrine — the inline re-approval handler appends the new ACs, re-runs `hash-section`, updates the §11 hash in `verification.json`, and lands a re-approval entry in `decisions.md`). Only after §11 is re-approved with the new ACs does the next step start.
2. **(b) THEN, in a follow-up step:** write the task list against the now-complete §11.

If §11 already covers every §4 constraint, skip step (a) and go straight to step (b).

**Map ACs → tasks 1:1.** T1 → AC1, T2 → AC2, etc. Order matters: dependencies first (e.g., schema migration before form), then features.

**Format:**
```
- [ ] T01: User form submission and email dispatch
  Test path: features/<id>/tests/task-001.mjs
  Effort: S
- [ ] T02: Email confirmation link validation
  Test path: features/<id>/tests/task-002.mjs
  Effort: XS
```

**Effort estimates** (be honest):
- **XS** — < 30 min · **S** — 30 min - 2h · **M** — 2-6h · **L** — 6-16h · **XL** — 16h+

If multiple tasks cluster as L or XL, split them. *"Implement the entire payment flow"* → split into *"Stripe form"*, *"token validation"*, *"transaction record"*, *"receipt email"*.

**Validation:** ≥1 task required (exit-check `C-spec-tasks`). If 0 tasks, the feature is too thin or ACs are too vague.

**Output:** fill `spec.md` under `### plan-decompose` with the task list.

**What it looks like:**

Now I'll turn the checklist (acceptance criteria) into a concrete to-do list of build steps. Each step = one test + the code to make it pass + one commit.

Example: *"T01 — write the signup form's HTML; T02 — submit form posts to /api/signup; T03 — invalid emails return a clear error; T04 — valid emails create a row in the database; T05 — confirmation email gets sent within 5 sec; ..."* You see the whole list before I start, and you pick the **run mode** (do you want to eye-check each step, or let me run all the way through?).

**End the turn with:** *"SPEC is now complete. Reply `looks good` to advance to BUILD, or tell me what to reorder/split/merge. Then run `/next` to continue."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If this action's answer changes anything user-visible (a screen, a button, a flow, a page transition, a form field), **also update `wireframe.html`** in the same commit. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.

Mechanical enforcement (a state_rule that refuses spec commits without wireframe staging when wireframe.html exists) lands in v0.11 — see issue #45.
