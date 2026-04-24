# Feature: <fill in short name>   [PHASE: SPEC]

> **Branch:** `sdd/<id>-<slug>`
> **Active blocker:** _(agent points this at the first unfilled `[ ]` in the current phase)_

<!--
HOW THIS FILE WORKS
- `[PHASE: X]` above is the state. Phases advance: SPEC → PLAN → BUILD → VERIFY → LEARN → SHIPPED.
- `[ ]` marks an open question. The agent CANNOT advance phase while any `[ ]` remains in the current phase's sections.
- Two interaction modes are declared per section:
  - [USER-LED]  → agent asks plain-English questions; user answers. Agent does NOT fill from assumption.
  - [AGENT-LED] → agent PROPOSES a concrete answer with tradeoffs; user reviews, pushes back, iterates until both agree. Captured text reflects the agreed answer, not the draft.
- When filling a `[ ]`, replace only the brackets. Keep the section headings and guidance.
- Commit after each section with `[SDD:<feature-id>] spec: <section name>`.
-->

---

## PHASE: SPEC

### 1. Problem   [USER-LED]
_Ask: Who has this problem? Why now? What breaks if we don't solve it? Push for specifics — "users want this" is not enough; which users, doing what, when do they hit the wall?_

- **Who has it:** [ ]
- **Why now:** [ ]
- **What breaks without it:** [ ]

---

### 2. Success   [USER-LED, agent sharpens]
_Ask: How will we know this worked? Push for measurable outcomes. If the user says "it works well", ask what "well" means in numbers, behavior, or feeling — and pin it down._

- **Verifiable outcomes:** [ ]

---

### 3. User stories   [USER-LED, agent structures]
_Ask: "As `<who>`, I want `<what>`, so that `<why>`"? Usually 2–5 stories. Agent keeps phrasing consistent._

- [ ]

---

### 4. Proposed approach   [AGENT-LED]
_Agent drafts a concrete solution. Must be plain English — no jargon without explaining it. Show tradeoffs and alternatives so the user can push back from a position of understanding, not blind trust. This is the non-technical user's biggest lever — do not skimp._

- **Recommended solution:** [ ]
  _What we'll build. Which pattern. Why this over other options. One paragraph._

- **Key technical choices:** [ ]
  _Framework / libraries / data store / auth / external services. For each: what it is, why we picked it, what it costs (money and lock-in)._

- **Alternatives considered:** [ ]
  _At least 2 options. What we gave up by choosing the recommended. Be honest._

- **Risks / unknowns:** [ ]
  _Things that could go wrong. Time/cost impact. What we're not sure about yet._

- **User's reaction / adjustments:** [ ]
  _What the user said during the discussion. The converged decision, not just the agent's draft._

---

### 5. Data contract   [AGENT-LED]
_Agent proposes the schema impact. User confirms. Be ruthless here — this is where prior workflows fell short. Every entity, every field, every transition, every edge case._

- **Entities used from `data-model.md`:** [ ]
  _List by name. If none exist yet, this feature defines the first ones._

- **New entities / fields:** [ ]
  _Exact diff that will be appended to `data-model.md`. Include name, type, constraints (NOT NULL, UNIQUE, default), foreign keys._

- **State transitions:** [ ]
  _If any entity has a status field, list every valid transition (e.g., `draft → pending → active`, `active → archived`). If no state, write "N/A"._

- **Edge cases:** [ ]
  _Nulls, uniqueness collisions, race conditions, migration concerns on existing data, timezone / locale / currency. Each one: what happens, what we do about it._

---

### 6. Flows   [AGENT-LED]
_Agent drafts user journeys step-by-step. User confirms or adjusts. Must include happy path + at least 3 edge cases._

- **Happy path:** [ ]
- **Edge 1:** [ ]
- **Edge 2:** [ ]
- **Edge 3:** [ ]

---

### 7. Dependencies   [AGENT-LED]
_Agent identifies external services / APIs / auth / third-party anything required. User confirms cost and availability are acceptable._

- **External APIs / auth / services:** [ ]
  _For each: name, purpose, cost per unit, rate limits, failure mode._

---

### 8. Out of scope   [USER-LED]
_Ask: What are we explicitly NOT doing in this feature? Makes future scope creep visible. Better to list 5 things here than have them silently creep in._

- [ ]

---

### 9. Non-functional   [AGENT-LED, skip if not relevant]
_Agent raises performance / security / accessibility / observability / compliance concerns relevant to this feature. User decides which are in-scope._

- [ ]

---

### 10. Acceptance criteria   [AGENT-LED]
_Agent derives from user stories (Section 3). Each criterion must be testable by agent-browser. Each maps to one test file in `features/<id>/tests/`._

- [ ] AC1: `<criterion>` → `tests/task-001.mjs`

---

### 11. Human sign-off steps   [USER-LED, agent drafts checklist]
_Ask: After automated tests pass, what will YOU test manually? These become a checklist in VERIFY. Keep it short — 3-5 steps usually._

- [ ]

---

### Wireframe
- **File:** `wireframe.html`
- **Status:** [ ] drafted / [ ] approved

_Agent generates a static HTML + Tailwind mockup for every screen in the user stories. User opens the file in a browser. User gives feedback in chat. Agent iterates until user says "approved". Then checks the `approved` box._

---

## PHASE: PLAN   _(populated only when all SPEC `[ ]` are filled)_

### Tasks
_One task per atomic commit. Each task references its acceptance criterion and test file. Order reflects dependencies._

- [ ] T1: `<task description>`   AC: AC1   test: `tests/task-001.mjs`   status: RED

---

## PHASE: BUILD   _(TDD, task-by-task)_

_The PLAN section's task statuses are the live build state. Each task:_

1. _Agent writes (or confirms exists) the test file named in `tests/`._
2. _Agent runs the test → must be **RED** (no code yet)._
3. _Agent writes the code._
4. _Agent runs the test → must be **GREEN**._
5. _Agent commits with `[SDD:<id>][T<n>] <msg>` and updates status to `GREEN` in the task line above._

_Feature cannot advance to VERIFY until every task is `GREEN`._

---

## PHASE: VERIFY

### Test run results
_Populated by `/verify`: output of agent-browser for every test in `features/<id>/tests/`. Any FAIL → phase flips back to BUILD with a `[ ] bug: <msg>` task added above._

- [ ]

### Human sign-off checklist
_Rendered from Section 11. User ticks each box after testing manually. Feature cannot ship until all ticked._

- [ ] (copied from Section 11)

---

## PHASE: LEARN

### What shipped
_One-paragraph summary. Gets appended to `current-state.md` (if used) or INDEX.md's shipped section._

- [ ]

### Lessons
_What surprised us. What to remember for future features. Gets merged (or linked) into `patterns.md`._

- [ ]

### PRs referenced
_`gh pr` URL, date, merge SHA._

- [ ]
