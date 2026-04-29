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

Tests are GREEN. Before we write the lessons-learned, the agent re-reads the feature's `spec.md` + the code that was actually shipped wearing a **hostile reviewer hat** — someone whose job is to find what could break this in production. The goal is to catch the problems we'd rather find now than from a real user (or an attacker) next week.

This action is two atomic steps + commits: first the agent drafts the findings, then the user triages each one.

---

## Part 1 — Findings (`§13.findings`)

The agent re-reads the feature's spec + the diff of code shipped in BUILD, then produces a **numbered list of 5–10 findings**. Each finding has four parts:

- **Severity** — `critical` (could lose data, leak secrets, block users), `major` (a real user will hit it), or `minor` (cosmetic / edge-edge case).
- **What could go wrong** — one sentence, plain English. What the bad outcome is.
- **Where** — pointer to the line / file / spec section. Concrete enough that the user can find it.
- **Suggested mitigation** — one line. The cheapest fix that closes it.

**Categories to look at** (the agent should consciously try each angle, not just the obvious ones):

- **Security** — auth bypass, SQL/HTML/script injection, race conditions on writes, secrets in logs or client bundles, missing CSRF / rate-limit, predictable IDs.
- **Edge cases** — empty input, null, the maximum allowed length + 1, weird characters (emoji, RTL, zero-width), duplicate submits, very fast double-click.
- **Failure modes** — network drops mid-request, the database is unreachable, the third-party service (Stripe / Resend / Turnstile / etc.) returns an error or hangs, a partial write that leaves data inconsistent.
- **Accessibility** — keyboard-only navigation works, screen reader announces state changes, color contrast meets WCAG AA, mobile viewport doesn't break layout, focus is visible.
- **Privacy** — PII (names, emails, IPs) is only stored where needed, isn't written to logs, has a documented retention rule, isn't sent to third parties without the user's awareness.
- **User confusion** — the CTA is unambiguous, error messages tell the user what to do next, empty / loading / success states all exist, jargon is translated.

**Discipline:** prefer to surface real worries even when low-confidence. False positives the user will dismiss in seconds; missed risks ship.

**Output:** fill `spec.md` under `### adversarial-review / findings` with the numbered list.

**Commits with**: `spec.md` only.

**End the turn with:** *"Drafted N findings. Reply `triage` to walk through them, or tell me to look harder at a specific category (e.g. `more on accessibility`)."*

---

## Part 2 — Triage (`§13.triage`)

The user reads each finding and decides one of three things for it. The agent walks through them in order, one at a time, and waits for the user's call.

For each finding, the user replies with one of:

- **`fix now`** — this matters; add it to BUILD as a new task. The agent appends a `[BUG]` task to plan-decompose and the spec phase moves back to BUILD with that one task open. Tests + code follow the normal BUILD cycle.
- **`file for later`** — real, but not blocking this ship. The agent appends a one-paragraph stub to `.sdd/<work-item>/follow-ups.md` (creating the file if needed) — title, severity, finding text, and the date. The user can pick it up as a future feature or bug.
- **`decided risk`** — the user is consciously accepting the risk. The agent appends a one-line entry to `.sdd/decisions.md` with the reason the user gives (e.g. *"AC10 race condition: traffic <100/day, retry on conflict is cheap, accepting"*).

**Discipline:** every finding must get a triage call — no silent skips. If the user is unsure, propose a default ("I'd file this for later — sound right?") and let them confirm or override.

**Output:** fill `spec.md` under `### adversarial-review / triage` with one line per finding: `<n>. <severity>: <one-line decision>`. Reflect any new BUILD tasks in plan-decompose; reflect any deferred items in `follow-ups.md`; reflect any accepted risks in `decisions.md`.

**Commits with**: `spec.md` + any of `plan-decompose` / `follow-ups.md` / `decisions.md` that changed.

---

**End the turn with:** `Reply approve when triage complete.`
