---
type: action
slug: playwright-explore
tag: AGENT-LED
prelude_refresh: true
title: "Playwright-driven exploration"
short_label: "§14 Playwright exploration"
steps:
  - { id: pe-run,    action: draft, field: "§14.findings" }
  - { id: pe-triage, action: ask,   field: "§14.triage" }
used_by: [feature]
references: [acceptance-criteria, edge-case-sweep, adversarial-review, verify-test-run]
touches: [".sdd/<work-item>/spec.md", ".sdd/<work-item>/wireframe.html"]
trust: framework
budget:
  max_minutes: 15
  max_tokens: 6000
  max_commits: 2
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Tests are GREEN. `adversarial-review` re-read the spec and the diff. Now the explorer **drives the actually-deployed feature** in a real browser, looking for edge cases the spec author didn't think of. This is the empirical layer that pairs with adversarial-review's analytical layer.

The work happens through the `playwright-explorer` MCP server. The agent doesn't write Playwright scripts by hand — it calls the `explore` tool, gets back structured findings, and walks the user through triage.

Two atomic steps + commits: first the agent runs the explorer and captures the findings list, then the user triages each finding `add` / `drop` / `later`.

---

## Part 1 — Run the explorer (`§14.findings`)

The agent calls the MCP server's `explore` tool. Inputs come from the project's existing config + the active feature:

- **`url`** — the deployed feature URL. Read from `## Running services` in `.sdd/stack.md`, joined with the feature's slug. If `stack.md` doesn't have a Running services section, the agent asks the user once for the URL and writes it back to `stack.md`.
- **`spec_path`** — the active feature's `spec.md` (the explorer reads §11 ACs to score finding coverage).
- **`provider`** — read from `parameters.playwright_explorer.provider` / `endpoint` / `model` in `.sdd/config.md`. If unset, the agent prints the config block (the `enable.sh` printed it on first install) and waits for the user to fill it in.
- **`auth_cookie`** — optional. Read from `parameters.playwright_explorer.auth_cookie` if the deployed feature is behind auth.
- **Budgets** — `max_llm_calls_per_run`, `max_browser_actions_per_session`, `cost_limit_usd` — all read from the same config block.

The explorer cycles the LLM through 8 edge-case categories — **empty / max / bad-input / network / concurrency / auth / mobile / time-based** — at 3 attempts per category by default. Total: 24 LLM calls per run minimum (well under the default 50-call budget).

**Cost ceiling:** the run halts cleanly the moment any of the three budgets is exhausted. The halt reason (`llm_budget` / `browser_budget` / `cost_budget` / `complete`) is reported in the `stats` block of the response.

**Output:** the explorer returns `{found, uncovered, items, stats}`. Each `item` has `category`, `repro_steps` (so a human can reproduce manually), `expected`, `actual`, `severity`, `covered_by_ac` (None if no §11 AC overlaps), and `ac_link` (a `[[ac:<slug>]]` wiki-link suggestion the user can lift into spec.md).

The agent fills `spec.md` under `### playwright-explore / findings` with the numbered list. Each entry mirrors the `edge-case-sweep` template but is rendered from the live findings instead of the agent's imagination:

```text
<n>. **<short name>** [<category>] [<severity>] — <actual> — repro: `<step 1> → <step 2>` — proposed AC: `<proposed_ac>` — link: `[[ac:<slug>]]`
```

Findings whose `covered_by_ac` matches an existing AC get a `(covered by AC<n>)` tag in plain text instead of a new wiki-link — the user can confirm coverage at triage.

**Stats footer.** The agent appends the `stats` block to the same section as a one-line summary so the user sees what the run consumed:

```text
Stats: <llm_calls>/<llm_budget> LLM calls · <browser_actions>/<browser_budget> browser actions · ~$<cost_usd> · halt: <halt_reason> · attempts: empty=<n>, max=<n>, ...
```

**Commits with**: `spec.md` only.

**End the turn with:** *"Drafted N findings (X uncovered, Y covered by existing ACs). Reply `triage` to walk through them."*

---

## Part 2 — Triage (`§14.triage`)

The user walks each finding `add` / `drop` / `later` — the same shape `edge-case-sweep` uses, so the language is already familiar.

### `add` (the default for uncovered findings)

This is a real edge case the spec missed. The agent does four things in order, mirroring `adversarial-review`'s `fix now` flow:

