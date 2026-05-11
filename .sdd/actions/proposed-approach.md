---
type: action
slug: proposed-approach
tag: AGENT-LED
model_tier: thinking
prelude_refresh: true
title: "§5 Proposed approach"
short_label: "Approach"
steps:
  - { id: approval, action: "draft the approach with 2 alternatives and tradeoffs, iterate with the user, get approval", field: "§5", triggers: [section_approved] }
used_by: [feature]
references: [problem, success, user-stories, ux-brief]
touches: [".sdd/<work-item>/spec.md", ".sdd/<work-item>/wireframe.html"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list, binary yes/no). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

Propose a concrete approach with reasoning, alternatives, and what's traded off. The user is non-technical — translate every technical choice into "what it does for the user" + "what could go wrong."

**Required output (fill in spec.md):**
- **Recommended approach** — one paragraph plus a short bulleted list of the moving parts. Reference `problem`, `success`, `user-stories`, `ux-brief` explicitly so it's clear this approach answers them.
- **Alternatives considered (≥2)** — for each, one line on what it is and one line on why it's not the recommendation. Don't strawman — the alternative should be a real plausible choice.
- **What we trade off** — be honest about cost, complexity, time-to-ship, debt. Plain English.
- **Key technical choices for sign-off** — list each library / service / pattern the user needs to be aware of (paying for, configuring, or whose limits matter). One short paragraph each: what it does for the user, what it costs, what could go wrong.

**Link to past decisions.** If this approach reuses a recipe the team has already settled on (e.g. "we already decided how to retry failed logins"), name that recipe with a `[[pattern:recipe-name]]` link in the prose — like a footnote. The framework checks the link points to a real recipe in `.sdd/patterns.md`; if it does, anyone reading later can click straight to it. Don't make links up — only link to recipes that already exist. If you're proposing a *new* recipe, just describe it in plain English here; the link gets added later (at `learn` time) when the recipe is written down.

**How we iterate.** This step is agent-led — I draft an approach, you push back, I redraft. Common pushbacks: "make it simpler", "swap X for Y", "what could go wrong with Z?". I update this section, ask again, repeat until you reply `approve`.

**What happens when you `approve`.** The framework takes a fingerprint (a short hash) of this section's text and remembers it. If anyone later edits §5 — you, me, a future session — the framework spots the change at the next phase advance and walks you through a quick "review the diff, reply `approve`" flow to confirm the new content. This is the section-lock that keeps the spec honest: once you've signed off, the text can't quietly change underneath you.

**What it looks like:**

Here's how I think we should build this — but I want to walk you through it before you commit.

I'll show you **2 or 3 different ways** we could do it (e.g. "use the email tool we already have" vs "sign up for a new one" vs "do it ourselves"), with the trade-offs of each in plain English ("option A is faster to ship but costs more per email; option B saves money but takes a week longer").

Then I'll recommend one and you say `looks good` or tell me what to change.

<details>
<summary>Show technical detail (architecture diagram, libraries, version pins)</summary>

Plain-English-first is the v1.6 default (closes #207 Part 4). When you DO want the engineer-shape draft — actual library names, version pins, architecture diagrams, code-shape sketches — that lives behind this foldable. The agent emits the foldable by default; you click to expand.

Example expansion (the agent fills this in for your specific feature):

```text
Stack: Next.js 15 (App Router) + Postgres 16 + Resend 4.x.
Recommended approach: server-action POST → email-validate → Resend send.
Alternatives: SendGrid (more expensive), AWS SES (more setup).
Risks: rate-limit at Resend's 3000/mo Free tier; mitigation: queue + retry.
```

Plain-English-first for non-technical readers; technical detail one click away for when you want it.

</details>

**End the turn with:** *"Reply `approve` if this works, or tell me what to change (e.g. 'simpler', 'use Postgres instead of SQLite', 'explain the rate-limit risk in plain English')."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If this action's answer changes anything user-visible (a screen, a button, a flow, a page transition, a form field), **also update `wireframe.html`** in the same commit. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.

Mechanical enforcement (a state_rule that refuses spec commits without wireframe staging when wireframe.html exists) lands in v0.11 — see issue #45.
