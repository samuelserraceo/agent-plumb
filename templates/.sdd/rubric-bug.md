# Feature: <bug short name>   [TYPE: BUG]   [PHASE: SPEC]

> **Branch:** `sdd/<id>-bug-<slug>`
> **Active blocker:** _(agent points this at the first unfilled `[ ]` in the current phase)_

<!--
HOW THIS FILE WORKS (BUG variant)
- Bugs use a SHORTER rubric than features. Skipped sections from the feature rubric:
  §4 UX, §5 Proposed approach, §7 Flows, §8 Dependencies, §9 Out of scope, §10 Non-functional, Wireframe.
  Reasoning: a bug fix has known surface area — it's not new functionality, just broken existing behaviour.
- Phases: SPEC → BUILD → VERIFY → LEARN. PLAN is skipped — a bug fix is one task by definition.
- If during SPEC you discover the "bug" actually requires a redesign (multiple data-model changes, new flows),
  STOP and propose escalating to a full feature via `/promote-bug-to-feature <id>`.
- Commit prefix on this branch: `[SDD:<id>-bug-<slug>] ...`
-->

---

## PHASE: SPEC

### 1. Problem (with reproduction)   [USER-LED]
_What's broken? Push for an exact reproduction the agent can run._

- **What goes wrong (one sentence):** [ ]
- **Steps to reproduce:** [ ]
- **Actual behaviour:** [ ]
- **Expected behaviour:** [ ]
- **Discovered when / by whom:** [ ]

---

### 2. Affected feature(s)   [USER-LED, agent confirms by reading]
_Which shipped or in-flight feature(s) does this bug live in? Cross-reference INDEX.md and shipped folders if user is unsure._

- **Primary feature:** [ ]
- **Other features touched (if any):** [ ]

---

### 3. Root cause   [AGENT-LED]
_Agent diagnoses by reading the affected feature's code and spec. Propose the root cause in plain English. User confirms or pushes back._

- **Root cause hypothesis:** [ ]
- **Evidence (file paths, log snippets, test output):** [ ]
- **Why we missed it the first time:** [ ]   _(important — this drives a §11 fix to prevent the class)_

---

### 4. Fix approach   [AGENT-LED]
_Small surgical change OR redesign? If it's redesign, escalate to feature instead._

- **Proposed change:** [ ]   _(file paths + summary of edits)_
- **Size signal:** [ ] small (< 50 lines, no schema change) / medium (one entity / one new helper) / large (escalate)
- **Risk:** [ ]   _(could this break anything else? what tests guard against that?)_

---

### 5. Data contract impact   [AGENT-LED]   [SKIPPABLE: bug doesn't touch schema]
_Most bugs don't touch the schema. If this one does, treat it like a feature's §6: list entity diffs to apply to `data-model.md`._

- **Entities affected (if any):** [ ]
- **Schema diff to apply:** [ ]

---

### 6. Acceptance criteria — regression test   [AGENT-LED]
_Every bug fix MUST add at least one test that fails before the fix and passes after. This stops the bug coming back._

- [ ] AC1: `<plain-English description of what the test asserts>` → `tests/<bug-id>.mjs`

---

### 7. Human sign-off   [USER-LED, agent drafts checklist]
_What will YOU manually verify after the fix lands?_

- [ ]

---

## PHASE: BUILD   _(TDD, single task)_

**Run mode:** _(usually "step-by-step" for bugs since there's only one fix — set at phase entry)_

A bug fix in BUILD is exactly one task:

1. Write the regression test from §6 — must FAIL on current code (proves the bug exists).
2. Write the fix (the §4 proposed change).
3. Run the test — must PASS.
4. Run the FULL feature suite for the affected feature(s) — must STILL pass (no regression).
5. Commit `[SDD:<id>-bug-<slug>] fix: <one-line summary>`.

If steps 3 or 4 don't pass after 3 attempts, STOP and ask the user. The diagnosis from §3 is probably wrong.

---

## PHASE: VERIFY

### Test run results
_All tests for the affected feature(s) — including the new regression — must be GREEN._

- [ ]

### Human sign-off checklist
_Rendered from §7. User ticks each box after verifying manually._

- [ ] (copied from §7)

---

## PHASE: LEARN

### What was broken and what fixed it
_One paragraph plain English. Distilled to a one-liner in INDEX.md `## Shipped`._

- [ ]

### Why we missed it (and what we're doing about it)
_The interesting question. If the answer is "the rubric didn't ask about this case", propose a rubric improvement. If "no test covered it", that's now §6 above. If "we deferred it knowingly", note the new condition that justified shipping anyway._

- [ ]   _(append to `patterns.md` under "Known pitfalls / lessons learned")_

### PR referenced
- [ ]
