---
type: action
slug: project-success
tag: USER-LED
prelude_refresh: true
title: "Project success"
short_label: "§2 Success"
steps:
  - { id: ship-state, action: ask, field: "§2.ship-state" }
  - { id: metrics, action: ask, field: "§2.metrics" }
  - { id: timeline, action: ask, field: "§2.timeline" }
used_by: [project]
references: [project-problem, project-capabilities]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 10
  max_tokens: 4000
  max_commits: 3
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list, binary yes/no). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

# §2 — Project success (what does "done" look like)

A project without a definition of "done" runs forever. Three steps to pin it down.

> **§170 — Auto-annotate ingested metrics on record.** When you write the user's answer into spec.md, scan each metric line for theatre tokens (numerical comparisons like `<5 min` / `≥80%`, raw counts like `100` / `5x`, currency like `$200/mo`, percentages, durations, absolutes like `always` / `never` / `100%`). For each match, append the matching annotation INLINE on the same line so the [no-theatre lint](../scripts/lint-no-theatre.sh) passes — never soften or strip the metric to bypass the lint (that defeats §2's whole point). Annotation choice:
>
> - `{best-effort: project-author at SHIP}` — the **default** for human-judged success metrics (NPS, satisfaction, "feels right"). The project author validates at SHIP.
> - `{prod-only: <one-line reason>}` — for metrics only measurable against live infra (real users, real signups, real $ revenue). Tag the reason explicitly (e.g. *"real signups, no dev synthetic"*).
> - `{verify-by: T-NNN}` — only when a test exists or will be built that mechanically asserts this value. Most §2 metrics aren't this; don't reach for it.
>
> If you can't tell which fits, default to `{best-effort: project-author at SHIP}` and tell the user in your reply: *"I tagged this as best-effort — say if it should be prod-measured or test-bound instead."* Foundation 3: ASK rather than assume which annotation applies.

## Step 1 — What does the world look like the day this ships?

Describe the moment the project is "live" — not the features, the OUTCOME. Concrete examples:

- *"Users can create an account, add their first 3 contacts, and email them a templated outreach in under 5 minutes."*
- *"A team's manager can see at a glance which leads are hot, which are cold, and which they haven't touched in 14+ days."*
- *"Customers can self-serve order status via a public link without contacting support."*

If you can't describe the moment, you can't tell when you've arrived. Keep asking until the answer is concrete enough to test.

## Step 2 — How will you measure that?

A success number that future-you can check. Common patterns:

- **Volume:** "100 signups in the first week"
- **Speed:** "First action completed in <5 min for new users"
- **Quality:** "NPS ≥40 from first 50 users"
- **Adoption:** "70% of signups create their first <thing> within 24h"
- **Retention:** "30% of week-1 users are still active week 4"

Pick one or two — not five. Less is more.

## Step 3 — When does this need to be done?

Every project has a force-function. What is it for this one?

Examples (use absolute YYYY-MM-DD dates — relative phrases like "end of Q2" or "mid-March" age poorly as the spec is re-read months later):
- *"Demo to investors by 2026-06-15"*
- *"Beta launch by 2026-06-30"*
- *"Replace the existing tool by 2026-03-15 because the contract expires"*
- *"No fixed deadline — but I want to ship one S-sized capability first to validate"*

If there's no deadline, set a "first-capability" target using framework-native sizing (one S-sized capability shipped first beats a perfect plan that ships nothing). Per CLAUDE.md doctrine rule 6, the framework sizes work in S/M/L and atomic-step counts, not in clock time.

---

**What it looks like:**

How will you know this PROJECT (not just a feature) is succeeding?

Example: *"Quarter 1: 50 indie founders use it to ship at least one feature. Quarter 2: I (Sam) ship 10 of my own features through it. Year 1: it's listed on the Anthropic plugin marketplace and has 500 active users."* Numbers + dates, even if rough.

**End the turn with:** `Run /next to continue to §3 — Stakeholders.`
