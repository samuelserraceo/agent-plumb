---
type: action
slug: learn
tag: AGENT-LED
title: "learn"
short_label: "Learn"
steps:
  - { id: summary, action: one_paragraph_recap_of_what_shipped, field: "§learn.summary" }
  - { id: lessons, action: extract_1_to_2_cross_feature_lessons_sync_patterns_md, field: "§learn.lessons" }
used_by: [feature]
references: [problem, success, acceptance-criteria, build-task, verify-test-run, non-functional, data-contract]
touches: [.sdd/patterns.md]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 2
requires_user_approval: true
---

Two parts of the same closing reflection: first capture **what just shipped** (one paragraph anyone can read cold), then extract **the one or two cross-feature lessons** that future features will benefit from. Each part is its own atomic step + commit.

---

## Part 1 — Summary

One paragraph (4-6 sentences) capturing what just shipped.

**Anchoring:** reference `problem` (why we built it), `success` (what we optimized for), and what actually happened during BUILD (any pivots, surprises, dead ends recovered from).

**Prompt structure:**

1. *What got built* — one sentence summary of the feature.
2. *Why* — one sentence linking back to the problem.
3. *What surprised* — one or two sentences on a tradeoff, edge case, or implementation detail that didn't go as planned.
4. *What you'd do differently* — one sentence; can be *"nothing — went smoothly."*

**Plain English.** Should be readable cold by someone who didn't follow the build. No jargon, no internal slang.

**Output:** fill `spec.md` under `### learn / summary` with one paragraph.

**Commits with**: `spec.md` only.

**End the turn with:** *"Summary drafted. Reply `looks good` or tell me what's off, then we move to lessons."*

---

## Part 2 — Lessons

The distilled value of the feature. **One or two cross-feature lessons** — patterns, constraints, gotchas, surprising discoveries that future features will benefit from knowing.

**Anchoring:** scan `non-functional`, `data-contract`, `acceptance-criteria`, and the summary above for signals.

**Examples of good lessons:**

- *"Never trust user-submitted emails as the join key — filter duplicates server-side first. Cost us 4 hours debugging a race condition."*
- *"Turnstile rate limits are per-IP, not per-session — will block legit users on shared WiFi. Cap before the form, surface a backup CAPTCHA path."*
- *"`citext` for case-insensitive emails is non-obvious but mandatory; otherwise `Sam@x.com` and `sam@x.com` create duplicate accounts."*

**Format:** one paragraph per lesson. No jargon. Actionable. Each lesson should answer *"if you read this in 6 months, what would you do differently?"*

**Sync requirement (F1 generic enforcer (`pre-commit-rules.sh`)'s `touches:` enforcement):** stage `.sdd/patterns.md` in this commit. If `patterns.md` doesn't exist yet, create it. Append the new lessons under a `## Feature: <id>-<slug>` heading.

**Topic-page lifecycle (Phase C+ deferred):**

- If a lesson is feature-specific (only relevant to THIS feature's domain) → append to `patterns.md`.
- If a lesson is cross-cutting (touches concepts that will recur) → check `.sdd/topics/<topic>.md`; update if exists, create if not.
- *Example: "Always use citext for case-insensitive emails" → cross-cutting → `.sdd/topics/data-types.md`.*
- *Example: "AC4 must contain 'one email' to satisfy US3 trust promise" → feature-specific → `patterns.md`.*

For now: append to `patterns.md` only. The cross-cutting topic-page split lands when the topic system ships.

**Output:** fill `spec.md` under `### learn / lessons` with 1-2 lessons. Stage updated `.sdd/patterns.md`.

**Commits with**: `spec.md` + `.sdd/patterns.md`.

**End the turn with:** *"Lessons captured + synced to patterns.md. Run `/next` to push the PR."*
