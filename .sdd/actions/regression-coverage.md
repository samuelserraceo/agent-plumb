---
type: action
slug: regression-coverage
tag: AGENT-LED
model_tier: routine
prelude_refresh: true
title: "§2 Regression coverage"
short_label: "Regression coverage"
steps:
  - { id: existing, action: "list every existing test that covers the §1 scope's behaviour", field: "§2.existing" }
  - { id: new-tests, action: "draft any new T-tests for shared-shape behaviour the existing tests don't already cover", field: "§2.new-tests" }
used_by: [refactor]
references: [refactor-scope]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 6000
  max_commits: 2
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list, binary yes/no). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

Before changing the code's shape, prove the behaviour it has today is captured by tests. The refactor is safe if and only if those tests still pass after.

This action has TWO steps (TWO commits):
- §2.existing — what we already have
- §2.new-tests — what we need to add to cover the shape we're extracting

---

## Part 1 — Existing tests (`existing` step)

Walk every file in §1's scope. For each, list the tests that already exercise it. Look at:

- Per-feature `tests/` folders for spec-driven tests
- The framework-wide test runner (`test/run-framework-test.sh` in this repo)
- MCP / extension tests if the scope touches those

**Output format:**

```text
- tests/path/to/test_X.py — covers <one-line behaviour>
- test/run-framework-test.sh:T42 — covers <one-line behaviour>
- ⚠️ no test covers <specific behaviour> — gap; new test needed (capture in §2.new-tests below)
```

**Be honest about gaps.** If a behaviour the refactor will preserve has NO existing test coverage, mark it as a gap. The next step closes those gaps.

**End the turn with:** *"Existing coverage drafted. Reply `looks good` or correct gaps, then `/next` to draft new tests for any shared-shape behaviour."*

---

## Part 2 — New T-tests (`new-tests` step)

For each gap identified in Part 1, draft a new test that covers the behaviour. These tests must:

1. **Pass on the current code** (no refactor done yet).
2. **Continue to pass after the refactor** (the new shape must preserve the behaviour).
3. **Be at the right granularity** — unit if the scope is one function, integration if multiple components, T-test in `test/run-framework-test.sh` if it's framework-wide.

**Output format:**

```markdown
### New test: <test-name>
**Path:** tests/refactors/<id>/test-<name>.<ext>
**What it asserts:** <one-line plain-English assertion>
**Why it's needed:** <which §1 behaviour it covers that wasn't already tested>
**Granularity:** unit / integration / T-test
```

**If §1's scope already has full coverage**, this step is short: *"All §1 behaviour is covered by existing tests; no new tests needed."* — that's a valid output. Don't manufacture tests just to fill the section.

**What it looks like:**

I'll list (Part 1) every existing test that already covers the refactor's scope, then (Part 2) draft any NEW tests needed to fill gaps.

Example for §2.new-tests: *"Part 1 turned up a gap — there's no existing test that asserts the validate-email helper rejects empty strings. I'll add `tests/refactors/004-auth-split/test-validate-email-empty.spec.ts` that calls `validateEmail('')` and asserts it returns `{ok:false, reason:'empty'}`. Run with `npx playwright test tests/refactors/004-auth-split/`. The test passes on the current code AND must still pass after the refactor — that proves the refactor preserves the behaviour."* Targeted gap-fillers, not a full-suite rerun. (Full-suite reruns happen later, in `verify-test-run` and `regression-coverage`'s own §1 listing.)

**End the turn with:** *"Reply `approve` to lock the regression coverage, or tell me what's missing. Then `/next` to draft the approach in §3."*
