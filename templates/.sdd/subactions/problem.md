---
type: subaction
slug: problem
tag: USER-LED
title: "§1 Problem"
short_label: "Problem"
fields:
  - { id: who-has-it, label: "Who has it" }
  - { id: why-now, label: "Why now" }
  - { id: what-breaks, label: "What breaks without it" }
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

Ask the user: who has this problem, why now, and what breaks if we don't solve it. Bundle all three fields in a single turn — they're conceptually one question split for clarity.

**Push for specifics.** "Users want this" is not enough. Which users — recruiters from Twitter, returning customers, internal team? Doing what — onboarding, paying, checking status? When do they hit the wall — first visit, after 30 days, on mobile? If the user's answer stays vague after one push-back, ask one more time and then move on with the best you've got.

**Translate every technical term on first use.** If the user mentions "the API" or "the cron job," ask back what it does for the user, not what it is. Capture the user's words in their language — don't reframe.

**Output:** fill the three fields in `spec.md` under `### §1 Problem`. One short paragraph or 2-3 bullets per field. No assumptions; if you don't know, ask.

**End the turn with:** *"Run `/next` when you're ready to continue to §2 Success."*
