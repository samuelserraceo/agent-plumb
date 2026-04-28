---
type: action
slug: project-problem
tag: USER-LED
title: "Project problem"
short_label: "§1 Problem"
steps:
  - { id: who, action: ask, field: "§1.who" }
  - { id: pain, action: ask, field: "§1.pain" }
  - { id: today, action: ask, field: "§1.today" }
used_by: [project]
references: [project-success]
touches: [".sdd/projects/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 10
  max_tokens: 4000
  max_commits: 3
requires_user_approval: false
---

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

**End the turn with:** `Run /next to continue to §2 — Project success.`
