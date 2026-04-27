# SDD Decisions Log

> **Append-only event log.** Every approval, phase transition, and
> notable decision gets one entry. Future-you reads this to remember
> WHY past-you committed to something — patterns.md captures the
> *what* and *how*; this file captures the *when* and *why*.
>
> **Enforced**: `pre-commit-decisions-append-only.sh` blocks any
> commit that removes or modifies an existing entry. Edits to past
> entries fail the pre-commit hook with a plain-English error.
>
> **Format**: each entry is one Markdown level-2 section:
>
> ```
> ## <ISO-Z timestamp>  [<work-item-id>]  <playbook>/<sub-action>
> <one-paragraph summary in plain English of what was decided>
> Hash: <sha256 if section was approved> (optional)
> ```
>
> Append entries with `>>` from the agent's command. Never `>` (would
> overwrite). Never edit manually unless re-creating the whole file
> from scratch — and that should be a one-time `[SDD] decisions: reset`
> commit, never a routine operation.

<!-- entries below this line; do not edit existing lines, only append -->

## 2026-04-27T18:44:40Z  [phase-b-1]  framework-uat/full-ux

SDD v0.8 Phase B-1 Full UX UAT executed by Sam Serra against post-`d8b1c9d`
framework state (T64 BLOCKER fix landed). All 8 scenarios passed: T64
re-validation, /start happy path, /next plain-English bundling,
advance.sh stage transition, decisions.md append-only, /start unknown
playbook, patterns.md size cap, trust boundary (malicious INDEX.md). 5
B-2 candidates surfaced — none block ship: advance.sh pwd fallback,
missing § number after advance, INDEX.md template leftover, /start
unknown-playbook conversational message, decisions.md hook leftover-
state surprise. Trust-boundary teaching (S8) and decisions.md append-
only error UX (S5) flagged as gold-standard examples worth featuring in
release notes. v0.8.0 approved for ship from a UX standpoint by Sam.
Full handoff archived at `.uat/2026-04-27-phase-B-1.md`.
