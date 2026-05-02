---
type: action
slug: success
tag: USER-LED
title: "§2 Success"
short_label: "Success"
steps:
  - { id: metric, prompt: "Pick a metric pattern (volume / speed / quality / engagement) or describe your own. Give a target number AND the current baseline if known.", field: "§2.verifiable-outcomes" }
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

**What it looks like:**

How will we know this worked? Give me a number, not a vibe.

Common patterns: **volume** (signups per month), **speed** (time from landing on the page to completing checkout), **quality** (NPS score, support-ticket rate), **engagement** (people coming back next week). Pick one or two and say where we are today (the baseline) and where we want to get to (the target). Or describe your own.

**End the turn with:** *"Run `/next` when you're ready to continue to §3 User stories."*
