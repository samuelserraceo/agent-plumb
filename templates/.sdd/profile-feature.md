---
type: profile
slug: profile-feature
profile_version: 0.8.0
---

# Profile: Feature

> Profile for shipping a new feature end-to-end. The 3-phase state machine
> (SPEC → BUILD → SHIP) consumes the v0.7 rubric content reorganised
> around three exit gates instead of five linear phases.
>
> PLAN's task decomposition is the `plan-decompose` sub-action at the end
> of SPEC. VERIFY's test run + sign-off and LEARN's summary + lessons all
> live as sub-actions inside SHIP.

<!--
HOW THIS PROFILE WORKS

- Every `/next` runs the inner loop: locate the active blocker → execute
  one sub-action → sync any declared writes → advance the pointer.

- `[ ]` marks an open question. The agent CANNOT advance the phase while
  any `[ ]` remains in that phase's sub-actions.

- Two interaction modes per sub-action:
  - [USER-LED]  → agent asks plain-English questions; user answers.
                  Agent does NOT fill from assumption.
  - [AGENT-LED] → agent PROPOSES with tradeoffs; user reviews, pushes
                  back, iterates until both agree.

- Commit after each sub-action.
- Phase transitions are gated by `verify-stage.sh` writing a
  `verification.json` whose (id, result) set is re-checked at commit time
  by the moat hook. Agent cannot commit a phase advance with a fabricated
  verification — see `pre-commit-stage-verified.sh`.
-->

---

## PHASE: SPEC

> Goal: define the feature precisely enough that BUILD becomes mechanical.
> Exit gate: every sub-action `[ ]` filled, plan-decompose produced ≥1
> task, `verification.json` says SPEC exit-checks pass.

### §1 Problem   [USER-LED]
_Ask: Who has this problem? Why now? What breaks if we don't solve it? Push for specifics — "users want this" is not enough; which users, doing what, when do they hit the wall?_

- **Who has it:** [ ]
- **Why now:** [ ]
- **What breaks without it:** [ ]

---

### §2 Success   [USER-LED, agent sharpens with multi-choice]
_Ask: How will we know this worked? Offer common metric patterns + free-form escape. Push for numbers — if the user says "it works well", ask what "well" looks like as a number._

_Common starting points to offer:_
- **Volume:** signups, orders, messages, transactions per day/week/month
- **Speed:** time to first action, response time, conversion rate
- **Quality:** NPS, error rate, support tickets, completion rate
- **Engagement:** DAU/WAU/MAU, retention curve, time in app
- **Or describe your own**

- **Verifiable outcomes:** [ ]

---

### §3 User stories   [USER-LED, agent structures with multi-choice]
_Ask: "As `<who>`, I want `<what>`, so that `<why>`"? Usually 2–5 stories. Agent keeps phrasing consistent._

_Common personas to offer (pick which apply, or describe your own):_
- **New visitor**, **Signed-up user**, **Returning customer**, **Admin / operator**, **Billing / finance**, **Customer support**, or describe your own.

For each persona the user picks, ask what they want to do and why.

- [ ]

---

### §4 UX & Design brief   [AGENT-LED]   [SKIPPABLE: non-UI features only — APIs, cron jobs, data migrations]
_Purpose: capture how the thing should look and feel BEFORE proposing tech (§5) or drawing the wireframe. Don't ask blank open-ended questions, propose concrete candidates with reasoning that references what §1-3 already told you._

_Run in this order:_

_**Step 1 — read context.** Re-read §1-§3. Extract every signal about audience, stakes, mood, screen context, voice. Write back what you've inferred in one paragraph._

_**Step 2 — ask only what's missing.** Identify the 1-3 smallest gaps before proposing. Ask only those._

_**Step 3 — propose candidates, not fields.** Give 2-3 concrete candidates per sub-item with one-line reasoning tied to §1-3._

- **Tone / feel:** [ ]
- **Reference sites / apps (3 candidates):** [ ]
  _Name, URL, what to borrow (layout, spacing, copy, colour, motion), why it maps. 1-2 to avoid with why._
- **Primary screen size & device posture:** [ ]
  _Mobile-first / desktop-first / split. Which one is "primary" — the one the agent must make perfect first._
- **Information density:** [ ]
- **Motion / interactivity:** [ ]
- **Accessibility floor:** [ ]
  _WCAG 2.1 AA minimum. Anything beyond? (Reduced motion, RTL, locale, low-bandwidth.)_

---

### §5 Proposed approach   [AGENT-LED]
_Agent proposes a concrete approach with reasoning, alternatives, and what's traded off. The user is non-technical — translate every technical choice into "what it does for the user" + "what could go wrong"._

