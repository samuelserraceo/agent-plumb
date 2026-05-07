---
type: action
slug: bug-regression-test
tag: AGENT-LED
prelude_refresh: true
title: "§5 Regression test"
short_label: "Regression test"
steps:
  - { id: approval, action: "draft a test that fails before the fix and passes after, get user approval", field: "§5", triggers: [section_approved] }
used_by: [bug]
references: [bug-repro, bug-root-cause, bug-fix]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 20
  max_tokens: 5000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Draft the regression test that turns "the bug is fixed" from a vibe-check into a mechanical guarantee. The test must fail on the broken code and pass on the fixed code — that's how we know the fix actually worked, and that's how we catch the bug if it ever regresses.

**Required output (fill §5):**

- **Test name + path** — `tests/bug-<id>-<short-name>.<ext>` (matches the project's test runner convention from `stack.md`). One file per bug.
- **What the test asserts** — in plain English, before any code. *"After signing up with magic-link and clicking the confirmation email, the user lands on `/dashboard`, not on `/error?reason=session-not-found`."*
- **Test type** — unit / integration / end-to-end. Match the level the bug actually lives at:
  - Unit: a single function returns the wrong value → unit test
  - Integration: components interact incorrectly → integration test
  - E2E: a user-visible flow breaks → Playwright / Cypress / equivalent
- **The RED proof** — confirm the test runs RED on the unfixed code. (BUILD will run this for real; here we confirm the test SHAPE is right.)

**Push for the smallest test.** Bug regression tests should be **focused** — one test per bug, asserting only the specific symptom. Don't expand into "while we're here, let's also test X" — that's a feature-test concern, not a regression concern.

**Don't propose a test that catches the cause but not the symptom.** A regression test that asserts "the auth callback awaits the user-creation Promise" is brittle (anyone refactoring that code path triggers a false positive). A regression test that asserts "after magic-link click, user lands on /dashboard" survives the refactor and still catches the original bug. **Test the symptom, not the cause.**

**On approval.** Hashed into `verification.json.approved_sections.bug-regression-test`. Moat refuses commits if §5 content drifts post-approval — guards against the test being weakened during BUILD ("oh, this assertion is failing for an unrelated reason, let me just remove it").

**What it looks like:**

Now I write a test that proves this exact bug stays fixed forever.

Example: *"`tests/regression-bug-NNN.spec.ts` — submits the form with `not-an-email`, asserts response is 400 (not 503), asserts the error message contains 'please use a valid email'. Runs on every PR going forward — if anyone reverts the fix, CI catches it the same hour."*

**End the turn with:** *"Reply `approve` to lock the regression test. Then `/next` to advance to BUILD — the agent will run the test (RED), apply the §4 fix, and confirm GREEN."*
