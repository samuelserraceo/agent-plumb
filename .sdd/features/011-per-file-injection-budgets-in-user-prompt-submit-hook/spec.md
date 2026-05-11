---
playbook: feature
---

# per-file injection budgets in user-prompt-submit hook

[PHASE: SPEC]

**Active blocker:** §1 (first action: brief-intake)

## PHASE: SPEC

### action: brief-intake

- [x] brief: agent-authored — replace 16K total-cap + truncate-from-end with per-file budgets so each corpus file (INDEX/spec/principles/stack/data-model/patterns) gets its own char allocation; overflow truncates individually with a sentinel. Closes idea 003's full-reorder prerequisite (#228 shipped INDEX-live filter as partial)

**§0 Brief intake**

Recap (3 bullets):

1. **Problem:** `user-prompt-submit.sh` today injects all corpus files (INDEX, spec, principles, stack, data-model, patterns) up to a single 16K total cap, then truncates from the end. On mature SDD projects patterns.md alone is 20KB; the last file in injection order gets cut entirely or mid-content. Agent loses visibility of accumulated lessons + active state.
2. **Fix:** new per-file budget map in `config.md` (`parameters.injection.per_file_budget_chars`), each file truncated individually to its budget with a `[truncated to <N> bytes — re-read explicitly]` sentinel. Total `cap_total_chars` stays as safety net. Defaults: INDEX=3K, spec=5K, principles=2K, stack=3K, data-model=3K, patterns=4K — ~20K total (over the 16K-only-cap floor, but the cap stays as a safety-net).
3. **Closes:** idea 003 full-reorder prerequisite from yesterday's brainstorm (#228 shipped the INDEX-live filter; this is the principled-allocation fix that the reorder needs to actually work without dropping INDEX/spec).

### action: problem

- [x] who: SDD framework maintainers and downstream users on mature projects — Sam first (patterns.md is 20KB on this repo today, gets silently cut mid-paragraph every turn), downstream users hit the same problem as their patterns.md grows
- [x] why-now: patterns.md hit 20KB on this repo this week (4 features shipped 2026-05-10/11 each adding lessons); #228 shipped the INDEX-live filter as the small win, but the full idea-003 reorder is blocked on this because today's "truncate from end" drops INDEX+spec entirely when stable corpus is reordered to the top — per-file budgets unblock the reorder
- [x] what-breaks: agent loses memory of accumulated patterns (cut mid-paragraph or entirely); idea 003's stable-first cache reorder can't ship (would push INDEX+spec off the cap and lose active state); patterns.md keeps growing so the truncation gets worse every shipped feature

### action: user-stories

- [x] stories: 3 stories — Sam wants per-file budgets so patterns.md doesn't silently lose mid-paragraph content; downstream user wants budgets configurable per-project (their patterns might be smaller); AI agent wants every corpus file at least partially visible so it doesn't propose things that contradict patterns it can't see

**User stories**

1. **As** Sam (framework maintainer on a mature project where patterns.md is 20KB), **I want** the user-prompt-submit hook to give each corpus file its own size budget instead of cutting from the end, **so that** patterns.md doesn't keep losing mid-paragraph content every turn as it grows.
2. **As** a downstream SDD user with a different project shape (e.g. patterns.md small, data-model.md huge), **I want** to override the default per-file budgets in my project's `config.md`, **so that** the budgets match what my project actually needs to see most.
3. **As** the AI agent running the session, **I want** every corpus file to appear at least up to its budget in the injection (present rather than dropped wholesale), **so that** I don't silently propose something that contradicts patterns I can't see.

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — non-UI feature (hook script + config schema change; no user-facing surface beyond config.md edits)

### action: proposed-approach

- [x] approval: Approved approach (A) — per-file budget map in `templates/.sdd/config.md` under `parameters.injection.per_file_budget_chars`. Each corpus file truncated to its own budget individually with a sentinel; existing `cap_total_chars` stays as a safety net. Recommended defaults: INDEX=3000, spec=5000, principles=2000, stack=3000, data-model=3000, patterns=4000. Approved 2026-05-11 with explicit anti-theatre constraint (every numerical / enforcement claim below carries a verifier annotation).

