---
type: action
slug: project-stakeholders
tag: USER-LED
prelude_refresh: true
title: "Project stakeholders"
short_label: "§3 Stakeholders"
steps:
  - { id: builders, action: ask, field: "§3.builders" }
  - { id: users, action: ask, field: "§3.users" }
  - { id: gatekeepers, action: ask, field: "§3.gatekeepers" }
used_by: [project]
references: [project-problem, project-capabilities]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 8
  max_tokens: 4000
  max_commits: 3
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

# §3 — Stakeholders (who's involved, who decides)

A project rarely belongs to one person. List who's involved so future decisions know who to consult.

## Step 1 — Who's BUILDING this?

Not "the team" — the actual humans. Names + roles. Even if it's just you, write that down ("solo founder, full-stack").

If you have collaborators or contractors:
- Who codes vs. who designs vs. who reviews
- Who has commit access on this repo
- Who you'd halt and ask before making big design decisions

## Step 2 — Who USES this?

Often the same people from §1 Problem (who has the problem = who uses the solution). But sometimes:
- The buyer is different from the user (sales tool: bought by sales VP, used by reps)
- The user is different from the beneficiary (parental controls: set by parent, used by kid)

Make this explicit. Future feature decisions ask "is this useful for X?" — having the right X listed matters.

## Step 3 — Who else has a say?

Less obvious but real:
- **Investors / bosses / advisors** — people whose approval gates ship dates
- **Compliance** — legal, privacy, security folks who must sign off
- **Vendors** — third parties whose tools the project depends on (Stripe, AWS, a specific API)
- **Existing users of an older tool** — if migrating from something, those users will complain

You don't need to consult everyone — but you need to know they exist so a feature decision doesn't surprise them later.

---

**What it looks like:**

Who cares whether this project succeeds or fails?

Example: *"(1) **You (Sam)** — you'll use it to ship your own startup faster. (2) **Future plugin-marketplace users** — non-technical people who want a less chaotic AI-coding workflow. (3) **AI-pair-programming Claude itself** — uses the framework to discipline its own output."* For each, what do they care about most?

**End the turn with:** `Run /next to advance to BREAKDOWN — capability list.`
