---
description: Capture a bug. (Phase C will ship a dedicated bug playbook; for B-1, /bug routes to /start with a [BUG] tag.)
---

$ARGUMENTS

A dedicated bug playbook is coming in Phase C — it'll skip PLAN and produce a smaller, faster bug-fix flow. **For B-1, capture bugs as features with a `[BUG]` tag in the title and §1 Problem.** The standard SPEC → BUILD → SHIP flow then handles them; you just leave the wireframe / UX brief / data-contract sections skipped if they don't apply.

## What to do

If `$ARGUMENTS` is non-empty (the user gave a bug description):

1. Tell the user in plain English: *"A dedicated bug flow is coming in Phase C. For now, I'll capture this as a feature with `[BUG]` in the title — same SPEC → BUILD → SHIP process, you just skip the sections that don't apply."*

2. Run (or tell the user to run): `/start [BUG] <bug description>`

If `$ARGUMENTS` is empty:

1. Ask: *"What's broken? Give me one sentence describing what goes wrong, plus the steps to reproduce it."*

2. When they answer, run `/start [BUG] <a one-line title summarising their answer>`.

The feature scaffolded by `/start` follows the standard playbook:
- §1 Problem — capture the reproduction steps + observed-vs-expected.
- §11 Acceptance criteria — write a regression test that fails on current code.
- BUILD — write the fix; the regression test goes RED → GREEN.
- §LEARN — record "why we missed it" so the same class of bug doesn't ship again.

Skippable sections (UX brief, dependencies, data-contract, wireframe) — use `/skip` with a one-line reason like "no UI surface — backend bug only" if they don't apply.

## End your turn

Per the call-to-action rules in `.sdd/CLAUDE.md`, end with an explicit next-action prompt. Example:

> Bug captured as feature `<id>-bug-<slug>` (or whatever ID `/start` assigned). First question: §1 Problem — what exactly is broken, and what are the steps to reproduce? Type your answer and I'll fill it in.
