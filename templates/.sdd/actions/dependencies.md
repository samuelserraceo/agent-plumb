---
type: action
slug: dependencies
tag: AGENT-LED
prelude_refresh: true
title: "§8 Dependencies"
short_label: "Dependencies"
steps:
  - { id: deps, action: "draft external services + pricing math scaled to success-volume targets", field: "§8" }
used_by: [feature]
references: [success, proposed-approach]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 15
  max_tokens: 4000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item name + **verbatim 1-line quote** from the work-item's §1 prose — *the spec's first paragraph, exactly as the user wrote it; do not paraphrase from memory*), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

**Skippable** if the feature uses no paid or external services. Proactively offer: *"§8 Dependencies covers external services (paid APIs, third-party tools). This feature [does/doesn't] seem to use any. Skip? Reply `skip no external dependencies` (handled inline by `/next`) or tell me what services you're using."*

**If continuing:** for each external service (`proposed-approach` usually names them — Resend, Stripe, OpenAI, Cloudflare, etc.), produce one sub-section:

- **What it does (plain English, not marketing copy):** *"Resend sends the confirmation email."* — NOT *"Resend is a transactional email API."*
- **Pricing scaled to `success` volume:** show the math. *"200 signups/week × 1 email each = 200/week × 4 weeks = 800/month. Resend Free = 3,000/month. Cost: $0."*
- **Setup the user must do:** API key, webhook URL, account creation, billing setup
- **Failure mode:** what breaks if this service is down? What's the user-visible behavior?
- **Total monthly cost** (sum across all services, scaled to expected volume)

**Output:** fill `spec.md` under `### §8 Dependencies` with one sub-section per service.

**What it looks like:**

What outside services do we need to pay for or sign up to?

Example: *"For this feature we'll need: (1) **Resend** (~$0/mo at 200 signups/mo) — sends the welcome email, (2) **Neon Postgres** (~$0/mo at our size) — stores the signups, (3) **Cloudflare Turnstile** (free) — blocks bots from spamming the form."* I'll always show you the math: how many emails we'll send × cost per email = total. If anything's surprising you tell me and we redo it.

**End the turn with:** *"Reply `looks good` if these dependencies look right, or tell me what's wrong (e.g. 'we're not using Stripe, just Lemon Squeezy', 'add Cloudflare Turnstile', 'pricing math is off — we expect 5x that volume'). Then run `/next` to continue."*
