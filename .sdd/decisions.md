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

## 2026-05-01T14:44:40Z  [[001-tier-3-llm-driven-synthesis]]  feature/data-contract

Approved the §6 data contract: two new framework-domain entities introduced — SynthesisCache (derived JSON cache at .sdd/.cache/synthesis.json, gitignored, keyed by (question_hash, corpus_signature), invalidated lazily on corpus signature flip) and Tier3Config (parameters.mcp.tier3 config block, opt-in, off by default, no baked-in defaults). data-model.md synced in the same commit with both entities and two new relationships. SQLite-as-cache and question-only-keying alternatives explicitly rejected (foundation 1 and cache-warmth respectively). The contract requires no changes to existing v1.0 graph nodes or query layer — Tier 3 reads them cleanly.

Hash: 5359e2a31bc0b688ca3956cac7625e7e2ff7d6dbf54c55c5b45f66cb1d4864bd

## 2026-05-01T14:54:41Z  [[001-tier-3-llm-driven-synthesis]]  feature/proposed-approach (re-approved)

Re-approved §5 with anti-theatre fixes (issue [#111](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/111) doctrine applied for the first time): dropped `cost_limit_usd` (framework can't price external services — no per-provider pricing table, no live ledger). Replaced with mechanically-countable caps: `max_calls_per_run`, `max_input_tokens_per_call`, `max_total_tokens_per_run`. Softened "no invention" to "no invented citations" (cite-check catches invented `[[link]]`s; misattributed quotes with real citations are reader-eye check, not mechanical). Softened "must verify in SHIP" on ambiguity-surfacing and empty-corpus handling to "best-effort prompt design, verified on ~5 representative test cases at SHIP" — these depend on prompt + LLM behaviour, can't be enforced over unseen corpora. USD cost projections moved to clearly-labelled informational block, separated from enforced config fields.

Hash: b183047ce7bfa28e134bfc35f81efc30712a8aa5142b8dd2303de28a59d8b705
Reason: anti-theatre audit (Sam, 2026-05-01) — every claim must declare its verification path or be softened.

## 2026-05-01T14:54:41Z  [[001-tier-3-llm-driven-synthesis]]  feature/data-contract (re-approved)

Re-approved §6 with anti-theatre fixes: Tier3Config schema replaces `cost_limit_usd` with the three mechanically-countable caps (calls, input tokens per call, total tokens per run). Schema explicitly notes the framework cannot enforce USD limits without per-provider pricing tables. data-model.md synced with the new field list and the absent-USD-field rationale.

Hash: 876b2c0739f8c1d268db95c165c9f61813795008094392206812e40b69ef06b8
Reason: anti-theatre audit (Sam, 2026-05-01) — same as proposed-approach above.

## 2026-05-01T15:38:53Z  [[001-tier-3-llm-driven-synthesis]]  feature/out-of-scope

Approved 5 explicit out-of-scope items for v1.1 Tier 3: (1) fuzzy / similar-question cache matching — exact-match only, fuzzy parked to v1.2 due to wrong-answer risk; (2) recursive / RLM-style flow — single-round only, recursion is a v1.2+ layer that sits on top of the v1.1 foundation; (3) catching misattributed quotes (semantic-truth check) — cite-check catches invented [[link]]s but not mischaracterised real ones; eye-check via click-through is the v1.1 protection; (4) pre-computed answers at /ship — explicitly rejected as Approach C in §5 because it breaks stories 3, 4, 5; (5) dollar-denominated cost limits — anti-theatre fix from earlier in the walk; framework enforces call/token caps, not USD. None are blocked forever — each can ship as its own work-item later if friction warrants.

Hash: 1904d0cf44b19a75aab3085f4f59d2a25782295f540ae4a19b754a8dce3b9114

## 2026-05-01T16:01:09Z  [[001-tier-3-llm-driven-synthesis]]  feature/acceptance-criteria

Approved 20 ACs covering Tier 3 v1.1 — 16 mechanical, 2 best-effort (declared with named test count), 2 PROD-ONLY (naturalness as human judgment, real-provider rate-limit confirmation). Sam pushed back twice on the draft: (a) wording was too technical (4th drift in this session — applied pre-flight check more aggressively in the redraft), (b) my own theatre re-check missed real theatre ("free" in AC#4 was dollar-language, "cost caps" in AC#6 was the same shape as the cost_limit_usd we removed, "real-looking key" in AC#11 was fuzzy, "about 1 KB" in AC#13 was inexact). All four theatre items fixed. New AC#20 added covering setup-wizard integration — Sam caught that §6's "set up tier3 config" was unsaid HOW; the answer is via extension of brick 007 (mcp-server). All §4 UX brief constraints have mapped ACs — Plan-decompose coverage check passes pre-emptively.

Hash: 80e2e2953623f58eed62535e453f1a480a36684acc39c545dc75f3fac585849c