**Recommended approach (A — per-file budgets):**

Replace the hook's single-cap + truncate-from-end logic with a per-file budget map. Each corpus file (INDEX, spec, principles, stack, data-model, patterns) gets its own char allocation in `templates/.sdd/config.md`. When a file exceeds its budget, the hook truncates that file individually and appends a sentinel marker — no file is dropped from the injection. The existing `cap_total_chars: 16000` stays as a defensive safety net (a floor applied to combined output if budgets overshoot).

**Why this answers §1-3:**

- **§1 problem (patterns mid-paragraph cuts):** patterns.md gets a dedicated allocation regardless of where it sits in the injection order. {verify-by: T-NNN injection-fixture asserts patterns.md content present up to its declared budget when patterns.md exceeds budget on disk}
- **§1 reorder blocker:** idea 003's stable-first cache reorder becomes safe — even if INDEX moves to the bottom of the injection order, it still gets its allocation. {verify-by: T-NNN reorder-fixture asserts INDEX content present after stable-first reorder when all 6 corpus files exceed their budgets}
- **§3 every-file-visible:** each corpus file appears in the injection up to its budget, so the agent sees at least part of each corpus piece. {verify-by: T-NNN multi-file-overflow fixture asserts ≥1 line of each corpus file present in injection output after truncation}

**Moving parts (4):**

1. **New config block** in `templates/.sdd/config.md`:
   ```yaml
   parameters:
     injection:
       cap_total_chars: 16000      # existing safety net, kept as a floor
       per_file_budget_chars:
         INDEX: 3000
         spec: 5000
         principles: 2000
         stack: 3000
         data-model: 3000
         patterns: 4000
   ```
   Defaults sum to a declared total of 20000 chars. {verify-by: T-NNN sums per_file_budget_chars defaults and asserts == 20000}

2. **Hook rewrite** in `templates/.claude/hooks/user-prompt-submit.sh`: replace the single-cap end-truncate block with a per-file loop. For each corpus file: read content, apply that file's budget, append the sentinel marker if truncated, concatenate. The existing INDEX-live filter from #228 stays in place upstream of the budget step. {verify-by: T-NNN hook unit test compares output to a golden injection fixture}

3. **Sentinel marker** appended when a file is truncated: `[truncated to <N> bytes per per-file budget — re-read with the Read tool if you need the cut portion]`. Tells the agent (a) the file was cut, (b) by how much, (c) the recovery path. {verify-by: T-NNN asserts sentinel string presence + byte-count substitution on a truncation fixture}

4. **Resolver helper** to read the per-file map from `config.md` with fallback to defaults — extends the existing `.sdd/scripts/resolve-parameters.sh` pattern. Unknown keys (e.g. a future corpus file added before its budget entry lands) fall back to a documented default char count. {verify-by: T-NNN resolver returns default for unknown key + project override for known key}

**Alternatives considered (3):**

- **(B) Raise the total cap via env var.** What it is: `export SDD_INJECTION_CAP_CHARS=32000` doubles today's single cap. Why not: it's the workaround Sam rejected — patterns.md is already large {verify-by: `wc -c .sdd/patterns.md` returns a value over 16000 on this repo at HEAD} and growing; doubling the cap once does not fix the underlying truncate-from-end behavior. The next corpus file added (or further patterns.md growth) hits the same wall.
- **(C) Tail-truncate for patterns.md specifically.** What it is: keep the single cap, but truncate patterns.md from its head instead of its tail (so the most recent patterns survive). Why not: patterns.md uses chronological order top-down — head-truncation would drop the foundational patterns, which is worse. Could be revisited later as a per-file truncation-direction option, but is not the first move.
- **(D) Enable Tier 3 (LLM-driven synthesis) for context injection.** What it is: feature 001's Tier 3 (currently `enabled: false` on this project) would synthesise corpus content into a summary before injection — the architectural answer to "the corpus is too big to dump." Why not: Tier 3 enablement is a separate decision on its own merits (latency, cost, accuracy trade-offs); per-file budgets fix the immediate truncation problem without that wider commitment. {best-effort: Sam at SHIP, comparing Tier 3 enablement vs per-file budgets on a 5-turn dogfooding session}

