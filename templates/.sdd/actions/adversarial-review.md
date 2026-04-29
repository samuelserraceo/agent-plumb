---
type: action
slug: adversarial-review
tag: AGENT-LED
title: "Adversarial review"
short_label: "§13 Adversarial review"
steps:
  - { id: ar-findings, action: draft, field: "§13.findings" }
  - { id: ar-triage, action: ask, field: "§13.triage" }
used_by: [feature]
references: [verify-test-run, learn]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 15
  max_tokens: 6000
  max_commits: 2
requires_user_approval: true
---

Tests are GREEN. Before we write the lessons-learned, the agent re-reads the feature's `spec.md` + the code that was actually shipped wearing a **hostile reviewer hat** — someone whose job is to find what could break this in production AND what could be made simpler. The goal is to catch the problems we'd rather find now than from a real user (or an attacker) next week, AND to surface complexity we can drop while it's still cheap.

This action is two atomic steps + commits: first the agent drafts the findings, then the user triages each one.

---

## Part 1 — Findings (`§13.findings`)

The agent re-reads the feature's spec + the diff of code shipped in BUILD, then produces a **numbered list of 5–10 findings**. Each finding has four parts:

- **Severity** — `critical` (could lose data, leak secrets, block users), `major` (a real user will hit it), or `minor` (cosmetic / edge-edge case).
- **What could go wrong** OR **What could be simpler** — one sentence, plain English.
- **Where** — pointer to the line / file / spec section. Concrete enough that the user can find it.
- **Suggested fix** — one line. The cheapest fix that closes it (or, for simplification findings, the smaller version of the code).

**Categories to look at** (the agent should consciously try each angle, not just the obvious ones — and prefer to surface a low-confidence concern over missing it):

- **Simplification** — code that could be 5 lines instead of 30; abstractions that aren't earning their weight; dependencies the project could drop; duplicated state; helper functions called once. Per CLAUDE.md foundation 1 (simplicity over capability), this is a first-class category, not an afterthought. If a function is wrapped in three layers of abstraction for "future flexibility," flag it.
- **Security** — auth bypass, SQL / HTML / script injection, race conditions on writes, secrets in logs or client bundles, missing CSRF / rate-limit, predictable IDs.
- **Edge cases** — empty input, null, the maximum allowed length + 1, weird characters (emoji, RTL, zero-width), duplicate submits, very fast double-click.
- **Failure modes** — network drops mid-request, the database is unreachable, the third-party service (Stripe / Resend / Turnstile / etc.) returns an error or hangs, a partial write that leaves data inconsistent.
- **Accessibility** — keyboard-only navigation works, screen reader announces state changes, color contrast meets WCAG AA, mobile viewport doesn't break layout, focus is visible.
- **Privacy** — PII (names, emails, IPs) is only stored where needed, isn't written to logs, has a documented retention rule, isn't sent to third parties without the user's awareness.
- **User confusion** — the CTA is unambiguous, error messages tell the user what to do next, empty / loading / success states all exist, jargon is translated.

**Discipline:** prefer to surface real worries even when low-confidence. A false positive the user dismisses in 2 seconds is much cheaper than a missed real risk that ships to production. If the agent is unsure whether something is a real finding, **it surfaces it anyway** with a `(low confidence)` tag and lets the user judge — per foundation 3 (never assume).

**Output:** fill `spec.md` under `### adversarial-review / findings` with the numbered list.

**Commits with**: `spec.md` only.

**End the turn with:** *"Drafted N findings (X simplification, Y security, …). Reply `triage` to walk through them, or tell me to look harder at a specific category (e.g. `more on accessibility`)."*

---

## Part 2 — Triage (`§13.triage`)

**The default outcome is `fix now`.** Per CLAUDE.md foundation 1 (simplicity over capability) and the framework's "no fake confidence" doctrine, if a finding is real and the cost to fix is moderate, fix it before shipping. Most findings should land in this bucket.

The user walks through each finding in order; for each one, the agent proposes the default and waits for the user to confirm or adjust. Three valid outcomes:

### `fix now` (the default)

