---
type: action
slug: problem
tag: USER-LED
title: "§1 Problem"
short_label: "Problem"
steps:
  - { id: who, prompt: "Who specifically has this problem? (real persona, not 'users')", field: "§1.who-has-it" }
  - { id: why-now, prompt: "Why is it worth solving now?", field: "§1.why-now" }
  - { id: what-breaks, prompt: "What breaks (concretely) if it isn't solved?", field: "§1.what-breaks" }
used_by: [feature]
references: []
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 3
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-line refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (feature + 1-line plain-English summary from spec.md §1), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Ask the user: who has this problem, why now, and what breaks if we don't solve it. Each is its own atomic step (one `[ ]` row per sub-question). Cognitive prep is free-form — you can ask all three together if it reads naturally — but each step gets its own commit when the answer lands.

**Push for specifics.** "Users want this" is not enough. Which users — recruiters from Twitter, returning customers, internal team? Doing what — onboarding, paying, checking status? When do they hit the wall — first visit, after 30 days, on mobile? If the user's answer stays vague after one push-back, ask one more time and then move on with the best you've got.

**Translate every technical term on first use.** If the user mentions "the API" or "the cron job," ask back what it does for the user, not what it is. Capture the user's words in their language — don't reframe.

**Output:** fill the three fields in `spec.md` under `### §1 Problem`. One short paragraph or 2-3 bullets per field. No assumptions; if you don't know, ask.

**What it looks like:**

Three quick questions for you:
1. **Who has this problem?** Your customers? Your teammates? You? Be specific — "a recruiter who clicks our LinkedIn link", not "users".
2. **Why are we solving it now and not next year?** What changed?
3. **If we don't fix it, what goes wrong concretely?** People give up halfway through signup? Support emails pile up unanswered? Pick a real story.

**End the turn with:** *"Run `/next` when you're ready to continue to §2 Success."*
