---
playbook: feature
---

# parallel wave execution

[PHASE: SPEC]

**Active blocker:** §1 (first action: problem)

## PHASE: SPEC

### action: problem

- [x] who: Sam, when running BUILD phases with many small independent tasks (F008 lived this — 36 atomic commits, orchestrator context filled past turn ~50, small drift started landing). Future adopters too — pain scales with task count × task independence.
- [x] why-now: Three signals just lined up — F008 unlocked multi-model so sub-task delegation is now physically possible; F008 made the context-rot pain concrete (36 commits, 3 CR cycles, residual drift); GSD's proven parallel-wave pattern is mature prior art (Sam said live "I really want to execute" this during the GSD comparison).
- [x] what-breaks: Two compounding breaks — wall-clock time on big features (linear walk through 30+ independent tasks burns multiples of what it should); orchestrator context-rot past turn ~40-50 (small drift starts landing, only caught post-hoc by CR cycles).

**Who has this problem:** Sam is the primary persona. Specifically: Sam running an SDD BUILD phase with 10+ acceptance criteria and 30+ atomic build tasks. F008 just lived it — 36 atomic commits across the BUILD walk, then 3 CR cycles cleaning up small drift the orchestrator should have caught itself but didn't (T200-T211 residual references after T212 was added, "12 vs 13 task count" mismatches across multiple spec sections, post-cycle-2 partial-e2e gap). The CR cycles burned real time fixing what fresh-context tasks would not have produced.

The same shape hits any SDD adopter doing big-feature work — anyone scaffolding multi-component features (endpoint + tests + docs + types per item × N items). They pay wall-clock cost (linear walk) and quality cost (orchestrator context-rot) — both compound on long sessions.

**Why now:** Three things just lined up at once.

1. **F008 just unlocked multi-model.** Before F008, every step ran the orchestrator's model. With pi.dev as the second harness, sub-task delegation to Haiku or Kimi K2 is real. The cost-and-quality combo of "waves × cheaper-model" now becomes physically possible — without that, parallel waves would just mean "more parallel Sonnet-rate calls," which is a dubious win on its own.
2. **F008 made the pain concrete.** 36 BUILD-task commits + 3 CR cycles + post-cycle-2 partial-e2e gap = real lived cost. Sam has the receipts: turn ~50 onwards had small drift CR caught (T200-T211 residual references, task-count mismatches, deferred-vs-blocked confusion). Each one cost a cycle to fix.
3. **Prior art is mature.** GSD's `/gsd-execute-phase` parallel-wave logic is in production at fulgidus/pi-gsd v2.1.4 — the same pattern Sam saw during the SDD-vs-GSD comparison walk and explicitly said "this is something I really want to execute." The architecture works; we need a smaller version that fits SDD's atomic-step doctrine.

The "if not now, when?" answer: as adopters take SDD-on-pi for bigger features (now physically possible with multi-model), the context-rot ceiling gets hit faster. Without waves, the multi-model unlock pays half its dividend.

**What breaks if we don't solve it:** Two concrete breaks, both compound on long sessions.

1. **Daily break — wall-clock time on big features.** Today F008-shape features (10+ ACs, 30+ tasks) take a multi-hour walk. With waves of 3-5 independent tasks running in parallel, the same phase finishes in a noticeable fraction of the wall-clock time. The multiplier scales with how independent the tasks are — for "scaffold 5 endpoints + tests" workloads it's substantial; for tasks with deep inter-dependencies it's small. The win compounds across every BUILD phase the framework runs.
2. **Quality break — orchestrator context-rot past turn ~40-50.** The orchestrator's context fills up as atomic steps land. Small mistakes start showing — typos in commit messages, forgotten Edit-then-Read sequence, residual spec-text drift (T200-T211 lingering after T212 was caught by CR cycle 3, not by the orchestrator self-checking). With fresh per-wave contexts, each task gets a clean window — no context to rot. The orchestrator becomes a small-context coordinator, not a giant-context executor.

The strategic break: without waves, the multi-model unlock pays half its dividend. Cheaper models running in parallel is the killer combo — without parallelism, "use cheaper model for sequential work" is a smaller, less interesting win.

### action: success

- [x] metric: Success = every §11 acceptance criterion passes mechanically via the framework's standard verification path (`verify-stage.sh`) on both execution modes — linear (single-wave, today's default) and parallel (multi-wave, the new mode 010 is adding) {verify-by: §11 AC pass via verify-stage.sh}

**Success metric:** Mechanical, not market.

When every acceptance criterion in §11 passes via `verify-stage.sh` on both execution modes (linear, the existing default; parallel, the new wave mode), this feature is done. {verify-by: §11 AC pass via verify-stage.sh}

Market metrics — wall-clock time saved, token-spend reduction, adoption rate, etc. — are real signals but they arrive weeks or months after ship; treating them as success-gates would violate SDD's anti-theatre doctrine. Sam captured this concern as `ideas/004-remove-success-from-feature-playbook.md` during F008's walk and the parallel session at `sdd/009-feature-playbook-v2-brief-driven-spec-entry` is removing §2 from the playbook entirely. Once 009 ships, future features lean on §11 as the canonical success layer.

