---
type: action
slug: bug-repro
tag: USER-LED
title: "§2 Repro"
short_label: "Repro"
steps:
  - { id: steps, prompt: "Steps to reproduce — exact sequence. (e.g. '1. Sign up with sam@x.com  2. Click the magic-link email  3. Page shows 'Session not found' instead of dashboard')", field: "§2.steps" }
used_by: [bug]
references: [bug-problem]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 10
  max_tokens: 2500
  max_commits: 1
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-line refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (feature + 1-line plain-English summary from spec.md §1), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Capture an exact, deterministic sequence that reproduces the bug. Without a reliable repro, any "fix" is a guess.

**Required shape:** numbered steps. Each step is one observable action (a click, a typed input, a wait, a system event). Include:

1. **Starting state** — what's on screen / what's in the database / which user / which env (`local`, `staging`, `prod`).
2. **Each user-visible action** — clicked X, typed Y in field Z, waited 5 seconds.
3. **The expected result** — what the user thought would happen.
4. **The actual result** — what actually happened. Include exact error text, response code, screenshot path, or other evidence.

**Push for determinism.** If the user says "sometimes the email doesn't arrive," ask back: *"Every signup, or some signups? Same email provider? Same network?"* If the bug is genuinely intermittent, capture what you know about the trigger conditions — that itself is signal.

**Push for environment.** Browser, OS, mobile vs desktop, region, account type. Bugs that only happen on iPhone Safari + private mode are a different shape than bugs that always happen.

**Don't propose a fix here.** §2 captures only what the user sees, not why. The agent's "I bet this is the X cause" speculation belongs in §3 (root cause), after the repro is locked.

**If the bug can't be reproduced.** Halt. The framework refuses to advance past §2 with empty repro steps — without them, the regression test in §5 has nothing to assert. Surface the halt to the user:

> *"§2 needs a deterministic repro. If you can't reproduce it on demand, options: (A) add logging/instrumentation and reproduce in production, (B) ship as a `feature.md` to harden the area, or (C) close as 'cannot reproduce' and re-open if it recurs. Reply A / B / C."*

**Output:** replace the `- [ ] steps: …` step row under `### action: bug-repro` with `- [x] steps: <one-line summary>`. The numbered steps + expected vs actual go under the action heading after the step row.

**What it looks like:**

Let me reduce the bug to the **smallest set of steps** that triggers it.

Example: *"To reproduce: (1) open https://oursite.com/signup, (2) type `not-an-email` in the email field, (3) click submit. Expected: 'please use a valid email'. Actual: 503 error page. Reliably reproduces on Chrome 120 and Safari 17."* If we can't reliably reproduce, we don't fully understand the bug yet.

**End the turn with:** *"Run `/next` to capture root cause in §3."*
