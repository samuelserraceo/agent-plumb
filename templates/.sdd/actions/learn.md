---
type: action
slug: learn
tag: AGENT-LED
title: "learn"
short_label: "Learn"
steps:
  - { id: summary, action: "write a one-paragraph recap of what shipped", field: "§learn.summary" }
  - { id: lessons, action: "extract 1 to 2 cross-work-item lessons and sync patterns.md", field: "§learn.lessons" }
used_by: [feature, bug, refactor]
references: [problem, success, acceptance-criteria, build-task, verify-test-run, non-functional, data-contract]
touches: [.sdd/patterns.md]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 2
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-line refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (feature + 1-line plain-English summary from spec.md §1), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Two parts of the same closing reflection: first capture **what just shipped** (one paragraph anyone can read cold), then extract **the one or two cross-work-item lessons** that future work will benefit from. Each part is its own atomic step + commit. Applies to features, bugs, and refactors — substitute the work-item type wherever "feature" appears below.

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

The distilled value of the work-item. **One or two cross-work-item lessons** — patterns, constraints, gotchas, surprising discoveries that future work (features, bugs, or refactors) will benefit from knowing.

**Anchoring:** scan `non-functional`, `data-contract`, `acceptance-criteria`, and the summary above for signals.

**Examples of good lessons:**

- *"Never trust user-submitted emails as the join key — filter duplicates server-side first. Cost us 4 hours debugging a race condition."*
- *"Turnstile rate limits are per-IP, not per-session — will block legit users on shared WiFi. Cap before the form, surface a backup CAPTCHA path."*
- *"`citext` for case-insensitive emails is non-obvious but mandatory; otherwise `Sam@x.com` and `sam@x.com` create duplicate accounts."*

**Format:** one paragraph per lesson. No jargon. Actionable. Each lesson should answer *"if you read this in 6 months, what would you do differently?"*

**Sync requirement (F1 generic enforcer (`pre-commit-rules.sh`)'s `touches:` enforcement):** stage `.sdd/patterns.md` in this commit. If `patterns.md` doesn't exist yet, create it. Append the new lessons under a heading shaped `## <work-item-type>: <id>-<slug>` — e.g. `## Feature: 003-auth-retry`, `## Bug: 002-safety-hook-still-blocks-...`, or `## Refactor: 001-extract-helper`.

**Wiki-link emission (v1.0 graph layer).** Add a `Source: [[<id>-<slug>]]` line inside the appended pattern block — typically as the last line of the body, but the position doesn't strictly matter (`get_pattern.py`'s `_SOURCE_RE` searches the whole block). Wrapping the source slug in `[[…]]` does two things: the graph cache picks it up as an outgoing edge from pattern → feature, AND the existing `feature_source` extractor still returns the bare slug for callers that don't care about the link form. Future sessions querying `get_backlinks(<id>-<slug>)` will see "the pattern cites this feature as its source" alongside any other inbound references. The pattern's own backlinks (which features cite the pattern) come from `[[pattern:<slug>]]` in feature specs — that's a separate emit-point handled by `proposed-approach`. Example:

```markdown
## Feature: 003-auth-retry

### Auth retry logic
When an auth provider returns 5xx, retry with exponential backoff up to 3 times...
Source: [[003-auth-retry]]
```

Bare slug form (no `pattern:` / `entity:` prefix) is correct here — the slug resolves to the feature folder via priority 1 (filename match).

**Topic-page lifecycle (Phase C+ deferred):**

- If a lesson is feature-specific (only relevant to THIS feature's domain) → append to `patterns.md`.
- If a lesson is cross-cutting (touches concepts that will recur) → check `.sdd/topics/<topic>.md`; update if exists, create if not.
- *Example: "Always use citext for case-insensitive emails" → cross-cutting → `.sdd/topics/data-types.md`.*
- *Example: "AC4 must contain 'one email' to satisfy US3 trust promise" → feature-specific → `patterns.md`.*

For now: append to `patterns.md` only. The cross-cutting topic-page split lands when the topic system ships.

**Output:** fill `spec.md` under `### learn / lessons` with 1-2 lessons. Stage updated `.sdd/patterns.md`.

**Commits with**: `spec.md` + `.sdd/patterns.md`.

**What it looks like:**

What did we learn building this that's worth remembering for the next feature?

Example: *"Lessons from this signup feature: (1) Resend's free tier (the email-sending service we use) is plenty for our scale — don't pay for SendGrid yet; (2) the 'wait for confirmation' screen needs a clear retry button or people email support thinking they're stuck; (3) Neon (the database we use) gets cranky when many short-lived cloud functions all open their own connections — putting PgBouncer (a connection-pool tool) in front fixes it."* These get appended to `.sdd/patterns.md` and shape future feature designs.

**End the turn with:** *"Lessons captured + synced to patterns.md. Run `/next` to push the PR."*
