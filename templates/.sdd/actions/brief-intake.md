---
type: action
slug: brief-intake
tag: USER-LED
model_tier: routine
prelude_refresh: true
title: "§0 Brief intake"
short_label: "Brief"
steps:
  - { id: brief, prompt: "Paste your brief, upload a doc, or use the template at .sdd/ideas/2026-05-08-brief-template-v2.md", field: "§0.brief" }
used_by: [feature]
references: []
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 15
  max_tokens: 6000
  max_commits: 1
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier — for first-action-of-a-new-work-item flows like this one, use the skeleton's "§1 not yet written" fallback since the brief IS what fills §1), **Today's question (§0 brief-intake)** (paste a brief OR upload a doc OR use the template), **Why now** (the brief lets us pre-fill §1, §3, §6, §7, §8, §10 — saves 15+ follow-up questions).
>
> **§173/§174 — Grill the user's answer.** AFTER the user pastes the brief, BEFORE writing it into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md) — but adapted for brief intake: grill on vague terms in §1.who-has-it / §1.why-now / hidden assumptions in §11 ACs / under-specification in §6 entities. Cap at 3 questions max.

# Brief intake (replaces §1 problem for new features)

Ask the user to paste a brief, upload a document, or use the v2 template at `.sdd/ideas/2026-05-08-brief-template-v2.md`. Then:

1. Read the brief carefully.
2. Apply [`brief-summarise.md`](../skeletons/brief-summarise.md) to emit a 3-bullet recap of what you understood.
3. Wait for user confirmation (or amendment).
4. Pre-fill spec.md sections from the brief content:
   - **§1 problem** — `who-has-it`, `why-now`, `what-breaks` (from brief #1 + #2 + #3)
   - **§3 user-stories** — derive personas (from brief #3 + #4)
   - **§6 data-contract** — entities mentioned (from brief #1 + #6 + uploaded docs)
   - **§7 flows** — critical user flows (from brief #4 + #5)
   - **§8 dependencies** — external services (from brief #11 + #12)
   - **§10 non-functional** — perf/security/compliance constraints (from brief #11 + #13)
5. Leave §11 ACs, §12 sign-off, §14 plan-decompose as placeholders — those need the standard ceremony.
6. Surface 3-5 follow-up USER-LED questions for what the brief DIDN'T cover (typically: tone in §4, edge cases in §15, prod-only ACs in §11).

**Backward compat:** if the user is on an EXISTING in-flight feature (started before this action shipped), the standard `problem` action runs instead. Detection: check `.sdd/INDEX.md` `## In flight` for the active feature; if it pre-dates this brick, use `problem` not `brief-intake`.

**Engineer opt-out:** if the user replies "use 3-question shape" or "skip brief", fall back to the existing `problem` action.

**What it looks like:**

> **Where we are:** `<feature-id>` — *(§1 not yet written; brief intake is the first action)*
>
> **Today's question (§0 brief-intake):** Paste your brief, or upload a document, or just use the template at `.sdd/ideas/2026-05-08-brief-template-v2.md`. The framework reads it once, summarises what it understood, and pre-fills sections §1, §3, §6, §7, §8, §10 — so you only answer 3-5 follow-up questions instead of ~20.
>
> **Why now:** anchors every later section. The brief is the canonical statement of intent; §1-§12 reference its content.
>
> Reply with your brief, or `use 3-question shape` to opt into the old Pitch flow.

**Output:** fill `spec.md` under `### action: brief-intake` with the brief verbatim (or a paraphrase if it's >2000 tokens) + the brief-summarise recap + the pre-filled section content.

**End the turn with:** *"Brief recorded. Run `/next` to walk the 3-5 follow-up questions for what the brief didn't cover."*
