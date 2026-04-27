---
type: subaction
slug: success
tag: USER-LED
title: "§2 Success"
short_label: "Success"
fields:
  - { id: verifiable-outcomes, label: "Verifiable outcomes (with numbers)" }
bundling: bundle_all_fields_in_one_turn
used_by: [feature]
references: []
touches: []
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

Ask: how will we know this worked? Push for **numbers**, not vibes.

Offer 4-5 metric patterns (and a free-form escape):
- **Volume** — signups, orders, messages per day/week/month
- **Speed** — time to first action, response time, conversion rate
- **Quality** — NPS, error rate, support tickets, completion rate
- **Engagement** — DAU/WAU/MAU, retention curve, time in app
- **Or describe your own**

User picks one or two and gives target numbers. If they say "it works well," ask: *"What does 'well' look like as a number? Compared to what baseline?"*

**Output:** fill `spec.md` under `### §2 Success` with one short paragraph per metric chosen — include the target number AND the current baseline if known. Capture the user's words; don't reframe.

**End the turn with:** *"Run `/next` when you're ready to continue to §3 User stories."*