This matters — add it to BUILD as a new task. The agent appends a `[BUG]` task to plan-decompose with a verbatim quote of the finding, and the spec phase moves back to BUILD with that one task open. Tests + code follow the normal BUILD cycle (test-first, RED→GREEN→commit, moat re-runs verify-stage).

For **simplification findings** specifically: the new task is `[REFACTOR]`-tagged, not `[BUG]`. Same lifecycle, different intent.

### `defer to follow-up` (the narrow exception)

Real concern, but the user has explicitly decided this isn't blocking THIS ship. The agent challenges: *"You're choosing to defer a `<severity>` finding. What's the reason?"*

The user must give:
1. A **non-trivial reason** (more than one word; the agent rejects "ok" / "fine" / "later" / "low-priority" and asks again).
2. A **trigger condition** — what changes have to happen before this becomes blocking? (e.g. *"defer until traffic crosses 1k DAU; if abuse reports exceed 1/day before that, fix immediately"*).

If both are given, the agent writes a one-paragraph stub to `.sdd/<work-item>/follow-ups.md` (creating the file if needed). Stub format:

```markdown
## <YYYY-MM-DD> — <severity> — <finding title>

**Finding (verbatim from §13):** <one-paragraph quote of the finding>

**Defer reason:** <user's reason, recorded verbatim>

**Trigger to revisit:** <user's condition>

**Source:** spec.md §13.findings #<n>, <feature-id>
```

If the user can't articulate a non-trivial reason or a trigger condition, the agent flips the default back to `fix now`. Per foundation 3 (never assume), the agent doesn't accept a soft "let's revisit later" — that's a recipe for the finding being lost.

### `accepted risk`

The user is consciously deciding NOT to fix and NOT to defer — the risk is real but the cost / benefit doesn't justify the work. Same discipline as `defer to follow-up`: the agent requires a non-trivial reason. The agent appends a one-line entry to `.sdd/decisions.md`:

```markdown
## <YYYY-MM-DDTHH:MM:SSZ>  [<feature-id>]  feature/adversarial-review
Accepted risk: <severity> — <finding title>. Reason: <full reason>.
```

The decisions.md append-only contract preserves this for audit. If the risk later bites in production, the audit trail shows when and why it was accepted.

### Hard gate on `critical` findings

Findings the agent flagged as `critical` severity (or anything tagged `BLOCK` by an automated review tool) have a stricter rule:

- **`fix now` is allowed** as the default.
- **`defer to follow-up` is REFUSED.** The agent says: *"This is a critical finding. Critical findings can't be deferred to follow-up. The only valid triages are `fix now` or `accepted risk` with an explicit non-trivial reason. Which do you pick?"*
- **`accepted risk`** is allowed but with extra discipline: the reason must reference a specific compensating control (e.g. *"manual review on every signup; alert wired"*) AND must be acknowledged in `decisions.md` with the word "accepted-critical" in the entry — making it grep-able for future audits.

### When the agent is unsure

If the user's reply is ambiguous (e.g. they say "let me think about it" or "skip"), the agent does NOT silently skip — that breaks foundation 3 (never assume). Instead, it asks in plain English:

> "Sorry, I want to make sure I'm recording the right thing. Three options:
> 1. **`fix now`** — add it to BUILD; we deal with it before ship.
> 2. **`defer to follow-up`** — real, but not for this ship; you'll tell me why and what triggers a revisit.
> 3. **`accepted risk`** — known risk you're choosing to accept; I'll record the reason in decisions.md.
>
> Which one?"

The agent waits for an explicit pick. No silent defaults beyond the `fix now` initial proposal.

### Output

Fill `spec.md` under `### adversarial-review / triage` with one line per finding:

```text
<n>. <severity>: <fix now / defer / accepted> — <one-line decision summary>
```

Reflect any new tasks in plan-decompose (with the `[BUG]` or `[REFACTOR]` tag), any deferred items in `follow-ups.md`, and any accepted risks in `decisions.md`.

**Commits with**: `spec.md` + any of `plan-decompose` / `follow-ups.md` / `decisions.md` that changed. One commit per file changed (atomic-step rule).

---

**End the turn with:** `Reply approve when triage complete.`