**What we trade off:**

- **Cost:** zero infra cost (config + bash change). Slight increase in injection size from the prior 16K floor to up to ~20K when each file maxes out its budget. {verify-by: T-NNN sum-of-budgets test asserts declared total == 20000}
- **Complexity:** hook gains a per-file loop. Config gains one nested map. Resolver gains one fallback. All three are localised.
- **Time-to-ship:** small — one config change + one hook change + one resolver helper + tests.
- **Debt:** if downstream users want per-file truncation *direction* (head vs tail) the schema needs another field later. Acceptable; revisit if anyone asks. {best-effort: Sam at SHIP, ack the deferral in §9 out-of-scope}

**Key technical choices for sign-off (3):**

1. **Per-file budgets live in `config.md` under `parameters.injection.per_file_budget_chars`.** Project-level override matches the v1.4 parameters convention — downstream users edit `config.md`, not the framework hook. Risk: schema drift if framework adds a new corpus file (e.g., a future `glossary.md`) — mitigated by the resolver falling back to a documented default for unknown keys. {verify-by: T-NNN unknown-key fallback test}

2. **Sentinel marker is human-readable and actionable.** The string `[truncated to <N> bytes per per-file budget — re-read with the Read tool if you need the cut portion]` tells the agent the file was cut, by how much, and how to recover. Risk: the agent ignores the sentinel and proposes against unseen content — mitigated by an AC that asserts the sentinel string is emitted whenever a corpus file is truncated. {verify-by: T-NNN sentinel-emission AC}

3. **`cap_total_chars` stays as a safety net floor.** Even with per-file budgets summing to ~20K, the cap remains as a defensive floor applied to combined output (in case a future corpus file is added without a budget entry, or budgets are mis-edited upward). Risk: the cap fires unexpectedly on a sum-overshoot edge case — mitigated by an AC that documents and tests the cap behavior when budget-map total > cap. {verify-by: T-NNN cap-overshoot AC}

**Out of scope here (deferred to follow-up features):**

- **Idea 003 full reorder** — stable-first cache reorder of injection sequence is a separate feature unlocked BY this one, but not bundled in.
- **Tier 3 enablement** — separate decision (see alternative D).
- **Per-file truncation direction** (head vs tail) — additive schema change; revisit if anyone needs it.

### action: data-contract

- [x] approval: No new project-state entities. One new framework-level concept added to `.sdd/data-model.md` during BUILD: [[entity:InjectionBudget]] — a config block under `parameters.injection.per_file_budget_chars`, analogous to [[entity:Tier3Config]]. Existing `cap_total_chars` field stays as a sibling. No relations added or removed. Approved by Sam 2026-05-11 with the same anti-theatre constraint as §5.

**Data contract:** No new project-state entities. Per-file budgets live in the framework's existing `parameters.injection` config block — a sibling of `cap_total_chars` rather than a new state file or table. This is pure framework-config plumbing: the brief's user stories (1-3) describe an injection-behavior change, not a project-data change.