- **Recommended approach:** [ ]
- **Alternatives considered (≥2):** [ ]
- **What we trade off:** [ ]
- **Key technical choices for sign-off:** [ ]
  _List each library / service / pattern that the user would need to be aware of (paying for, configuring, or whose limits matter)._

---

### §6 Data contract   [AGENT-LED]   [data-model.md must be staged with this section's commit]
_Agent proposes the schema impact. User confirms. Be ruthless — every entity, every field, every transition, every edge case. **Sync required:** `data-model.md` MUST be staged in the same commit as any change to this section._

- **Entities affected:** [ ]
- **New fields / migrations:** [ ]
- **Relations created or removed:** [ ]
- **Edge cases at the data layer:** [ ]

---

### §7 Flows   [AGENT-LED]
_The 1-3 user flows from open-page through done. Agent draws as numbered steps. Reference §3 user stories._

- **Flow 1 — `<name>`:** [ ]
- **Flow 2 — `<name>`:** [ ]
- **Flow 3 — `<name>`:** [ ]

---

### §8 Dependencies   [AGENT-LED]   [SKIPPABLE: feature uses nothing paid or external]

For each external service or paid dependency:

#### `<Service name>`
- **What it does for the user:** [ ]
  _Plain English. Not "transactional email API" — "sends the confirmation email when someone signs up."_
- **Pricing relevant to this feature:** [ ]
  _Show the math, scaled to expected volume (§2 Success)._
- **Setup needed from the user:** [ ]
- **What breaks if this is down:** [ ]
- **Total monthly cost (across all services):** [ ]

---

### §9 Out of scope   [USER-LED]
_What we're explicitly NOT doing this round. Useful for next-feature pull-requests later._

- [ ]

---

### §10 Non-functional   [AGENT-LED]   [SKIPPABLE: no perf / security / compliance concerns]
- **Performance budget:** [ ]
- **Security:** [ ]
- **Compliance:** [ ]

---

### §11 Acceptance criteria   [AGENT-LED, propose multi-choice when reviewing]
_Concrete, testable assertions. Each AC maps to one task in plan-decompose. Tag impossible-to-test-locally ACs as `[PROD-ONLY]`._

_Common test-type patterns to offer:_
- **Form / input** → submission produces X; invalid input returns Y
- **Session / state** → user state persists across reload, expires after T
- **Layout / responsive** → mobile viewport renders without horizontal scroll
- **Navigation** → link redirects to expected URL with expected params
- **Errors** → service-down state shows "please try again", logs the error
- **Or describe what to assert**

- [ ] AC1: ...
- [ ] AC2: ...

---

### §12 Human sign-off steps   [USER-LED, agent drafts checklist]
_The manual steps the user must take (separate from automated ACs) before SHIP. Often: "click around the prod URL", "ask one real user to sign up", "check the Slack channel got a message"._

- [ ]

---

### Wireframe   [SKIPPABLE: non-UI features — auto-skipped if §4 was skipped]
_Static HTML + Tailwind CDN, viewable in a browser. One file at `.sdd/features/<id>/wireframe.html`. Show every screen named in §3. Iterate with the user until they say "approved"._

- **Approved by user:** [ ]

---

### plan-decompose   [AGENT-LED]
_Final SPEC sub-action. Convert §11 ACs into ordered tasks. Each task has: `T<n>`, short title, exact test path, est. effort. Output as a checklist in this section. plan-decompose's exit-check counts ≥1 task as the gate to leaving SPEC._

- [ ] task list

---

### Exit checks
- [ ] C-spec-acs: §11 has ≥1 acceptance criterion — grep -q '\[ \] AC' "$SECTION_FILE"
- [ ] C-spec-tasks: plan-decompose produced ≥1 task — grep -Eq '\[ \] T[0-9]' "$SECTION_FILE"

---

### TRANSITION: SPEC → BUILD
_Run `verify-stage.sh <spec> SPEC`. If `verification.json` shows all SPEC exit-checks `pass`, the moat hook will allow the commit `[SDD:<id>] phase: SPEC → BUILD`. Stage spec.md + verification.json together._

---

## PHASE: BUILD

> Goal: implement every task GREEN, every test passing.
> Exit gate: every task is `[GREEN]`, `verification.json` says BUILD
> exit-checks pass.

### run-mode-chosen   [USER-LED, runs once at BUILD entry]
_How does the user want BUILD to run? (Universal halting rules apply regardless.) Pick one:_

1. **Step-by-step** — pause after every task GREEN, user replies `/next`.
2. **Checkpoint every 5 (recommended)** — auto-loop, pause every 5 tasks.
3. **Full autonomous** — only stop on universal halts.
4. **Shell Ralph (headless)** — run `./scripts/ralph.sh`, fresh Claude per task.

