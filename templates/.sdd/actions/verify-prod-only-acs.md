---
type: action
slug: verify-prod-only-acs
tag: USER-LED
title: "verify-prod-only-acs"
short_label: "PROD-ONLY check"
fields:
  - { id: prod-only-results, label: "PROD-ONLY AC verifications" }
bundling: bundle_all_fields_in_one_turn
used_by: [feature]
references: [acceptance-criteria, signoff-steps]
touches: []
trust: framework
budget:
  max_minutes: 30
  max_tokens: 4000
  max_commits: 1
requires_user_approval: false
---

For every AC in `acceptance-criteria` tagged `[PROD-ONLY]`, the user walks through it manually after the first prod deploy. These are the things impossible to test in dev (real Stripe charges, real email bounce webhooks, real Turnstile tokens, real DNS propagation).

**If §11 has zero `[PROD-ONLY]` ACs:** auto-skip. Fill with `**No PROD-ONLY ACs to verify.**` and continue.

**Otherwise, for each `[PROD-ONLY]` AC:**

1. Restate the AC in plain English
2. Give the user a step-by-step walkthrough: *"Open the live URL `<X>`. Sign up with a real email. Wait 30 sec. Check your inbox for a confirmation. Reply yes/no."*
3. User replies. If `yes` → tick the box. If `no` or `details` → capture the issue and mark the AC as `[BUG]` in plan-decompose; kick back to BUILD.

**If user can't verify a `[PROD-ONLY]` AC right now** (e.g., *"I don't have a Stripe account set up"*): don't fail the feature. Capture it in `INDEX.md` under `## Pending production verification` for next time.

**Output:** fill `spec.md` under `### verify-prod-only-acs` with one bullet per `[PROD-ONLY]` AC, ticked or carried forward.

**End the turn with:** *"PROD-ONLY verification complete. Run `/next` to write the lesson summary."*
