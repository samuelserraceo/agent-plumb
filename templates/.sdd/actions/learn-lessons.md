---
type: action
slug: learn-lessons
tag: AGENT-LED
title: "learn-lessons"
short_label: "Lessons"
bundling: n_a
used_by: [feature]
references: [non-functional, data-contract, acceptance-criteria, learn-summary]
touches: [.sdd/patterns.md]
trust: framework
budget:
  max_minutes: 20
  max_tokens: 5000
  max_commits: 1
requires_user_approval: false
---

The distilled value of the feature. **One or two cross-feature lessons** — patterns, constraints, gotchas, surprising discoveries that future features will benefit from knowing.

**Anchoring:** scan `non-functional`, `data-contract`, `acceptance-criteria`, `learn-summary` for signals.

**Examples of good lessons:**
- *"Never trust user-submitted emails as the join key — filter duplicates server-side first. Cost us 4 hours debugging a race condition."*
- *"Turnstile rate limits are per-IP, not per-session — will block legit users on shared WiFi. Cap before the form, surface a backup CAPTCHA path."*
- *"`citext` for case-insensitive emails is non-obvious but mandatory; otherwise `Sam@x.com` and `sam@x.com` create duplicate accounts."*

**Format:** one paragraph per lesson. No jargon. Actionable. Each lesson should answer *"if you read this in 6 months, what would you do differently?"*

**Sync requirement (Theme 4's pre-commit-touches hook):** stage `.sdd/patterns.md` in the commit that closes this sub-action. If patterns.md doesn't exist yet, create it. Append the new lessons under a `## Feature: <id>-<slug>` heading.

**Topic-page lifecycle (Phase C-deferred):**
- If a lesson is feature-specific (only relevant to THIS feature's domain) → append to patterns.md
- If a lesson is cross-cutting (touches concepts that will recur) → check `.sdd/topics/<topic>.md`; update if exists, create if not
- *Example: "Always use citext for case-insensitive emails" → cross-cutting → `.sdd/topics/data-types.md`*
- *Example: "AC4 must contain 'one email' to satisfy US3 trust promise" → feature-specific → `patterns.md`*

For B-1: append to `patterns.md` only. The cross-cutting topic-page split lands with full Theme 7 in Phase C.

**Output:** fill `spec.md` under `### learn-lessons` with 1-2 lessons. Stage updated `.sdd/patterns.md`.

**End the turn with:** *"Lessons captured + synced to patterns.md. Run `/next` to push the PR."*