1. Appends the proposed AC to §11 of `spec.md` (verbatim from the finding's `proposed_ac` text, with `AC<n>` resolved to the next free number).
2. Appends a `[BUG]` task to `plan-decompose` quoting the finding's `repro_steps` so the BUILD task has a deterministic acceptance criterion.
3. Runs `bash .sdd/scripts/revert-phase.sh <spec-path> SHIP BUILD` — flips `[PHASE: SHIP]` back to `[PHASE: BUILD]` and un-ticks all step rows under `## PHASE: SHIP`. Without un-ticking, the second BUILD→SHIP transition would walk a fully-ticked SHIP body and skip straight to SHIPPED, so playwright-explore would never re-fire on the new code.
4. Commits the revert (new AC + new BUG task + phase flip + un-ticked SHIP rows in one commit).

After the commit, normal BUILD discipline kicks in: test-first, RED→GREEN→commit. Once the BUG task is GREEN, the framework transitions BUILD→SHIP and the entire SHIP phase (including a SECOND playwright-explore pass) re-fires on the NEW code. The loop is the design — exploration runs against the latest deploy, not the old one.

### `drop` (real, but not real enough to ship work over)

The user has decided this finding isn't worth covering. Common reasons: the explorer's `expected` was too strict, the `actual` is desired behaviour the LLM mis-judged, the finding is a duplicate of a covered AC the heuristic missed.

The agent records the drop in `spec.md` under `### playwright-explore / triage` as one line:

```text
<n>. drop — <one-line reason from the user>
```

Nothing else changes. No new AC, no new task, no phase revert.

### `later` (real concern, but not for this iteration)

Same discipline as `edge-case-sweep`'s `defer`: the finding is real but the user has explicitly decided not to handle it in this ship. The agent appends it to `### Deferred edge cases` in §14.5 of spec.md so the next iteration or a follow-up feature can pick it up. The user must give a non-trivial reason — the agent rejects single-word deferrals (`"ok"`, `"later"`) and asks again.

```markdown
### Deferred edge cases

- <finding name> [<category>] [<severity>] — reason: <user's reason> — link: `[[ac:<slug>]]`
```

### Hard gate on `high` severity

Findings the explorer flagged `high` (currently triggered by network errors) follow the stricter rule from `adversarial-review`:

- **`add` is the default.**
- **`later` is REFUSED.** The agent says: *"This is a high-severity finding. High-severity findings can't be deferred. The only valid triages are `add` or `drop` with an explicit reason. Which do you pick?"*
- **`drop`** is allowed but requires a non-trivial reason that the agent records in `decisions.md` with the word `accepted-explorer-finding` so the entry is grep-able for future audits.

### When the user is unsure

If the reply is ambiguous (`"hmm"`, `"skip"`, `"not sure"`), the agent does NOT silently skip — that breaks foundation 3 (never assume). It asks in plain English:

> "Three options for finding `<n>`:
> 1. **`add`** — landfresh AC + new BUILD task; we go back to BUILD and re-loop SHIP.
> 2. **`drop`** — discard it; tell me why so I can record the reason.
> 3. **`later`** — real, but not for this ship; give me a non-trivial reason and a trigger to revisit.
>
> Which one?"

The agent waits for an explicit pick. No silent defaults.

### Output

Fill `spec.md` under `### playwright-explore / triage` with one line per finding:

```text
<n>. <severity>: <add | drop | later> — <one-line decision summary>
```

If any `add` lands, the spec also has new entries in §11 (the AC) and §10 plan-decompose (the BUG task), and the phase flag is back to `[PHASE: BUILD]`.

**Commits with**: `spec.md` + any of `plan-decompose` / `decisions.md` / `wireframe.html` that changed. One commit per file changed (atomic-step rule).

---

## Wiki-link emission (graph foundation)

This action emits `[[ac:<slug>]]` cross-references following the framework's wiki-link grammar (see `CLAUDE.md` "Wiki-link grammar"). Each finding's `ac_link` field comes from the explorer; the action writes them verbatim into spec.md so the graph cache resolves them at the next stop-hook lint.

The slug is derived from the finding's short name (lowercase, hyphen-separated, max 60 chars). Cross-file slug collisions are fine (different nodes); same-priority same-slug = stop-hook violation per invariant 8.

---

## Why it matters (non-technical reviewer language)

`adversarial-review` reads the spec + the code with a hostile-reviewer hat. It catches what could go wrong in theory.

This action **drives the deployed app in a real browser** and tries to break it. It catches what actually goes wrong in practice — the empty form that crashes the page, the 30-second timeout that hangs the submit button, the auth boundary that lets a logged-out user paste a private URL. Things the spec didn't think to test because the spec author hasn't actually used the feature yet.

The cost ceiling is the bargain: at most a buck per run, at most 50 LLM calls, at most 200 browser actions. Predictable, bounded, repeatable. If the budget runs out, the explorer summarises what it found so far and exits cleanly — no runaway.

**What it looks like:**

Let me drive a real browser through the deployed feature and try weird inputs to find bugs you didn't think of.

Example: *"I'll explore the signup form across 8 categories — empty submission, max-length input (5000-char email), special characters in the name, slow network, double-submit, signup-while-logged-in, mobile viewport at 320px, time-based (signup at 11:59pm crossing midnight). For each category I try 3 attempts. I report what crashed, what looked weird, and which AC each finding maps to."* Findings become new ACs in the next iteration.

**End the turn with:** `Reply approve when triage complete.`
