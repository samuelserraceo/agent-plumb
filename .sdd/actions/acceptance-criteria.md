---
type: action
slug: acceptance-criteria
tag: AGENT-LED
prelude_refresh: true
title: "§11 Acceptance criteria"
short_label: "ACs"
steps:
  - { id: approval, action: "draft the acceptance criteria, run a constraint-coverage check vs §4, iterate, get approval", field: "§11", triggers: [section_approved] }
used_by: [feature]
references: [success, user-stories, flows, ux-brief, non-functional]
touches: [".sdd/<work-item>/spec.md", ".sdd/<work-item>/wireframe.html"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

**This is the central section the moat protects** (Codex finding #2). User-approved ACs are hash-locked; the agent cannot silently soften them later.

Each AC is a **concrete, testable assertion**. Each AC maps to **one task** in `plan-decompose` — what we promise to test, we promise to build.

**Anchor to context.** Base ACs on `flows`, `user-stories`, and (if not skipped) `ux-brief` constraints. Every UX constraint (mobile-first, accessibility floor, locale) needs ≥1 AC backing it.

**Multi-choice scaffold for test types** (and a free-form escape):

- **Form / input** → submission produces X; invalid input returns Y
- **Session / state** → user state persists across reload, expires after T
- **Layout / responsive** → mobile viewport renders without horizontal scroll
- **Navigation** → link redirects to expected URL with expected params
- **Errors** → service-down state shows "please try again", logs the error
- **Or describe what to assert**

**Coverage check before approval.** After drafting all ACs, scan `ux-brief` for constraints (mobile, dark mode, accessibility, i18n, locale, etc.). Each constraint MUST have ≥1 AC. If gaps, propose new ACs in this same turn — don't drip them out one by one.

**`[PROD-ONLY]` tag.** Some ACs can't be tested in dev (real Stripe charge, real email bounce webhook, real Turnstile token, real DNS propagation). Tag those `[PROD-ONLY]` at line end. SHIP's verify-prod-only-acs walks them manually post-deploy. Don't use `[PROD-ONLY]` to dodge writing tests — it's only for the impossible-in-dev cases.

**Format:**

```text
- [ ] AC1: New user signs up with valid email, inbox shows confirmation email → tests/task-001.mjs
- [ ] AC2: Empty submission returns 400 with error message → tests/task-002.mjs
- [ ] AC3: Mobile viewport (iPhone-13) renders without horizontal scroll → tests/task-003.mjs
- [ ] AC4: Turnstile rejects automated requests with invalid token → 400 [PROD-ONLY] → tests/task-004.mjs
```

4-8 ACs is typical. Fewer = scope too narrow; more = scope too broad.

**On approval (Theme 1.6 hook).** Hash recorded. Future edits to §11 require `/re-approve §11`.

**What it looks like:**

Let me write a checklist of every concrete thing that must work before we ship — in plain English, one bullet per check. Each bullet becomes one test we run.

Example: *"(1) Submitting the form with a valid email shows a 'check your inbox' message within 2 seconds. (2) Submitting with a bad email (no @) shows a clear error like 'that doesn't look like an email yet'. (3) Clicking the confirmation link signs you in and sends you to /welcome. (4) The confirmation link stops working after 24 hours."* You can add, remove, or reword each one before I lock the list.

**End the turn with:** *"Reply `approve` to lock the ACs (this section can't be silently softened after approval), or tell me what to add/remove/sharpen."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If this action's answer changes anything user-visible (a screen, a button, a flow, a page transition, a form field), **also update `wireframe.html`** in the same commit. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.

Mechanical enforcement (a state_rule that refuses spec commits without wireframe staging when wireframe.html exists) lands in v0.11 — see issue #45.
