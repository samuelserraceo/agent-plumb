---
type: action
slug: verify-prod-only-acs
tag: USER-LED
title: "verify-prod-only-acs"
short_label: "PROD-ONLY check"
steps:
  - { id: prod-walk, prompt: "For each [PROD-ONLY] AC in §11: walk through it manually post-deploy. Tick or carry forward.", field: "§verify-prod-only-acs" }
used_by: [feature]
references: [acceptance-criteria, signoff-steps]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 4000
  max_commits: 1
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-line refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (feature + 1-line plain-English summary from spec.md §1), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

For every AC in `acceptance-criteria` tagged `[PROD-ONLY]`, the user walks through it manually after the first prod deploy. These are the things impossible to test in dev (real Stripe charges, real email bounce webhooks, real Turnstile tokens, real DNS propagation).

**If §11 has zero `[PROD-ONLY]` ACs:** auto-skip. Fill with `**No PROD-ONLY ACs to verify.**` and continue.

**Otherwise, for each `[PROD-ONLY]` AC:**

1. Restate the AC in plain English
2. Give the user a step-by-step walkthrough: *"Open the live URL `<X>`. Sign up with a real email. Wait 30 sec. Check your inbox for a confirmation. Reply yes/no."*
3. User replies. If `yes` → tick the box. If `no` or `details` → capture the issue and mark the AC as `[BUG]` in plan-decompose; kick back to BUILD.

**If user can't verify a `[PROD-ONLY]` AC right now** (e.g., *"I don't have a Stripe account set up"*): don't fail the feature. Capture it in `INDEX.md` under `## Pending production verification` for next time.

**Output:** fill `spec.md` under `### verify-prod-only-acs` with one bullet per `[PROD-ONLY]` AC, ticked or carried forward.

**What it looks like:**

Some checks can only happen against the real production setup (e.g. real payment processor, real email provider, real DNS). I list those out so you can walk them by hand once we deploy.

Example: *"Two checks tagged [PROD-ONLY]: (1) `AC18` — sending a real welcome email through Resend lands in the inbox within 30 sec, not spam folder. (2) `AC19` — Stripe webhook delivery confirms within 60 sec of charge."* These go into INDEX.md `## Pending production verification` and you tick them after first deploy.

**End the turn with:** *"PROD-ONLY verification complete. Run `/next` to write the lesson summary."*