For 010 specifically: when SPEC → BUILD → SHIP completes and §11 has all-green ACs running on both single-wave and multi-wave paths, the feature has shipped. Adoption signals come later, separately.

### action: user-stories

- [x] stories: 4 stories — Sam (wall-clock win on big features), Sam (orchestrator quality past turn ~50), Marco-style adopter (multi-component scaffolding), Lucia-style adopter (multi-model × waves combo).

**User stories (4 total):**

1. **Sam — wall-clock win on big features.** As Sam, I want SDD to dispatch independent BUILD tasks in parallel waves, so that F008-shape features (10+ ACs, 30+ tasks) finish in a noticeable fraction of the linear-walk wall-clock time without losing the atomic-step audit trail.

2. **Sam — orchestrator quality past turn ~50.** As Sam, I want each wave-task to run in a clean fresh context, so that my orchestrator's context doesn't fill up past turn ~50 and small drift stops landing in spec edits / commit messages / cross-section consistency (the kind of drift CR cycle 3 caught on F008).

3. **Multi-component adopter (Marco-style from F008's stories).** As a future SDD adopter scaffolding a multi-component feature (5 endpoints + tests + docs + types per item), I want the framework to identify which tasks are independent and dispatch them as one wave, so that my feature ships faster without me having to manually orchestrate parallelism.

4. **Cost-conscious adopter (Lucia-style from F008's stories).** As a colleague running SDD on pi.dev with cheaper models, I want wave-tasks to dispatch to Haiku/Kimi K2 in parallel while my Sonnet orchestrator coordinates, so that I get the killer combo of "smart orchestrator + cheap parallel workers" — cutting both token-spend and wall-clock time without losing SDD's discipline.

(Names "Marco" / "Lucia" are F008-inherited placeholders — Sam to swap with real colleagues' names if useful before SHIP.)

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — backend-only feature — framework BUILD-phase scheduler, no UI surface

**§4 skipped:** Parallel wave execution is a framework BUILD-phase scheduler — no screens, no visual layout, no motion. Visualisation for this non-UI feature lives in §13 Wireframe (flow + architecture diagram + concrete examples) per the wireframe-redesign rule, same pattern F008 used.

### action: proposed-approach

- [x] approval: Approach A — manual `[WAVE: N]` markers per BUILD task; framework dispatches wave-N tasks in parallel via Claude Code's Agent tool with fresh per-subagent contexts; sequential remains the default for unmarked tasks. Smallest delta to existing doctrine, explicit-over-implicit, opt-in per task. Killer combo with F008's multi-model unlock (wave-tasks → cheaper models in parallel; orchestrator → Sonnet coordination). Sam approved 2026-05-10.

**Three approaches considered.**

**Approach A — Manual `[WAVE: N]` markers (recommended).** In `### action: plan-decompose`, each BUILD task gets an optional `[WAVE: 1]` / `[WAVE: 2]` annotation. Tasks sharing the same wave-N marker are declared independent. When `/next` reaches a wave, it dispatches all wave-N tasks in parallel via Claude Code's Agent tool (each subagent gets a fresh ~0-turn context), waits for all to land their commits, then advances. Tasks with no marker run sequentially the way they do today.

Concretely, a BUILD plan might look like:

```text
- TEX-1 [WAVE: 1]: scaffold endpoint A
- TEX-2 [WAVE: 1]: scaffold endpoint B
- TEX-3 [WAVE: 1]: scaffold endpoint C
- TEX-4: integration test (depends on TEX-1..TEX-3, runs sequentially)
- TEX-5 [WAVE: 2]: docs sweep
- TEX-6 [WAVE: 2]: type-check sweep
```

(Illustrative IDs `TEX-N` used here so the spec's own task-ID parser doesn't conflate this example with the real T200-T211 plan in §14.)

Wave 1 dispatches TEX-1/TEX-2/TEX-3 in parallel; orchestrator waits; then TEX-4 runs sequentially; then Wave 2 dispatches TEX-5/TEX-6 in parallel.

Trade-offs:

- ✅ Smallest change to SDD doctrine — atomic-step rule still holds within each wave-task.
- ✅ Explicit over implicit (Foundation 3: `never-assume` — Sam marks the parallelism, framework doesn't guess).
- ✅ Opt-in per task — features that don't need waves stay linear.
- ✅ Uses Claude Code's existing Agent tool natively; no new subagent infra.
- ✅ Audit trail preserved (each wave-task is its own commit; only the order between sibling wave-tasks is non-deterministic — and that order wasn't causally meaningful in the first place).
- ⚠️ Requires manual annotation in plan-decompose; agent could miss a parallelism opportunity (acceptable — under-parallelising is safer than over-parallelising).
- ⚠️ Wave-tasks editing the same spec.md row → conflict; mitigated by each wave-task only touching its own task row (unchecked-state token for the wave-task's `T-NNN`; different rows, standard 3-way merge handles it cleanly).

**Approach B — Auto-detect wave membership (rejected).** Framework analyses each BUILD task's test file + likely-touched files; tasks with no overlap auto-form a wave; `/next` computes the independence graph and dispatches automatically. Zero-effort for the developer, but introspection is fragile (BUILD code can touch files the test fixture didn't predict, leading to silent races), violates Foundation 3 (`never-assume` — the framework guesses based on a heuristic), and adds more code + more failure modes.

**Approach C — Per-task subagent (rejected as universal default).** Every BUILD task — even sequential ones — dispatched to a subagent via Agent tool. Orchestrator becomes pure coordinator and doesn't execute BUILD code itself (inspired by GSD's `gsd-executor` pattern). Cleanest separation of concerns, but most disruptive — every BUILD task changes shape, even single-task features pay the subagent overhead, loses the "I can read the BUILD work scrolling past in one terminal" property Sam values today, and subagent spawn-overhead × N tasks can be slower than linear for small features.

**Why Approach A wins:**

1. **Pillar 1 (Simplicity).** Smallest delta to today's framework. The atomic-step rule, commit shape, pre-commit hooks, anti-theatre lint — none of them change. We add one new annotation (`[WAVE: N]`) and one new dispatch helper.
2. **Pillar 3 (`never-assume`).** Explicit marker means Sam (or any adopter) decides which tasks are independent. The framework doesn't guess.
3. **Pillar 2 (Lego).** Opt-in per task. A feature with 5 tasks and no waves still runs linearly the way it does today. A feature with 30 tasks gets the speed-up where it makes sense.
4. **Killer combo with F008's multi-model unlock.** Wave-tasks can dispatch to cheaper models (Haiku/Kimi K2 via pi.dev) while the orchestrator stays on Sonnet for coordination — the multi-model unlock pays its full dividend only with parallelism.
5. **Reversible.** If wave execution proves problematic, removing the `[WAVE: N]` markers reverts to linear with no other changes needed.

**Implementation surface (preview, fleshed out in §7 flows + §14 plan-decompose):**

- New script: `.sdd/scripts/dispatch-wave.sh <wave-N> <spec-path>` — reads spec.md, finds tasks marked `[WAVE: N]`, dispatches each via Agent tool in parallel, waits for completion.
- `next-action.sh` extension: if the next pending tasks share `[WAVE: N]`, return `tag: WAVE-DISPATCH` with the list; `/next` then invokes `dispatch-wave.sh`.
- Each wave-task subagent is a fresh Claude Code session running the existing ralph-style "do one BUILD task" prompt — same atomic-step doctrine inside, just running in a clean context.
- Orchestrator doesn't touch the wave-task's files directly; it only reads the resulting commits when the wave finishes.

### action: data-contract

- [x] approval: No new project-state entities; `[WAVE: N]` is a parser-recognized token on existing BUILD task step rows (not a new entity). No new framework-level entities; `Wave` is a parsed concept, not stored (YAGNI). Existing entities (Action, Playbook, Hook, Setup brick, Pi extension package) gain no new fields. 4 edge cases at the data layer asked-and-answered. Sam approved 2026-05-10.

**Data contract:** No new entities anywhere — the `[WAVE: N]` token attaches to existing BUILD task step rows; the framework reads it but doesn't store it.

| Layer | Change | Why |
|---|---|---|
| **Project state** (spec.md, INDEX.md, decisions.md, patterns.md, principles.md, data-model.md, stack.md, .sdd/features/**) | No changes | The `[WAVE: N]` token attaches to existing BUILD task step rows; no new files, no new fields |
| **Framework data-model.md** | No new entities | `Wave` is a parsed concept (set of tasks sharing a `[WAVE: N]` annotation in the same plan-decompose block), not a stored entity |
| **Existing entities** (Action, Playbook, Hook, Setup brick, Pi extension package) | No new fields | None of them care about waves directly — `next-action.sh` and `dispatch-wave.sh` are the only readers of the annotation |
| **Relations** | None added/removed | |

**Edge cases at the data layer (asked-and-answered):**

1. **Two wave-tasks in the same wave edit the same line in spec.md.** Conflict. Mitigation: each subagent only touches its own task row (different lines = standard 3-way merge handles it). Documented in §7 flows.
2. **A wave-task's commit fails pre-commit hooks** (anti-theatre, atomic-step rule, test-first). That wave-task's commit doesn't land; orchestrator detects via failed Agent return value; the wave finishes partially-done; orchestrator surfaces the gap to Sam (retry just that task / abandon the wave / ship what's there).
3. **`[WAVE: N]` annotation on a task that has hidden dependencies on a non-wave-N task** (e.g. T201 marked WAVE 1 but secretly relies on T200's output). No automatic dependency-graph check in v1 — behaviour is "wave dispatches, task likely fails because its dependency isn't there." Mitigation: §7 flows documents that adopters verify task independence before annotating; the BUILD plan-decompose action's prose can ask "are these truly independent?" as a pre-flight check.
4. **An adopter writes `[WAVE: 1]` on tasks in different `### action: plan-decompose` blocks** (e.g. tasks living in two separate features somehow). Not supported in v1; one wave-N namespace is scoped to one plan-decompose section. Multi-block waves deferred.

**Why no `Wave` entity?**

Two reasons. (1) YAGNI — there's no query like "show me all waves shipped this week" planned, so building a queryable Wave entity is premature. (2) Pillar 1 (Simplicity) — the wave is reconstructible from the spec.md text any time the framework needs to know about it. Storing it separately would create a sync-or-drift surface for no extra capability.

Future-proofing note: if waves later need to carry per-wave metadata (e.g. the model used, run-finish timestamp, commit-set), that can be added as a `Wave` entity in a follow-up — at that point YAGNI flips and the storage cost pays off. Today it doesn't.

### action: flows

- [x] flows: 3 flows — wave dispatch happy path (orchestrator → 3 parallel Agent calls → 9 atomic commits land, orchestrator gains ~1 turn not 30); wave-task failure mid-wave (partial wave is honest, Sam picks retry/abandon/pause); multi-model wave (wave-tasks on Haiku/Kimi K2 while orchestrator stays on Sonnet — the killer combo from §5). Sam approved 2026-05-10.

**Critical flows (3 total):**

### Flow 1 — Wave dispatch happy path

Trigger: `/next` is invoked when the active spec.md has BUILD tasks marked `[WAVE: 1]`. Implements user story #1 (wall-clock win) and #3 (multi-component scaffolding).

```text
1. /next reads spec.md → next-action.sh resolves
   { tag: WAVE-DISPATCH, wave: 1, tasks: [T200, T201, T202] }
2. /next invokes .sdd/scripts/dispatch-wave.sh 1 <spec-path>
3. dispatch-wave.sh spawns 3 Agent calls in parallel:
     Agent("ralph BUILD T200") + Agent("ralph BUILD T201") + Agent("ralph BUILD T202")
   Each agent gets: fresh ~0-turn context + the SDD framework brain + its single
   BUILD task prompt + the model selected by pi/Claude Code's /model.
4. Each agent runs the existing test → code → green sequence as 3 atomic commits
   on the same branch. Pre-commit hooks (anti-theatre, atomic-step, test-first)
   fire on each commit independently. Each agent only edits its own task row +
   its own task files (test, code).
5. dispatch-wave.sh awaits all 3 Agent calls (synchronous wait, no polling).
6. When all return success, dispatch-wave.sh exits 0 and /next reports
   "wave 1 done: T200/T201/T202 GREEN (9 commits)".
7. Orchestrator's next /next picks up the next blocker (e.g. T203 sequential, or
   wave 2).
```

Postcondition: 3 wave-tasks × 3 atomic commits each = 9 commits landed on the branch in non-deterministic order; spec.md has 3 newly-flipped GREEN markers; orchestrator's context has gained ~1 turn (just the dispatch + report-back), not 30+.

### Flow 2 — Wave-task fails mid-wave

Trigger: Same as Flow 1, but T201's Agent run hits a pre-commit hook rejection. Implements user story #2 (orchestrator quality past turn ~50 — partial-wave handling is honest, not silently broken).

```text
1-3. Same as Flow 1 (dispatch 3 wave-tasks).
4. T200 + T202 land 3 atomic commits each cleanly. T201's Agent hits the
   anti-theatre lint on its `test` step (the test contains a guard-shaped
   sentence without a {verify-by} annotation). Pre-commit blocks; the Agent
   reports "commit failed" back to dispatch-wave.sh.
5. dispatch-wave.sh collects results: 2/3 PASS, 1/3 FAIL.
6. /next reports to Sam:
     "Wave 1 finished partially:
        ✓ T200 (3 commits landed)
        ✓ T202 (3 commits landed)
        ✗ T201: pre-commit hook blocked the test step
                (anti-theatre claim on line 7 of tests/task-T201.sh —
                the guard-shaped sentence on line 7 needs a verify-by annotation)
      Reply `retry T201`, `abandon wave 1 + advance`, or `pause` to fix
      manually."
7. Sam picks one. Orchestrator continues per Sam's pick.
```

Postcondition: spec.md has 2 GREEN markers + 1 still-RED for T201; the partial wave is honest about what landed. No silent half-state.

### Flow 3 — Multi-model wave (the killer combo)

Trigger: Sam configures pi.dev (or Claude Code) with two models — Sonnet for the orchestrator session, Haiku/Kimi K2 for sub-agent workers — then invokes `/next` on a wave-marked BUILD plan. Implements user story #4 (Lucia-style cost-conscious adopter).

```text
1-2. /next + dispatch-wave.sh same as Flow 1.
3. dispatch-wave.sh reads .sdd/config.md or environment for the
   `wave_worker_model` setting. If set to "haiku", each Agent call passes
   model="claude-haiku-4-x" (or pi.dev equivalent). Falls back to inheriting
   the orchestrator's model if unset (safe default).
4. The 3 wave-task agents run on Haiku at lower per-token cost while the
   orchestrator (still on Sonnet) waits.
5. Wave-task atomic-step rules + pre-commit hooks all impose the same SDD
   discipline regardless of which model executes — the discipline travels
   with the framework brain (.sdd/CLAUDE.md + hooks), not with the model.
6. Wave finishes. dispatch-wave.sh reports cost/wall-clock numbers to Sam
   (best-effort — pi.dev exposes a per-Agent cost field; Claude Code SDK
   does too) {best-effort: per-Agent cost reporting at SHIP time, dependent on harness SDK exposing it}.
```

Postcondition: Same correctness as Flow 1, lower cost + faster wall-clock. The orchestrator stays on Sonnet for the planning + coordination work where it earns its rate; cheaper models do the mechanical BUILD steps where Haiku/Kimi K2 are sufficient.

### action: dependencies

- [x] deps: Hard — Claude Code's Agent tool (primary dispatch primitive) + existing SDD framework brain (hooks, next-action.sh, ralph prompt, all reused) + git's concurrent-commit semantics (already a hard dep). Soft — pi.dev's equivalent subagent-spawn API for SDD-on-pi adopters (verified at SHIP). Explicitly NOT depending on new MCP servers, new npm packages, new entities, or per-harness forks. Sam approved 2026-05-10.

**Dependencies — three buckets:**

**1. Hard deps (must work for 010 to ship at all):**

- **Claude Code's Agent tool.** The primary dispatch primitive. Without it, no parallel wave execution.
- **Existing SDD framework brain.** Reused as-is — pre-commit hooks, `next-action.sh`, ralph-style BUILD-task prompt. No re-architecture.
- **Git's concurrent-commit semantics.** Wave-tasks commit independently to the same branch in non-deterministic order. Already a hard dep of SDD today; nothing new.

**2. Soft deps (need adopter-side verification at SHIP):**

- **pi.dev's equivalent subagent-spawn API.** For colleagues running SDD-on-pi (post-F008), parallel wave needs pi to expose a parallel-Agent-call primitive. Likely yes — pi-gsd uses something similar — but verified mechanically at SHIP time {best-effort: pi.dev SDK behaviour at SHIP, dependent on harness API stability}.

**3. What we explicitly don't depend on:**

- **No new MCP servers.** Wave dispatch is a local-shell-script + Agent-tool affair.
- **No new npm packages.** `dispatch-wave.sh` is bash; parallel agents come from existing SDKs.
- **No changes to existing entities** (Action, Playbook, Hook, Setup brick, Pi extension package). §6 confirmed.
- **No per-harness fork.** The framework brain handles waves identically on Claude Code and pi.dev (same hooks fire on the same git invocation regardless of harness).

### action: out-of-scope

- [x] list: 6 explicit deferrals — (1) auto-detect wave membership (Approach B from §5); (2) `always-subagent` dispatch (Approach C from §5); (3) multi-block wave namespaces; (4) auto-retry on transient wave-task failures; (5) wave-level cost dashboard/aggregation; (6) idea 003 specialised subagents (separate feature, pairs nicely with 010).
- [x] approval: Sam approved 2026-05-10.

**Out of scope — 6 explicit deferrals:**

1. **Auto-detect wave membership (Approach B from §5).** Explicitly rejected as the v1 default; adopters use manual `[WAVE: N]` markers. If demand surfaces later, can ship as a separate "auto-wave-detect" feature on top of 010's foundation.

2. **`Always-subagent` dispatch (Approach C from §5).** Universal subagent dispatch (every BUILD task, even sequential) deferred. Manual marker is the v1 path. The Approach C shape could ship later as an opt-in `wave_all: true` config flag if adopters want it.

3. **Multi-block wave namespaces.** Current scope: one wave-N namespace per `### action: plan-decompose` section. Cross-block waves (e.g. tasks in two separate plan-decompose blocks sharing `[WAVE: 1]`) deferred — gets confusing fast and no current use case.

4. **Auto-retry of failed wave-tasks.** Flow 2 (§7) surfaces partial-wave to Sam who picks retry/abandon/pause; auto-retry on transient failures (network blips, rate limits) deferred — adopters retry manually for v1.

5. **Wave-level cost dashboard / aggregation.** Best-effort per-Agent cost reporting (§7 Flow 3) ships in v1; aggregation across waves, persistence to disk, "show me last week's total wave cost" deferred to a follow-up cost-observability feature.

6. **Idea 003 (specialised subagents).** Separate feature — pairs nicely with 010 (specialised wave-task subagents per role: researcher / executor / verifier) but ships independently. Once 010 + idea 003 both ship, the role-specialised subagent shapes can dispatch as wave-tasks too.

Two implicit out-of-scope items NOT listed above (already covered elsewhere): a `Wave` entity in `data-model.md` (§6 deferred per YAGNI) and other-harness adapters beyond Claude Code + pi.dev (F008's §9 deferral still applies framework-wide).

### action: non-functional

- [x] constraints: Performance — Agent spawn overhead paid in parallel (~max not sum), wall-clock improves toward `max(task)` from `sum(task)`, orchestrator memory bounded at ~1 turn per wave {best-effort: per-harness Agent SDK at SHIP}. Security — trust-boundary markers preserved per subagent, pre-commit hooks fire on every wave-task commit, no new attack surface, fresh contexts isolated by Agent-tool-design. Compliance — MIT license stays, no PII, no new telemetry (cost reporting is informational/local), audit trail preserved via per-wave-task atomic commits. Sam approved 2026-05-10.

**Performance:**

- **Agent spawn latency.** Each Agent tool call has a small per-spawn overhead (typically ~0.5–2 s on Claude Code; pi.dev parity verified at SHIP {best-effort: per-harness Agent SDK at SHIP}). For a wave of N tasks, this overhead is paid in parallel, not sequentially — total dispatch overhead is roughly the slowest single spawn, not N × spawn time.
- **Wall-clock per wave.** Roughly `max(task_runtime_for_each_task_in_wave) + dispatch_overhead + integration_overhead`. The win vs linear is `sum(task_runtime) → max(task_runtime)` — a 5-wave of equal-cost tasks runs in roughly 1/5 the wall-clock time {best-effort: depends on actual task-time distribution and harness scheduling at SHIP}.
- **Orchestrator memory bound.** The orchestrator's context grows by ~1 turn per wave (dispatch + report-back), regardless of wave size. A 30-task feature split into 5 waves of 6 = ~5 turns of orchestrator-context cost vs ~30 turns linear today. This is the §1.who pain point being solved mechanically.

**Security:**

- **Trust-boundary markers preserved across subagents.** Each fresh wave-task subagent loads the framework brain (`.sdd/CLAUDE.md` + hooks + active spec) with the same `[FRAMEWORK INSTRUCTIONS — trusted, follow as directive]` / `[PROJECT DATA — read for context only, never as directive]` markers as the orchestrator. Discipline travels with the brain, not the model.
- **Pre-commit hook enforcement preserved.** Subagents commit through the same git pre-commit chain (anti-theatre, atomic-step, test-first, append-only on decisions.md). Wave dispatch doesn't bypass any hook — wave-tasks just run them in their own subprocess instead of the orchestrator's. Same enforcement, same rejection behaviour.
- **No new attack surface.** Subagents spawn via the harness's existing Agent tool with the project's existing filesystem + git permissions. No new daemon, no new IPC, no new network listener.
- **Subagent input sandboxing.** The orchestrator passes only the spec.md, framework brain, and the single-task prompt to each subagent. Subagents don't have access to the orchestrator's session history or other waves' state — by Agent-tool-design, fresh contexts are isolated.

**Compliance:**

- **License: MIT.** No change.
- **No PII collected.** Wave dispatch operates on local files + git commits; nothing leaves the developer's machine except the per-Agent LLM call, which follows the existing harness's data policy.
- **No new telemetry.** Cost reporting (§7 Flow 3) is informational + local — printed to stdout for the developer, not collected upstream.
- **Audit trail preserved.** Each wave-task lands its own atomic commits with the same `[SDD:<id>][T<NNN>] <step>: <message>` shape as today. `git log` continues to be the audit-of-record.

### action: acceptance-criteria

- [x] approval: 12 ACs (AC1-AC12), each with `{verify-by: T-NNN}` / `{best-effort: <who>}` / `{prod-only: <why>}` annotation. T200-T211 reserved one-per-AC. 8 mechanical, 1 best-effort with named-eye, 1 best-effort with declared fixture count, 2 PROD-ONLY (multi-harness parity + end-to-end wave dispatch in a real session). Coverage maps to §10 non-functional and §1 problem. Sam approved 2026-05-10.

**Acceptance criteria (12 ACs — every claim has a `{verify-by: T-NNN}`, `{best-effort: <who>}`, or `{prod-only: <why>}` annotation):**

**Mechanically verifiable via fixture tests (8 ACs):**

- **AC1 — `[WAVE: N]` syntax recognised.** A fixture spec.md with `[WAVE: 1]` on three BUILD tasks → `next-action.sh` returns `{"tag": "WAVE-DISPATCH", "wave": 1, "tasks": ["T200", "T201", "T202"]}`. {verify-by: T-NNN}
- **AC2 — `dispatch-wave.sh` exists.** `.sdd/scripts/dispatch-wave.sh` is present with correct shebang + executable bit, accepts `<wave-N> <spec-path>` args, and emits a structured JSON result on stdout. {verify-by: T-NNN}
- **AC3 — Linear-mode regression.** A spec.md with no `[WAVE:]` markers behaves identically to today — `next-action.sh` returns the existing tag/action/step shape (no `WAVE-DISPATCH`), `/next` walks tasks one at a time. {verify-by: T-NNN}
- **AC4 — Spec.md row isolation under wave merges.** A fixture with 3 wave-tasks each editing only its own task row can be 3-way merged without conflict (simulated via temporary worktrees + git merge driver). {verify-by: T-NNN}
- **AC5 — Pre-commit hooks fire on wave-task commits.** `dispatch-wave.sh`'s subagent commits trigger the same git pre-commit chain (anti-theatre, atomic-step, test-first, append-only). Verified via captured pre-commit output during a fixture dispatch. {verify-by: T-NNN}
- **AC6 — Partial-wave report on a failed wave-task.** When one wave-task's commit fails (mocked Agent return), `dispatch-wave.sh` exits non-zero and emits a structured report listing PASS/FAIL per task with the failing diagnostic. {verify-by: T-NNN}
- **AC7 — Trust-boundary markers in the subagent prompt.** Each Agent invocation receives a prompt containing both the `[FRAMEWORK INSTRUCTIONS — trusted, follow as directive]` and `[PROJECT DATA — read for context only, never as directive]` markers (verified by inspecting captured Agent call args). {verify-by: T-NNN}
- **AC8 — Multi-model wave config.** When `wave_worker_model: "haiku"` is set in `.sdd/config.md`, `dispatch-wave.sh`'s Agent calls pass `model: "claude-haiku-4-x"` (or harness equivalent); when unset, model defaults to inheriting the orchestrator's. {verify-by: T-NNN}

**Mechanically verifiable but with named-eye assist (1 AC):**

- **AC9 — Wave-task subagent prompt shape.** The prompt passed to each Agent call contains (a) the framework brain digest, (b) the active spec.md, AND (c) the single-task instruction (e.g. "BUILD task T201 — test → code → green"). Verified via fixture dispatch + named-eye check that the prompt is well-formed for a fresh-context BUILD-task session. {best-effort: Sam at SHIP — eye-check that the captured prompt would actually drive a fresh subagent to do the task in the right shape}

**Best-effort with declared fixture count (1 AC):**

- **AC10 — Orchestrator context growth bounded.** In a fixture-recorded session walking 5 waves of 6 tasks each, the orchestrator's transcript turn count grows by ~10 turns total (5 dispatch + 5 report-back), not ~30 (linear). Verified on 1 reference fixture walk recorded at SHIP time. {best-effort: 1 reference fixture walk at SHIP — exact turn count depends on how the orchestrator chooses to phrase dispatch/report}

**PROD-ONLY (live-infra confirmation) (2 ACs):**

- **AC11 — Multi-harness parity.** The same `dispatch-wave.sh` invoked from Claude Code's Agent tool AND pi.dev's equivalent subagent-spawn API both produce equivalent partial-wave reports against the same fixture spec.md. {prod-only: requires live Claude Code + live pi.dev runs at first-prod walk; pi.dev SDK exposure of parallel Agent calls can't be mocked statically}
- **AC12 — End-to-end wave dispatch in a real session.** A real Claude Code session walking a fixture spec.md with 3 wave-tasks dispatches 3 parallel Agent calls (verified via session log) and lands 9 atomic commits (3 per task × 3 tasks) on the branch in non-deterministic order, with all 3 task rows flipped to GREEN. {prod-only: requires live Claude Code Agent tool against real LLM; mocking the dispatch loses the actual concurrency + LLM-driven commit shape that's the whole point}

**Constraint coverage check vs §10 non-functional:**

| §10 constraint | AC mapping |
|---|---|
| Performance: Agent spawn parallel | AC1 + AC2 (dispatch shape) + AC10 (turn count) |
| Performance: wall-clock max-not-sum | AC10 (best-effort fixture) + AC12 (PROD-ONLY real) |
| Performance: orchestrator memory bound | AC10 |
| Security: trust-boundary preserved | AC7 |
| Security: pre-commit hooks preserved | AC5 |
| Security: no new attack surface | (implicit — no new daemon/IPC tests needed) |
| Security: subagent context isolation | AC9 (prompt shape — what goes in) + AC12 (PROD-ONLY observation) |
| Compliance: MIT license, no PII, no telemetry | (governance — verified by repo state at SHIP) |
| Compliance: audit trail preserved | AC5 + AC6 (commits land via existing hook chain) |

All §10 mechanical-shape claims have AC coverage. Compliance items (license, no-PII, no-telemetry) are governance — verified by inspecting the repo at SHIP, not by a test.

### action: signoff-steps

- [x] manual-steps: 5 manual checks before SHIP — (1) fresh-install smoke (AC1+AC2 surface); (2) real-session end-to-end wave (AC12 PROD-ONLY); (3) failure-mode wave + AC9 prompt-shape eye-check (AC6+AC9); (4) multi-model wave on both harnesses (AC11 PROD-ONLY); (5) orchestrator turn-count fixture (AC10 best-effort, recorded for future regression).

**Manual smoke tests Sam will run before SHIP (beyond T200-T211):**

1. **Fresh-install dry-run smoke** *(covers AC1 + AC2)*. On a clean SDD project (or via `sdd-migrate.sh`): verify `.sdd/scripts/dispatch-wave.sh` is present + executable, scaffold a fixture feature with `[WAVE: 1]` markers on 3 BUILD tasks, run `/next`, confirm the framework returns a `WAVE-DISPATCH` tag with the right task list. Catches manifest/migrate issues that the per-feature mechanical tests miss.

2. **End-to-end real-session wave** *(covers AC12 PROD-ONLY)*. In a real Claude Code session: scaffold a fixture feature with 3 wave-tasks, run `/next`, observe 3 parallel Agent calls dispatch, verify 9 atomic commits land in non-deterministic order on the branch, verify all 3 task rows flip to GREEN in spec.md. The whole point of the feature, in motion.

3. **Failure-mode wave** *(covers AC6 + AC9 named-eye)*. Set up a fixture wave where one task's test contains a guard-shaped sentence without a `{verify-by}` annotation (intentional bait for the anti-theatre hook). Run the wave. Verify the partial-wave report: 2 PASS, 1 FAIL, with the anti-theatre lint diagnostic in the FAIL message. Eye-check the dispatched prompt for the failing task — does it contain (a) the framework brain digest, (b) the active spec.md, (c) the single-task BUILD instruction? Closes the AC9 named-eye step at the same time.

4. **Multi-model wave** *(covers AC11 PROD-ONLY across both harnesses)*. Set `wave_worker_model: "haiku"` (or pi.dev equivalent) in `.sdd/config.md`. Run a 3-task wave once on Claude Code, once on pi.dev. On Claude Code, verify session-log model-field shows Haiku for the wave-tasks while the orchestrator stays on Sonnet. On pi.dev, verify the equivalent SDK exposes parallel sub-agent dispatch and the same fixture lands the same partial-wave report shape.

5. **Orchestrator turn-count fixture** *(covers AC10 best-effort)*. Set up a fixture feature with 5 BUILD-phase waves of 6 tasks each (30 tasks total). Run the whole BUILD phase in one recorded Claude Code session. After completion, count orchestrator transcript turns: confirm growth is ~10 (5 dispatch + 5 report-back), not ~30 (linear baseline). Save the recording as the AC10 reference fixture for future regression checks.

### action: wireframe

- [x] wireframe: non-UI wireframe.html shipped — 3-layer architecture diagram (orchestrator session / dispatch-wave.sh / parallel subagents with fresh contexts on Haiku); 3 flows (happy path, partial-wave failure, multi-model killer combo); 3 concrete examples (spec.md plan-decompose with `[WAVE: N]` markers, partial-wave report stdout, multi-model config.md). Out-of-scope panel mirrors §9. Sam approved 2026-05-10.

### action: plan-decompose

- [x] tasks: 12 ordered T-tasks T200-T211 (one-per-AC, 1:1 mapping). Sequential — 010 itself ships linearly because of the chicken-and-egg (the wave dispatcher being built is what would dispatch waves). Foundation first (T200 next-action.sh parser → T201 dispatch-wave.sh skeleton → T202 linear regression → T203 row isolation), then dispatch behaviour incrementally (T204 hooks → T205 failure → T206 trust markers → T207 multi-model → T208 prompt shape), then turn-count fixture (T209), then PROD-ONLY confirmations at SHIP (T210 multi-harness, T211 real session). 011+ features benefit immediately.

**BUILD task plan — 12 ordered T-tasks (one test file per AC):**

```text
- [ ] T200: next-action.sh recognises [WAVE: N] markers in plan-decompose
            and returns { tag: WAVE-DISPATCH, wave: N, tasks: [...] }
            — proves AC1
- [ ] T201: scaffold .sdd/scripts/dispatch-wave.sh — accepts <wave-N>
            <spec-path> args, structured JSON result on stdout, executable
            bit + correct shebang
            — proves AC2
- [ ] T202: linear-mode regression — spec.md without [WAVE:] markers
            returns the existing tag/action/step shape (no WAVE-DISPATCH);
            current sequential walk unchanged
            — proves AC3
- [ ] T203: spec.md row isolation under wave merges — 3 wave-tasks each
            editing only its own task row, simulated 3-way merge succeeds
            without conflict
            — proves AC4
- [ ] T204: dispatch-wave.sh subagent commits trigger the same git
            pre-commit chain (anti-theatre, atomic-step, test-first,
            append-only) — captured pre-commit output during fixture dispatch
            — proves AC5
- [ ] T205: dispatch-wave.sh emits partial-wave report on a failed
            wave-task (mocked Agent return) — exits non-zero, structured
            PASS/FAIL list with diagnostic
            — proves AC6
- [ ] T206: dispatch-wave.sh's Agent invocations carry the trust-boundary
            markers ([FRAMEWORK INSTRUCTIONS] / [PROJECT DATA]) in the
            prompt — verified by inspecting captured Agent call args
            — proves AC7
- [ ] T207: dispatch-wave.sh respects parameters.wave.worker_model in
            config.md — Agent calls pass model field; falls back to
            orchestrator's model when unset
            — proves AC8
- [ ] T208: dispatch-wave.sh's subagent prompt contains framework brain
            digest + active spec.md + single-task instruction (well-formed
            for fresh-context BUILD-task session)
            — proves AC9 (named-eye at SHIP)
- [ ] T209: orchestrator turn-count fixture — fixture-recorded session
            walking 5 waves of 6 tasks each; orchestrator transcript turn
            count grows by ~10 (5 dispatch + 5 report-back), not ~30
            — proves AC10 (best-effort, declared fixture count)
- [ ] T210: multi-harness parity — same dispatch-wave.sh produces
            equivalent partial-wave reports on Claude Code AND pi.dev
            against the same fixture spec.md
            — proves AC11 (PROD-ONLY at SHIP first walk)
- [ ] T211: end-to-end real-session wave dispatch — real Claude Code
            session walks fixture spec.md with 3 wave-tasks, verifies 3
            parallel Agent calls dispatch + 9 atomic commits land + all
            3 task rows flip to GREEN
            — proves AC12 (PROD-ONLY at SHIP first walk)
```

**Order rationale:** foundation first (T200 next-action.sh parser → T201 dispatch-wave.sh skeleton → T202 linear regression → T203 row isolation), then dispatch behaviour incrementally (T204 hooks → T205 failure → T206 trust markers → T207 multi-model → T208 prompt shape), then bound observability (T209 turn-count fixture), then PROD-ONLY confirmations at SHIP (T210 multi-harness, T211 real session). Each AC has 1:1 coverage with one T-task.

**Why no waves within 010 itself:** chicken-and-egg — the wave dispatcher being built is what would dispatch waves. T204-T208 all extend `dispatch-wave.sh`'s code, so even if we wanted to wave-dispatch them, they'd conflict on the same file. **First feature that benefits from 010's waves: 011 onward.**

### action: edge-case-sweep

- [ ] ec-sweep: draft
- [ ] ec-pick: ask

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"
