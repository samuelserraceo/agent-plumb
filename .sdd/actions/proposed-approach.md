---
type: action
slug: proposed-approach
tag: AGENT-LED
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

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item name + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Propose a concrete approach with reasoning, alternatives, and what's traded off. The user is non-technical — translate every technical choice into "what it does for the user" + "what could go wrong."

**Required output (fill in spec.md):**
- **Recommended approach** — one paragraph plus a short bulleted list of the moving parts. Reference `problem`, `success`, `user-stories`, `ux-brief` explicitly so it's clear this approach answers them.
- **Alternatives considered (≥2)** — for each, one line on what it is and one line on why it's not the recommendation. Don't strawman — the alternative should be a real plausible choice.
- **What we trade off** — be honest about cost, complexity, time-to-ship, debt. Plain English.
- **Key technical choices for sign-off** — list each library / service / pattern the user needs to be aware of (paying for, configuring, or whose limits matter). One short paragraph each: what it does for the user, what it costs, what could go wrong.

**Wiki-link emission (v1.0 graph layer).** When the recommended approach reuses a known pattern from `.sdd/patterns.md` (e.g., the team has already chosen "auth-retry-logic"), name the pattern with a wiki-link in §5 prose: `[[pattern:auth-retry-logic]]`. The framework's stop-hook (invariant 8) verifies the link resolves; the MCP server's `get_backlinks` query lets future sessions see which features cite the pattern. Don't invent links — only emit them for patterns that already exist in `patterns.md`. If you propose a *new* pattern that doesn't exist yet, prose-only is fine; the link gets added at `learn` time when the pattern lands in `patterns.md`.

**Iteration discipline.** This is AGENT-LED — propose first, then iterate with the user. Common feedback: "simpler", "swap X for Y", "show me what could go wrong with Z." Update the spec section, ask again until the user types **approve**.

**On approval.** The framework hashes the §5 section content and writes the hash to `verification.json.approved_sections.proposed-approach`. After approval, edits to §5 are caught by the moat at phase-advance time (`"section §<slug> CHANGED since you approved it"`); `/next` then walks the user through inline re-approval — review the diff, reply `approve` to re-lock the new content. The earlier `/re-approve <slug>` slash command was retired in v0.9; the inline flow lives in `.claude/commands/next.md` (search "Re-approving a section after intentional edits"). Approved-section hashes are how the moat detects post-approval edits.

**What it looks like:**

Here's how I think we should build this — but I want to walk you through it before you commit.

I'll show you **2 or 3 different ways** we could do it (e.g. "use the email tool we already have" vs "sign up for a new one" vs "do it ourselves"), with the trade-offs of each in plain English ("option A is faster to ship but costs more per email; option B saves money but takes a week longer").

Then I'll recommend one and you say `looks good` or tell me what to change.

**End the turn with:** *"Reply `approve` if this works, or tell me what to change (e.g. 'simpler', 'use Postgres instead of SQLite', 'explain the rate-limit risk in plain English')."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If this action's answer changes anything user-visible (a screen, a button, a flow, a page transition, a form field), **also update `wireframe.html`** in the same commit. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.

Mechanical enforcement (a state_rule that refuses spec commits without wireframe staging when wireframe.html exists) lands in v0.11 — see issue #45.