- **Run mode:** [ ]

---

### build-task   [BUILD-TASK | BUILD-SPIKE, repeats per task]
_Repeats once per task in plan-decompose. The default is BUILD-TASK (test-first):_

1. _Test file exists at the path named in the task line._
2. _Run test → must be RED. (If GREEN before code, the test is wrong — rewrite.)_
3. _Write code._
4. _Run test → must be GREEN._
5. _Commit `[SDD:<id>][T<n>] <message>` with both code and test staged._
6. _Update task line `[ ]` → `[GREEN]`._

_For exploratory tasks where TDD-first is the wrong abstraction (SQL spike, CSS gradient tweaking, third-party API stub), tag `BUILD-SPIKE` instead. The exit-check still requires both code and test staged together — order is reversed, gate is identical._

- [ ] T1 ...
- [ ] T2 ...

_Feature cannot advance to SHIP until every task is `[GREEN]`._

---

### Exit checks
- [ ] C-build-tasks-green: every task is GREEN — ! grep -Eq '\[ \] T[0-9]' "$SECTION_FILE"
- [ ] C-build-run-mode-set: run-mode-chosen has a value — grep -Eq '\*\*Run mode:\*\* (1|2|3|4|step|checkpoint|autonomous|ralph)' "$SECTION_FILE"

---

### TRANSITION: BUILD → SHIP
_When every task is `[GREEN]`, run `verify-stage.sh <spec> BUILD`. If verification.json shows all BUILD exit-checks pass, the moat hook allows the commit `[SDD:<id>] phase: BUILD → SHIP`._

---

## PHASE: SHIP

> Goal: prove it works in production and capture the lesson.
> Exit gate: tests green, prod-only ACs deferred or verified, lessons
> synced to patterns.md, INDEX.md updated, PR shipped.

### verify-test-run   [AGENT-LED]
_Run the full test suite. Surface failures immediately. Re-RED any AC that fails — kicks back to BUILD as a `[BUG]` task._

- **All ACs pass (excluding PROD-ONLY):** [ ]

---

### verify-prod-only-acs   [USER-LED]
_For every `[PROD-ONLY]` AC, the user walks through it manually after the first prod deploy. Each pass ticks the box. Failures return to BUILD as `[BUG]`._

- [ ]

---

### learn-summary   [AGENT-LED]
_One paragraph. What got built, why, what surprised you about the implementation._

- **Summary:** [ ]

---

### learn-lessons   [AGENT-LED, sync to patterns.md]
_What's the one (or two) cross-feature lesson worth keeping? Pattern, constraint, gotcha. **Sync required:** patterns.md MUST be staged with this commit._

- **Lesson 1:** [ ]
- **Lesson 2 (optional):** [ ]

---

### push-pr   [AGENT-LED]
_Push the branch, open the PR. Wait for CI green._

- **PR URL:** [ ]

---

### verify-ci-green   [AGENT-LED]
_CI must be green before mark-shipped fires. If RED, kicks back to BUILD as `[BUG]`._

- **CI green:** [ ]

---

### mark-shipped   [AGENT-LED, sync to INDEX.md]
_Move the feature from `## Active` to `## Shipped` in INDEX.md. Drop a `.shipped` marker in the feature folder. **Sync required:** INDEX.md MUST be staged with this commit._

- **Shipped:** [ ]

---

### Exit checks
- [ ] C-ship-tests-green: verify-test-run filled — grep -Eq 'All ACs pass.*\[(x|GREEN)' "$SECTION_FILE"
- [ ] C-ship-pr-url: PR URL present — grep -Eq 'PR URL:.*https?://' "$SECTION_FILE"
- [ ] C-ship-marked: mark-shipped filled — grep -Eq 'Shipped:.*\[(x|GREEN)' "$SECTION_FILE"

---

### TRANSITION: SHIP → done
_When mark-shipped is complete, the active pointer in INDEX.md clears (or moves to the next active feature). The feature folder is now cold — referenced, not read._

---

## Notes for the implementing agent

This profile is consumed by:

- **`next-action.sh`** — walks the active phase body, ignores `[ ]` inside ` ``` ` fences, returns first open marker (or transition signal if all filled).
- **`verify-stage.sh`** — extracts `### Exit checks` for the named phase, runs each `- [ ] <id>: <desc> — <bash cmd>` line with `$SECTION_FILE` set to the phase body. Writes verification.json sorted by id.
- **`pre-commit-stage-verified.sh`** — when verification.json is staged, re-runs verify-stage on the staged spec and compares (id, result) sets. Mismatch blocks the commit.

Translate technical choices to plain English at every USER-LED touchpoint. Especially in §5 Proposed approach and §8 Dependencies, the user must be able to react in 30 seconds without reading docs.
