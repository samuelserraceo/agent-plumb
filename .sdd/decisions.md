# SDD Decisions Log

> **Append-only event log.** Every approval, phase transition, and
> notable decision gets one entry. Future-you reads this to remember
> WHY past-you committed to something — patterns.md captures the
> *what* and *how*; this file captures the *when* and *why*.
>
> **Enforced**: `pre-commit-rules.sh` (via `file_rules: append_only`
> in `config.md`) blocks any commit that removes or modifies an
> existing entry. Edits to past entries fail the pre-commit hook
> with a plain-English error.
>
> **Format**: each entry is one Markdown level-2 section:
>
> ```text
> ## <ISO-Z timestamp>  [<work-item-id>]  <playbook>/<sub-action>
> <one-paragraph summary in plain English of what was decided>
> Hash: <sha256 if section was approved> (optional)
> ```
>
> Append entries with `>>` from the agent's command. Never `>` (would
> overwrite). If decisions.md is genuinely corrupt and needs rebuilding,
> that's a manual recovery operation outside the framework's contract —
> restore from a known-good commit, don't squash history forward.

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

## 2026-05-01T14:39:15Z  [[001-tier-3-llm-driven-synthesis]]  feature/proposed-approach

Approved Approach A (single-shot RAG with cite-check) plus an exact-match synthesis cache keyed by (question, corpus signature). The wiki-graph picks the documents to feed the model; the model answers with [[link]] citations; the cite-check rejects any answer whose links don't resolve in the graph cache. User-configured provider with cost ceiling — no baked-in defaults. Two render formats (structured for the agent, prose for chat) come out of one shared LLM call. Lazy escalation and pre-computed-at-ship were explicitly considered and rejected (state-dependent shape and broken §3 stories respectively). RLM-style recursion ([Zhang et al., MIT, Dec 2025](https://arxiv.org/abs/2512.24601)) is deferred to v1.2+ as a layer on top of the v1.1 single-shot foundation.

Hash: 2ba64f7fa326e43093413b1fc53f2acf62b9f01ee9a2339035fe7256fc6b17a0