| Layer | Change | Why |
|---|---|---|
| **Project state** (spec.md, INDEX.md, decisions.md, patterns.md, principles.md, data-model.md, stack.md, .sdd/features/**, .sdd/bugs/**) | No changes | Per-file budgets are framework-level config, not project content |
| **Framework data-model.md** | One addition: [[entity:InjectionBudget]] (analogous to [[entity:Tier3Config]]) | Distributable shape the framework should describe so future work knows it exists |
| **Existing entities** ([[entity:Action]], [[entity:Hook]], [[entity:Tier3Config]]) | No new fields | The new entity is a peer, not an extension |
| **Relations** | None added / removed | Reuses existing Hook → resolve-parameters.sh wiring |

**New framework entity** (to be added to `.sdd/data-model.md` during BUILD):

> **InjectionBudget** — a config block under `parameters.injection` in `templates/.sdd/config.md`. Two fields: (1) `cap_total_chars` (existing) — defensive safety-net floor applied to combined hook output; (2) `per_file_budget_chars` (new) — a map keyed by corpus-file basename (INDEX, spec, principles, stack, data-model, patterns) to char-count budgets. Read by `templates/.claude/hooks/user-prompt-submit.sh` via `templates/.sdd/scripts/resolve-parameters.sh`. Unknown keys fall back to a documented default char count. Same shape pattern as Tier3Config (foundation 3 — framework defines the schema; downstream projects override in their own `config.md`). {verify-by: T-NNN resolver test returns project override for known key and documented default for unknown key}

**Wire-level shape:**

```yaml
# templates/.sdd/config.md
parameters:
  injection:
    cap_total_chars: 16000              # existing — safety-net floor
    per_file_budget_chars:              # NEW
      INDEX: 3000
      spec: 5000
      principles: 2000
      stack: 3000
      data-model: 3000
      patterns: 4000
```

**Edge cases at the data layer (asked-and-answered):**

1. **Downstream project overrides only some keys.** Project `config.md` lists `per_file_budget_chars: {patterns: 10000}` only. Resolver merges: declared key wins, unspecified keys fall back to framework defaults — no partial-merge surprises. {verify-by: T-NNN partial-override fixture}
2. **A future corpus file gets injected without a budget entry.** Resolver returns a documented default char count for unknown basename keys. The new file appears in injection within that default budget rather than being dropped or unbounded. {verify-by: T-NNN unknown-key default fixture}
3. **Project sets `per_file_budget_chars: null` or omits the block entirely.** Resolver returns framework defaults for each corpus file (same as `templates/.sdd/config.md`'s declared defaults). No null-deref path. {verify-by: T-NNN missing-block fixture}
4. **Sum of per-file budgets exceeds `cap_total_chars`.** Defensive floor still applies to combined output — per-file truncation runs first, then the total-cap clip handles sum-overshoot at the end. Documented as a behavior note on the [[entity:InjectionBudget]] description. {verify-by: T-NNN cap-overshoot AC asserts combined output ≤ cap_total_chars when sum-of-budgets > cap}

### action: flows

- [x] flows: 2 critical flows — (1) hook injection with per-file budgets (covers stories 1 + 3); (2) downstream project overriding budgets (covers story 2). Approved by Sam 2026-05-11 with same anti-theatre constraint.

**Flows (2 critical, mapped to user stories):**

### Flow 1 — Hook injection with per-file budgets (stories 1 + 3)

```text
1. Sam (or any user on a project with .claude/hooks/user-prompt-submit.sh
   wired) types a prompt in Claude Code.
2. user-prompt-submit.sh fires BEFORE the prompt reaches the model.
3. Hook reads per-file budgets via resolve-parameters.sh:
     parameters.injection.per_file_budget_chars
     → {INDEX:3000, spec:5000, principles:2000, stack:3000,
        data-model:3000, patterns:4000}
4. Hook iterates the corpus injection order:
     a. INDEX.md  → live-filter via awk '/^## Shipped/ {exit} {print}'
                    (#228), then apply 3000-char budget.
     b. active spec.md → apply 5000-char budget.
     c. principles.md → apply 2000-char budget.
     d. stack.md → apply 3000-char budget.
     e. data-model.md → apply 3000-char budget.
     f. patterns.md → apply 4000-char budget.
5. For each file whose pre-budget content exceeds its budget:
     - keep first <budget> chars
     - append sentinel line:
       [truncated to <N> bytes per per-file budget — re-read with
        the Read tool if you need the cut portion]
6. Concatenate all files (each capped to its budget + optional sentinel).
7. Defensive cap_total_chars: if combined output still exceeds 16000
   (e.g. sum-overshoot edge case), apply the existing total-cap clip
   to the tail. Documented as the safety-net path.
8. Inject the concatenated text as [PROJECT DATA] alongside the
   user's prompt. The model sees every corpus file up to its budget
   plus a sentinel when truncated.
```

**What's different from today's hook:** today's logic concatenates all corpus files into one string, then truncates the END of that string at 16000 chars — so patterns.md (last in order, 20KB on this repo) gets cut mid-paragraph or wholesale. The per-file loop replaces step 5's behavior so each file's truncation is independent of the others' sizes. {verify-by: T-NNN compares output of today's hook vs new hook on a fixture where patterns.md > 16KB}

**Acceptance signal for this flow:** the agent sees a sentinel string when truncation happens, plus at least the first <budget> chars of each corpus file. {verify-by: T-NNN sentinel-presence AC on a multi-file-overflow fixture}

### Flow 2 — Downstream project overrides budgets (story 2)

```text
1. Lucia (downstream SDD user) clones the framework into her project;
   her patterns.md is small (3KB) but data-model.md is huge (12KB).
2. She edits her project's .sdd/config.md and adds:
     parameters:
       injection:
         per_file_budget_chars:
           patterns: 2000     # her patterns are small; tight budget is fine
           data-model: 8000   # she wants more of her data-model visible
3. She runs any /next or types a new prompt.
4. user-prompt-submit.sh fires.
5. resolve-parameters.sh reads HER config first, merges:
     - patterns: 2000   (her override)
     - data-model: 8000 (her override)
     - INDEX, spec, principles, stack: framework defaults
6. Hook applies the merged map per Flow 1.
7. Lucia sees data-model.md content up to 8000 chars in injection
   on this turn; patterns.md truncated at 2000 chars with sentinel.
```

**What's different from today's hook:** today there is no per-file budget map — only the single `cap_total_chars` (which itself has an env-var override but no per-file shape). Lucia today can either accept the framework default (16K total, end-truncated) or set `SDD_INJECTION_CAP_CHARS=N` (still single-cap shape). The per-file map gives her granular control without changing the framework hook code. {verify-by: T-NNN partial-override fixture asserts merged map matches expected}

**Acceptance signal for this flow:** resolve-parameters.sh returns Lucia's override for declared keys + framework defaults for the rest; hook applies the merged map. {verify-by: T-NNN partial-override fixture}

### action: dependencies

- [x] deps: Zero new external services, zero new local dependencies, zero marginal cost. Reuses bash/python3/awk/head/wc already pulled in by existing SDD scripts. Approved by Sam 2026-05-11 with same anti-theatre constraint.

**Dependencies:**

**Zero new external services.** This is a local-only feature — the user-prompt-submit hook runs inside the Claude Code process before each prompt reaches the model. No network, no API calls, no paid SaaS.

**Zero new local dependencies.** Everything the new code needs is already pulled in by existing scripts:

| Dependency | Status | What it's used for here |
|---|---|---|
| `bash` (>= 3.2, mac default) | Already required by every SDD hook + script | Per-file truncation loop in `user-prompt-submit.sh` |
| `python3` + standard library | Already required by `resolve-parameters.sh`, `hash-section.sh`, `pre-commit-stage-verified.sh`, etc. | YAML parsing for the new `per_file_budget_chars` map (via `resolve-parameters.sh`) |
| `awk` (BSD or GNU) | Already used by the live-INDEX filter shipped in #228 | INDEX live-filter step is upstream of the per-file budget step in Flow 1 |
| `head` / `wc` (coreutils) | Already used elsewhere in the hook | Char counting + first-N-bytes truncation |

**Zero new optional dependencies.** No PyYAML, no `yq`, no `jq` upgrades — `resolve-parameters.sh` already implements its own YAML walking via inline Python (PyYAML if available, else a soft-fail per the v0.8 minimal-Python pattern). The per-file-budget map sits at the same nesting depth as existing `parameters.mcp.tier3.*` keys and uses the same walker.

**Pricing math:** $0 marginal cost. Zero infra spend, zero per-turn cost — the hook reads local files, computes char counts, writes the concatenated output. No external billable surface. {verify-by: code review — there is no network call added by this feature} {best-effort: Sam at SHIP, confirms no `curl` / `wget` / API client added under templates/.claude/hooks/ or templates/.sdd/scripts/}

**Success-volume scaling note:** the hook runs once per UserPromptSubmit event. The new per-file loop is O(6) (one pass per corpus file) with O(N) char-counting per file, where N = budget cap (≤ 5000 chars per declared default). Worst-case per-turn cost is bounded by the size of the corpus directory, which is bounded by the per-file budgets themselves. There is no fanout or recursion path. {verify-by: T-NNN micro-benchmark asserts hook completes in under a small bounded time for a corpus where every file maxes its budget}

**External-service exposure summary:** none. This feature does not touch any of the existing parameters.mcp.* config blocks (Tier3, semantic_search, Playwright-explorer) or their cost ceilings. The `parameters.injection.*` block is the only block edited here, and it has no external-service dependency by construction.

### action: out-of-scope

- [x] list: 4 explicit deferrals (each: name + reason)
- [x] approval: Approved by Sam 2026-05-11. 4 deferrals locked: idea 003 full reorder, Tier 3 enablement, per-file truncation direction, token-aware budgets.

**Out of scope this round (4 explicit deferrals):**

1. **Idea 003 full stable-first cache reorder** — reordering the corpus injection sequence so stable files come first (cache-friendly) and the variable turn comes last is the bigger speed win this feature unblocks. Reason it is not bundled: per-file budgets are the prerequisite (today's truncate-from-end would drop INDEX+spec entirely if the order flipped). Reorder ships as a separate feature once 011 lands. {verify-by: separate feature ID will be issued when 011 ships}

2. **Tier 3 (LLM-driven synthesis) enablement** — `parameters.mcp.tier3.enabled: true` would replace the corpus-dump injection with an on-the-fly synthesised summary. Reason it is not bundled: separate decision on its own merits (latency, cost, accuracy trade-offs); Sam wants per-file budgets as the immediate truncation fix without that wider commitment. {best-effort: Sam revisits Tier 3 enablement at the next idea-001 review}

3. **Per-file truncation direction (head vs tail)** — today the per-file truncation keeps the first <budget> chars. A future schema addition could let downstream users pick head vs tail per file (e.g. patterns.md might want tail-kept once it has stable foundational sections at the top). Reason it is not bundled: additive schema change; revisit when a downstream user asks. {best-effort: Sam at the next downstream-user request}

4. **Token-aware budgets** — `per_file_budget_chars` is char-count based, not token-count based. Reason it is not bundled: char-counting is provider-agnostic and bash-native; token-counting needs the provider's tokenizer (different per model). Char-budgets are a useful approximation; token-aware is a follow-up if measurement shows the approximation is too loose. {best-effort: Sam at SHIP — empirical check whether the char→token ratio holds for the corpus files on this project}

### action: non-functional

- [ ] constraints: draft performance, security, and compliance constraints

### action: acceptance-criteria

- [ ] approval: draft the acceptance criteria, run a constraint-coverage check vs §4, iterate, get approval

### action: signoff-steps

- [ ] manual-steps: What manual smoke tests do YOU need to do before SHIP, beyond the automated tests? 1-5 bullets.

### action: wireframe

- [ ] wireframe: draft wireframe.html — UI screens for UI features OR flow + architecture for non-UI features

### action: plan-decompose

- [ ] tasks: convert acceptance criteria into ordered build tasks (one test file per task)

### action: edge-case-sweep

- [ ] ec-sweep: draft
- [ ] ec-pick: ask

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"
