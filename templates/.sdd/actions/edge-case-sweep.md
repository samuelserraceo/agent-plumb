---
type: action
slug: edge-case-sweep
tag: AGENT-LED
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

A numbered list of candidates, each one line. Format:

```text
1. **<short name>** [<category>] — <what could happen> — proposed AC: `AC<n>: <test wording>`
2. **Empty contact list** [empty] — first-time user lands on /dashboard with 0 contacts and sees a blank page — proposed AC: `AC9: Dashboard with 0 contacts shows an empty-state card with "Import your first contact" CTA`
3. **30s API timeout** [network] — Resend slow, signup form hangs and user double-clicks — proposed AC: `AC10: Submit button disables for the duration of the request; second click is a no-op`
```

Aim for 4-10 candidates. Fewer = the sweep was too shallow; more = stop drowning the user, fold near-duplicates.

## The triage

The user reviews each candidate and replies one of three words per number:

- **`take`** — add this AC to §11. The agent appends it via the inline `/re-approve` flow (same two-step pattern as `plan-decompose`: re-approve §11 with the new ACs, then add a matching task to `plan-decompose`).
- **`skip`** — not worth covering. The candidate is dropped; nothing lands in spec.md.
- **`defer`** — real concern, but not for this iteration. The agent records it in §11.5 of spec.md under a `### Deferred edge cases` heading so the next feature or follow-up can pick it up.

User can reply per-number (`1: take, 2: skip, 3: defer`) or in bulk (`take 1,2,5; skip 3,4; defer 6`). Either works.

## Why it matters (non-technical reviewer language)

A spec that only tests the happy path is a spec that lies — it claims the feature works when it only works for the easy case. Real users paste 200-character emails, click submit twice, lose their connection mid-form, and log in from a phone on the train. The sweep is 10 minutes of *"what could break?"* that saves hours of *"why is it broken?"* later.

This is also the audit-trail moment for the non-technical user: every candidate the user reviews shows up in `decisions.md` with their pick. Future-you reading the audit trail in three months can see *"we considered the 30s timeout case and chose to skip it because of X"* — that's a real decision, not a forgotten gap.

**End the turn with:** *"Reply with which to take/skip/defer (e.g. `take 1,2,5; skip 3,4; defer 6`). Each `take` becomes a new AC + task. Each `skip` is dropped. Each `defer` is recorded for next iteration."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If a `take` lands a new AC that changes anything user-visible (a new empty-state card, a new error message, a disabled button state), **also update `wireframe.html`** in the same commit as the AC. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.
