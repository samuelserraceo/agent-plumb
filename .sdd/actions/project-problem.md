---
type: action
slug: project-problem
tag: USER-LED
prelude_refresh: true
title: "Project problem"
short_label: "§1 Problem"
steps:
  - { id: who, action: ask, field: "§1.who" }
  - { id: pain, action: ask, field: "§1.pain" }
  - { id: today, action: ask, field: "§1.today" }
used_by: [project]
references: [project-success]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 10
  max_tokens: 4000
  max_commits: 3
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item name + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

# §1 — Project problem (who has it, what hurts)

This is the first thing a future reader needs to know. The project doesn't exist for its own sake — it exists because somebody has a problem.

Three small steps, each its own commit.

## Step 1 — Who specifically has this problem?

Don't say "users" or "everyone." Get specific. Common patterns:
- *"Founders running waitlists who don't have time to set up a real CRM"*
- *"E-commerce shops with under 50 SKUs that find Shopify too heavy"*
- *"Teams that ship a few features per quarter and need lightweight project tracking"*

What you write here defines who this whole project is FOR. Every later decision narrows down to "does this serve <these people>?"

If you can't name them in one sentence, the project is too vague — keep asking until you can.

## Step 2 — What hurts about their current life?

Forget the solution. Forget the product. What's the actual pain? Not "they don't have a tool" — that's the absence of YOU. The pain is what the absence causes.

Examples:
- *"They lose 2 hours a week copying signups between Mailchimp and Notion"*
- *"They can't tell which leads are hot until the rep manually rechecks each one"*
- *"They lose deals because their tool can't track multi-touchpoint follow-ups"*

The pain is the project's reason to exist. If the pain is small, the project is small.

## Step 3 — How are they coping today?

Every problem worth solving has a workaround. List them. They tell you:
- What the bar is (you have to be better than the workaround)
- What features they ALREADY have via the workaround (don't re-build those)
- What stopped them from solving it themselves (skill gap? cost? time?)

Examples:
- *"They use Google Sheets + Zapier — works but breaks at 500 rows"*
- *"They pay $200/mo for HubSpot — most features unused, the few they need are buried"*
- *"They built a custom Notion template — works for them but their VA can't navigate it"*

---

**What it looks like:**

What's the high-level problem THIS PROJECT exists to solve?

Example: *"Indie founders waste 2 hours per feature writing specs that go stale 3 days later. They want to ship; their spec rots. We're building a tool that keeps the spec, the code, and the tests in lockstep so the spec is always alive and reviewable."* One paragraph. The thing that, if it didn't exist, the project would have no reason to be.

**End the turn with:** `Run /next to continue to §2 — Project success.`
