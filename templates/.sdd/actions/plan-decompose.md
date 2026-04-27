---
type: action
slug: plan-decompose
tag: AGENT-LED
title: "plan-decompose"
short_label: "Plan"
steps:
  - { id: tasks, action: convert_acs_to_ordered_tasks_one_test_file_per_task, field: "BUILD.tasks" }
bundling: n_a
used_by: [feature]
references: [acceptance-criteria, success, user-stories, ux-brief]
touches: []
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: false
---

Convert `acceptance-criteria` into ordered tasks. Each task = one test file + one commit. This is what BUILD will execute.

**Coverage check FIRST.** Before drafting any tasks, verify every constraint in `ux-brief` (mobile, accessibility, i18n, locale, dark mode, etc.) is reflected in ≥1 AC in §11. If gaps, propose new ACs in this same turn — surface ALL gaps in one go, don't drip them.

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

**End the turn with:** *"SPEC is now complete. Reply `approve` to advance to BUILD, or tell me what to reorder/split/merge."*
