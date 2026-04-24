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

### 4. UX & Design brief   [USER-LED, agent asks one at a time]   [SKIPPABLE: non-UI features only — e.g. APIs, cron jobs, data migrations]
_Purpose: capture how the thing should look and feel BEFORE proposing tech or drawing the wireframe. The agent cannot invent taste — this is where your aesthetic preferences, brand constraints, and references go on record. Every downstream decision (tech choices, copy voice, wireframe polish) is informed by this._

_Ask each bullet in plain English, one at a time. Push past lazy answers — "clean" and "modern" are not answers; "like Linear's homepage but warmer" is._

- **Tone / feel:** [ ]
  _Pick 2-3 descriptors: minimal, professional, playful, bold, elegant, warm, technical, confident, editorial, luxe — or describe in your own words._

- **Reference sites / apps you love (1-3):** [ ]
  _Names + URLs or screenshots of products whose UI or vibe you want to match. "Linear", "Stripe checkout", "Notion marketing pages"._

- **References you want to AVOID (0-2):** [ ]
  _"Don't make it look like [X]." Helpful for bracketing taste._

- **Brand assets on hand:** [ ]
  _Logo / color palette / typeface already chosen? Starting fresh? If fresh, one-line brand idea so the agent can pick sensible defaults._

- **Primary screen size:** [ ]
  _Where will most users see this — mobile, desktop, or split?_

- **Copy voice:** [ ]
  _How should the words feel — formal, friendly, concise, witty, technical, warm? One-sentence example of a headline you'd personally write, if you have one._

- **Emotional goal:** [ ]
  _What should the user FEEL after using this feature? (confident, excited, reassured, in control, impressed, calm…) Guides microcopy, animation, pacing decisions later._

- **Accessibility intent beyond baseline:** [ ]
  _Default is WCAG 2.1 AA via §10. This is where you raise the bar — high-contrast audience, large-type, keyboard-only, screen-reader-first, low-bandwidth regions. Write "baseline only" if none apply._

---

### 5. Proposed approach   [AGENT-LED]
_Agent drafts a concrete solution. Must be plain English — no jargon without explaining it. Show tradeoffs and alternatives so the user can push back from a position of understanding, not blind trust. This is the non-technical user's biggest lever — do not skimp. Let §4 UX brief inform framework/library choices (e.g., "you picked 'warm + playful' so we'll use Framer Motion for small entrances rather than a heavier animation lib")._

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

### 6. Data contract   [AGENT-LED]
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

### 7. Flows   [AGENT-LED]
_Agent drafts user journeys step-by-step. User confirms or adjusts. Must include happy path + at least 3 edge cases._

- **Happy path:** [ ]
- **Edge 1:** [ ]
- **Edge 2:** [ ]
- **Edge 3:** [ ]

---

### 8. Dependencies   [AGENT-LED]   [SKIPPABLE: feature uses nothing paid or external]
_Purpose: list every **paid or risky** external service this feature relies on, so the user knows the ongoing cost, the setup work, and what happens when each one breaks. Skip built-in language or framework bits (e.g. Node DNS lookups, standard npm utilities) — only call out things the user would actually sign up for, pay for, or be woken up by._

_Format every entry in this exact shape so a non-technical reader can scan it:_

```
### <Service name>
- **What it is (one plain sentence, no jargon):**
- **What it does for this feature (in feature-specific terms, not generic):**
- **Cost at our scale — show the math:**     e.g. "200 signups × 2 emails = 400 emails/mo. Resend Free = 3,000/mo. $0."
- **What happens if it breaks (plain English user impact):**
- **What you (the user) need to do to set it up:**      e.g. "create an account at X, add DNS record, paste API key into env"
```

_Then end the section with a **Total monthly cost** line showing the sum and the math behind it. If there's a known spike month (launch, seasonal), show that separately. No hand-waving._

- **External APIs / auth / services:** [ ]

---

### 9. Out of scope   [USER-LED]
_Ask: What are we explicitly NOT doing in this feature? Makes future scope creep visible. Better to list 5 things here than have them silently creep in._

- [ ]

---

### 10. Non-functional   [AGENT-LED]   [SKIPPABLE: no perf / security / compliance concerns — rare]
_Agent raises performance / security / accessibility / observability / compliance concerns relevant to this feature. User decides which are in-scope. Apply the non-technical lens from CLAUDE.md: translate every technical term on first use, describe failures in user-impact language, show math for any threshold ("10 req/min/IP = blocks ≥170 rapid submits from a single IP in 17s")._

- [ ]

---

### 11. Acceptance criteria   [AGENT-LED]
_Agent derives from user stories (§3) and the UX brief (§4). Each criterion must be testable by agent-browser. Each maps to one test file in `features/<id>/tests/`._

- [ ] AC1: `<criterion>` → `tests/task-001.mjs`

---

### 12. Human sign-off steps   [USER-LED, agent drafts checklist]
_Ask: After automated tests pass, what will YOU test manually? These become a checklist in VERIFY. Keep it short — 3-5 steps usually._

- [ ]

---

### Wireframe   [SKIPPABLE: non-UI features — auto-skipped if §4 was skipped]
- **File:** `wireframe.html`
- **Status:** [ ] drafted / [ ] approved

_Agent generates a static HTML + Tailwind mockup for every screen in the user stories (§3), styled to match the UX brief (§4). User opens the file in a browser. User gives feedback in chat. Agent iterates until user says "approved". Then checks the `approved` box._

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
_Rendered from §12. User ticks each box after testing manually. Feature cannot ship until all ticked._

- [ ] (copied from §12)

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
