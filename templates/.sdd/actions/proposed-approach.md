---
type: action
slug: proposed-approach
tag: AGENT-LED
title: "§5 Proposed approach"
short_label: "Approach"
steps:
  - { id: approval, action: draft_iterate_approve_with_2_alternatives_and_tradeoffs, field: "§5", triggers: [section_approved] }
used_by: [feature]
references: [problem, success, user-stories, ux-brief]
touches: []
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

Propose a concrete approach with reasoning, alternatives, and what's traded off. The user is non-technical — translate every technical choice into "what it does for the user" + "what could go wrong."

**Required output (fill in spec.md):**
- **Recommended approach** — one paragraph plus a short bulleted list of the moving parts. Reference `problem`, `success`, `user-stories`, `ux-brief` explicitly so it's clear this approach answers them.
- **Alternatives considered (≥2)** — for each, one line on what it is and one line on why it's not the recommendation. Don't strawman — the alternative should be a real plausible choice.
- **What we trade off** — be honest about cost, complexity, time-to-ship, debt. Plain English.
- **Key technical choices for sign-off** — list each library / service / pattern the user needs to be aware of (paying for, configuring, or whose limits matter). One short paragraph each: what it does for the user, what it costs, what could go wrong.

**Iteration discipline.** This is AGENT-LED — propose first, then iterate with the user. Common feedback: "simpler", "swap X for Y", "show me what could go wrong with Z." Update the spec section, ask again until the user types **approve**.

**On approval.** The framework hashes the §5 section content and writes the hash to `verification.json.approved_sections.proposed-approach`. After approval, edits to §5 require running `/re-approve §5` — the moat hook blocks phase advance if the section content changed without re-approval. (Approved-section hashes are how the moat detects post-approval edits.)

**End the turn with:** *"Reply `approve` if this works, or tell me what to change (e.g. 'simpler', 'use Postgres instead of SQLite', 'explain the rate-limit risk in plain English')."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If this action's answer changes anything user-visible (a screen, a button, a flow, a page transition, a form field), **also update `wireframe.html`** in the same commit. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.

Mechanical enforcement (a state_rule that refuses spec commits without wireframe staging when wireframe.html exists) lands in v0.11 — see issue #45.
