---
type: action
slug: success
tag: USER-LED
model_tier: thinking
prelude_refresh: true
title: "§2 Success"
short_label: "Success"
deprecated: true
deprecation_note: "Removed from feature.md playbook in v1.6 (PR-A of #207). Success metrics fold into §11 ACs by default for foundation/internal features. The Clickthrough QA pattern (#172, v1.5.1) is the canonical §11 AC shape for foundation work; for features with real numerical targets (signup conversion, latency budgets), §11 ACs handle that too — same section, two patterns. File kept for backward-compat with in-flight features whose spec.md was scaffolded before v1.6 landed."
steps:
  - { id: metric, prompt: "Pick a metric pattern (volume / speed / quality / engagement) or describe your own. Give a target number AND the current baseline if known.", field: "§2.verifiable-outcomes" }
used_by: [feature]
references: []
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

> **DEPRECATED in v1.6 — fold §2 Success into §11 Acceptance Criteria.** This action is no longer scheduled by `feature.md`'s SPEC actions list. If you've landed here from an in-flight feature scaffolded before v1.6 (PR-A of #207), the canonical path forward is: skip the §2 prompt and capture any success metric you'd write here as a §11 Acceptance Criterion instead — `AC<N>: <behaviour> ... {verify-by: T-NNN}`. The framework verifies §11 ACs mechanically via test pointers; §2 Success was market-shape prose the framework couldn't verify, so it was retired (idea 004, closed by F021). The prose below remains for backward-compat with pre-v1.6 spec.md scaffolds; new features should not see this action.

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list, binary yes/no). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

Ask: how will we know this worked? Push for **numbers, not vibes** — *but only when numbers are honest*. For foundation/gateway features (auth, canvas, infra, scaffolding) where there's no end-user funnel to measure, numerical metrics become theatre — see the 5th pattern below.

Offer 5 metric patterns (and a free-form escape):

- **Volume** — signups, orders, messages per day/week/month
- **Speed** — time to first action, response time, conversion rate
- **Quality** — NPS, error rate, support tickets, completion rate
- **Engagement** — DAU/WAU/MAU, retention curve, time in app
- **Clickthrough QA** *(closes #172)* — for foundation/gateway features where the right verification is human-judged at preview-deploy time, not a number. List specific behaviours as `M1`, `M2`, …, each annotated `{best-effort: <reviewer> at SHIP — what they check}`. Honest verification, not a softened number.
- **Or describe your own**

**When to propose Clickthrough QA *first*:** if the feature has no end-user-facing measurement surface (no funnel, no latency baseline, no error-rate signal yet) AND it's sized S or M (foundation features tend to be small) AND brief §3 persona explicitly trusts a human reviewer (e.g. *"reviews via clickthrough, not diffs"*), lead with this pattern. Don't force a numerical metric where none can honestly be measured — the user will push back and you'll have to redo §2.

**Format for Clickthrough QA metrics:**

```text
- M1: User can log in, land on /map, and see every database table as a card. {best-effort: Sam at SHIP — clickthrough on preview deploy, no synthetic traffic}
- M2: Each card click opens a panel showing the table's columns + first 50 rows. {best-effort: Sam at SHIP — manual test, ≥3 random tables}
```

User picks one or two and gives target numbers (or behaviours). If they say *"it works well,"* ask: *"What does 'well' look like — a number compared to a baseline, or a list of clickthrough behaviours a human will check on the preview deploy?"*

**Output:** fill `spec.md` under `### §2 Success` with one short paragraph per metric chosen — include the target number AND the current baseline if known, OR the list of `M1`/`M2`/… behaviours with their `{best-effort:}` annotations. Per CLAUDE.md (§170 directive on auto-annotation): every numerical metric line gets `{best-effort:}` / `{prod-only:}` / `{verify-by:}` annotation inline at record time. Capture the user's words; don't reframe.

**What it looks like:**

How will we know this worked? Give me a number, not a vibe.

Common patterns: **volume** (signups per month), **speed** (time from landing on the page to completing checkout), **quality** (NPS score, support-ticket rate), **engagement** (people coming back next week). Pick one or two and say where we are today (the baseline) and where we want to get to (the target). Or describe your own.

**End the turn with:** *"Run `/next` when you're ready to continue to §3 User stories."*
