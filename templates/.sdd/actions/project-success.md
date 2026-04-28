---
type: action
slug: project-success
tag: USER-LED
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

# §2 — Project success (what does "done" look like)

A project without a definition of "done" runs forever. Three steps to pin it down.

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

Examples:
- *"Demo to investors in 6 weeks"*
- *"Beta launch by end of Q2"*
- *"Replace the existing tool by mid-March because the contract expires"*
- *"No deadline — but I want to ship the first capability within 2 weeks to validate"*

If there's no deadline, set a "first-capability" target — having SOMETHING shippable in 1-3 weeks beats a perfect plan that takes 6 months.

---

**End the turn with:** `Run /next to continue to §3 — Stakeholders.`
