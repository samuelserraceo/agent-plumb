---
type: action
slug: edge-case-sweep
tag: AGENT-LED
prelude_refresh: true
title: "Edge-case sweep"
short_label: "§11.5 Edge-case sweep"
steps:
  - { id: ec-sweep, action: draft, field: "§11.5.candidates" }
  - { id: ec-pick, action: ask, field: "§11.5.picked" }
used_by: [feature]
references: [acceptance-criteria, plan-decompose]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 10
  max_tokens: 5000
  max_commits: 2
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item name + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

After §11 ACs are written and `plan-decompose` has mapped them to tasks, the agent looks at the spec and asks: **"what could break that no AC covers?"** The answer is a numbered list of candidates. The user picks which to add as new ACs (and tasks), which to drop, and which to defer.

This is the difference between *"the happy path is tested"* and *"this thing actually works in production."* Most production bugs come from edge cases the original spec missed — empty lists, bad input, slow networks, two users at once. The sweep surfaces them before BUILD starts, not after a user finds them.

## What the agent considers

For each category, the agent thinks about the feature in §1-§7 and asks the questions below. Skip categories that don't apply (a backend cron job has no mobile-specific edges).

- **Empty state** — no data yet. *"What does the dashboard show with 0 contacts? Does the empty state explain what to do next, or is it a blank screen that looks broken?"*
- **Max state** — too much data. *"What if there are 10,000 contacts? Does the list paginate, virtualise, or freeze the page?"*
- **Bad input** — invalid, malformed, or hostile. *"What if the email field has spaces? Has 200 chars? Has script tags? Has emojis? Is left blank?"*
- **Network failure** — timeout, partial response, retry. *"What if the API takes 30 seconds? Returns 500? Times out mid-write? The user double-clicks submit?"*
- **Concurrency** — two users editing the same thing. *"What if two people change the same setting at the same time? Whose change wins?"*
- **Authorisation edges** — logged-out, expired session, wrong role. *"What does a logged-out user see if they paste a URL to a private page? An expired token mid-session? An admin URL hit by a member?"*
- **Mobile-specific** — small viewport, slow network, no JS, intermittent connection. *"Does the form work on iPhone-13 portrait? On a 3G connection? If JS fails to load? If the connection drops mid-submit?"*
- **Time-based** — daylight savings, midnight rollover, leap year, timezone mismatch. *"What if a daily report runs at midnight UTC but the user is in Tokyo? What happens on the day clocks change?"*

If a category surfaces nothing real for this feature, drop it. Don't pad the list with hypotheticals.

## What it produces

A numbered list of candidates. Each line follows the same template; concrete examples follow separately so the agent doesn't accidentally treat the example numbering as literal output.

**Template (one entry per line, for each candidate):**

```text
<n>. **<short name>** [<category>] — <what could happen> — proposed AC: `AC<m>: <test wording>`
```

**Example output for a hypothetical signup-with-dashboard feature:**

```text
1. **Empty contact list** [empty] — first-time user lands on /dashboard with 0 contacts and sees a blank page — proposed AC: `AC9: Dashboard with 0 contacts shows an empty-state card with "Import your first contact" CTA`
2. **30s API timeout** [network] — Resend slow, signup form hangs and user double-clicks — proposed AC: `AC10: Submit button disables for the duration of the request; second click is a no-op`
3. **Password reset on expired link** [auth] — user clicks an expired reset link 48h after request — proposed AC: `AC11: expired reset links show "this link has expired — request a new one" with the request CTA`
```

Aim for **up to 10** candidates. **Fewer is fine when the feature is small and there's nothing else real to surface** — don't fabricate hypotheticals to hit a quota. The earlier "no padding" rule (above) overrides any volume target. If the feature genuinely has only 2 edge cases, write 2.

## The triage

The user reviews each candidate and replies one of three words per number:

- **`take`** — add this AC to §11. The agent appends the new AC and treats §11 as edited; on the next `/next` advance the agent walks the user through inline re-approval per CLAUDE.md's "Skippable sections — proactively offer, don't force" pattern (the user replies `re-approve §11` to confirm the new content). Then the agent adds a matching task to `plan-decompose`. (The earlier `/re-approve <slug>` slash command is deprecated — re-approval is now handled inline through `/next`.)
- **`skip`** — not worth covering. The candidate is dropped; nothing lands in spec.md.
- **`defer`** — real concern, but not for this iteration. The agent records it in §11.5 of spec.md under a `### Deferred edge cases` heading so the next feature or follow-up can pick it up.

User can reply per-number (`1: take, 2: skip, 3: defer`) or in bulk (`take 1,2,5; skip 3,4; defer 6`). Either works.

## Why it matters (non-technical reviewer language)

A spec that only tests the happy path is a spec that lies — it claims the feature works when it only works for the easy case. Real users paste 200-character emails, click submit twice, lose their connection mid-form, and log in from a phone on the train. The sweep is a quick *"what could break?"* pass that saves hours of *"why is it broken?"* later.

The candidates and the user's picks are all recorded in `spec.md` under §11.5 (the section the action's `touches` field declares). The user's `take` / `skip` / `defer` calls become part of the section's content — written into spec.md alongside the AC list — so future readers can see what was considered and what was deliberately set aside. The action does NOT separately append to `decisions.md`; that file's entries come from the standard section-approval flow when §11 itself is re-approved (see CLAUDE.md "Audit log" doctrine).

**What it looks like:**

Before we move from planning to building, let me think about weird cases that could break this — things you might not have thought of when describing the feature.

Example: *"For the signup form: what if someone signs up with the same email twice? Suppose their email provider is offline when we try to send the confirmation. Imagine they click the confirmation link from a different browser than the one they signed up in. Consider someone pasting a really long fake email like 'a' × 10000."* I'll list maybe 8-10 of these. For each you reply with one of three outcomes — **`take`** (add it as a new acceptance criterion (AC) + task), **`skip`** (not worth covering, drop it), or **`defer`** (real concern, but parked under "Deferred edge cases" for a later iteration).

**End the turn with:** *"Reply with which to take/skip/defer (e.g. `take 1,2,5; skip 3,4; defer 6`). Each `take` becomes a new AC + task. Each `skip` is dropped. Each `defer` is recorded for next iteration."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If a `take` lands a new AC that changes anything user-visible (a new empty-state card, a new error message, a disabled button state), **also update `wireframe.html`** in the same commit as the AC. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.
