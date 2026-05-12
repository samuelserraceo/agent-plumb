---
playbook: feature
---

# specialized subagents (researcher / executor / verifier) — closes idea 003

[PHASE: BUILD]

**Active blocker:** BUILD — T01-T03 to ship

**Run mode:** full-autonomous

## PHASE: SPEC

### action: brief-intake

- [x] brief: idea 003 (`.sdd/ideas/003-specialized-subagents.md`) IS the brief. Splits today's monolithic agent into 3 declarative role files (researcher / executor / verifier). Each ships as a markdown file with frontmatter + system-prompt body, plus a `/dispatch` slash command and one new `Subagent` entity in `data-model.md`. Declarative ship — no runtime daemon, no enforcement, no auto-routing. Pairs with F008 (multi-model) for tier-routing + F010 (parallel waves) for executor dispatch + F015 (model_tier per action) for default-role mapping.

#### §0 Brief

**Source:** [[ideas/003-specialized-subagents]] — captured 2026-05-07.

**Fix shape (declarative-only):**
- 3 new files under `templates/.sdd/agents/` (mirrored to `.sdd/agents/`): `researcher.md`, `executor.md`, `verifier.md`. Each carries frontmatter (`role`, `model_tier_default`, `tools_allowed`) + a system-prompt-style body explaining what the role does and how to behave.
- 1 new slash command `templates/.claude/commands/dispatch.md` (mirrored) documenting `/dispatch <role> <task>`.
- 1 new entity `Subagent` in `.sdd/data-model.md` (analogous to `Action` / `Hook`).
- 1 short doctrine paragraph in `templates/CLAUDE.md` describing when to reach for which role.
- Manifest repinned for both copies (live + template).

**Out of scope (deferred):**
- Runtime auto-dispatcher in `next-action.sh` (this idea ships agent-readable doctrine; auto-routing would require model_tier-per-action wiring — handled by F015 not F025).
- Debugger / planner roles — start with 3, add when patterns earn it (per idea 003).
- Tools-allowed mechanical enforcement (advisory in v1; can become a hook later if drift surfaces).

**Backwards compat:** `/next` flow unchanged; subagents are opt-in via `/dispatch`. Existing projects without `.sdd/agents/` keep current behaviour.

**Target:** v1.9 (declarative-only follow-up to v1.8.x patch run).

### action: problem

- [x] who: SDD's main agent today walks every step (SPEC, BUILD, SHIP) in one context. Research notes, code edits, AC checks all eat the same token budget. The user (Sam, but anyone running long features) hits context-rot 4-5 hours into a feature.
- [x] why-now: F008 (multi-model) + F010 (parallel waves) + F015 (model_tier per action) just shipped — the tier-routing infra is in place but there's no role concept to feed it. F025 is the missing brick that lets cheap models run cheap roles.
- [x] what-breaks: without role separation, every BUILD task and every verification pass uses the same prompt and (today) the same model. Context-rot makes verification miss AC gaps it caught early; cost stays high because Opus runs even mechanical tasks. {verify-by: T-01}

#### §1 Problem

#### who-has-it

The user driving an SDD feature (any user, but observed live with Sam) over a 30+ task BUILD or a long SHIP cycle. The single context fills with research findings from action 5 that aren't useful at action 11; the agent's verification pass at action 14 has to re-derive the §11 AC list because the original context is buried.

#### why-now

F008 + F010 + F015 just landed: tier-routing exists at the action level, parallel-wave dispatch exists at the BUILD-task level. F025 is the missing role-level brick. With it, F015's `model_tier:` can default per-role (research → cheap, execute → mid, verify → small/fast) without each action having to re-declare. Without it, the tier system is per-action only — a missed dimension.

#### what-breaks

1. **Context-rot in long features** — single-context agent loses sharpness after ~20 actions. Verification at SHIP misses AC gaps the same agent caught at SPEC §11 because the prompt is now buried under code edits.
2. **No cost-optimisation handle** — F008 lets you pick a model per action; F025 lets you pick a model per ROLE (researcher = Haiku-class, executor = Sonnet-class, verifier = Haiku-class). One layer up the abstraction tree.
3. **No declarative way to invoke a subagent** — today the user has to write `Use the Agent tool with prompt: "you are a verifier, here are the §11 ACs..."` from scratch every time. {verify-by: T-02}

### action: user-stories

- [x] stories: 2 personas

#### §3 User Stories

> *As an SDD framework user mid-BUILD, I want to dispatch a fresh-context verifier subagent against my §11 ACs so the verifier sees ONLY the spec + diff (not 30 turns of code edits), catches more AC gaps, and returns a clean report.*

> *As an SDD framework maintainer, I want to declare default model tiers per role (researcher/executor/verifier) so cost-optimisation isn't per-action but per-role — one config change cascades to every action a researcher runs.*

### action: ux-brief

- [x] brief: no UI surface — markdown files + one slash command

#### §4 UX & Design brief

**Primary surface:** the agent reads `.sdd/agents/<role>.md` when invoked via `/dispatch <role> <task>`. The slash command body documents the convention; the agent files supply the system-prompt body.

**Before:** monolithic agent walks every step in one context. No role concept.
**After:** 3 declarative role files + 1 `/dispatch` command. Agent treats `<role>.md` as the system-prompt body for a fresh-context subagent invocation. Backwards-compat: existing `/next` flow unchanged.

### action: proposed-approach

- [x] approval: AUTONOMOUS DRAFT — declarative-shape feature, mirrors F011 + F013 (doctrine-only) precedent.

#### §5 Proposed approach

1. **Three agent role files** under `templates/.sdd/agents/` (created new) + mirror at `.sdd/agents/`:
   - `researcher.md` — system prompt for codebase exploration + WebFetch + synthesis. `model_tier_default: mechanical` (cheap, lots of context).
   - `executor.md` — system prompt for running a single BUILD-TASK end-to-end. `model_tier_default: routine` (balanced).
   - `verifier.md` — system prompt for reading spec + diff and reporting AC gaps. `model_tier_default: mechanical` (small/fast).
   Each file's frontmatter declares `role`, `model_tier_default`, `tools_allowed`. Body is system-prompt-style prose (~30-60 lines).

2. **One slash command** `templates/.claude/commands/dispatch.md` (mirrored to `.claude/commands/dispatch.md`) documenting `/dispatch <role> <task>`. The command body tells the agent: read `.sdd/agents/<role>.md`, treat the body as the system prompt for a fresh Agent-tool subagent, pass `<task>` as the user message. Agent-honoured convention (same shape as `requires_user_approval`, `prelude_refresh`, `skip_when` — no runtime evaluator).

3. **One new entity `Subagent`** in `.sdd/data-model.md` — declares the shape (frontmatter fields + body convention) so future role additions follow the same pattern.

4. **One doctrine paragraph** in `templates/CLAUDE.md` (mirrored) above the existing "Multi-feature parallel work" section, naming the three roles + the `/dispatch` entry-point + when to reach for each.

5. **Manifest repin** — both `templates/.sdd/.cache/manifest.json` and `.sdd/.cache/manifest.json` get entries for the 3 new agent files + the new slash command + the dispatch script (none — pure markdown).

### action: data-contract

- [x] approval: AUTONOMOUS DRAFT — one new entity `Subagent`, sibling of `Action` / `Hook`

#### §6 Data contract

New entity `Subagent` in `.sdd/data-model.md`:

- **Location:** `.sdd/agents/<role>.md` (live) + `templates/.sdd/agents/<role>.md` (framework copy).
- **Frontmatter fields:**
  - `role` (string, required) — slug matching the filename basename.
  - `model_tier_default` (enum: `thinking` / `routine` / `mechanical`, required) — falls back to `routine` per F015 convention.
  - `tools_allowed` (array of strings, advisory) — informs which Claude Code tools the subagent should call. Not mechanically enforced in v1 (deferred per §9).
- **Body:** plain-English system-prompt prose. Agent reads this verbatim when dispatched.

Today: **0 subagents**. Adds 3 (researcher / executor / verifier) in this feature.

Same agent-honoured-frontmatter shape as Action's `requires_user_approval` / `prelude_refresh` / `trust` (per F013 pattern). No runtime evaluator.

### action: flows

- [x] flows: 1 dispatch flow

#### §7 Flows

```text
User: /dispatch verifier "Check my §11 ACs against the current diff"
Claude Code (main agent):
  1. Reads .sdd/agents/verifier.md
  2. Spawns Agent-tool subagent with verifier.md body as system prompt
  3. Passes "Check my §11 ACs against the current diff" as user message
Subagent (verifier role, fresh context):
  - Reads spec.md §11
  - Reads `git diff` for changed files
  - Returns: "AC1 covered by tests/task-001.sh GREEN; AC2 prose unchanged — no diff coverage"
Main agent: relays subagent report to user
```

### action: dependencies

- [x] deps: zero new deps. Uses Claude Code's existing Agent tool.

### action: out-of-scope

- [x] list: 4 deferrals
- [x] approval: AUTONOMOUS DRAFT

#### §9 Out-of-scope

1. **Runtime auto-dispatch** — `next-action.sh` doesn't read `.sdd/agents/` and auto-pick a role per step. Deferred — would require model_tier-per-action wiring (F015 covers that dimension separately).
2. **Mechanical `tools_allowed` enforcement** — v1 ships advisory. Hook-based enforcement deferred until drift surfaces in practice (same precedent as `skip_when:` shipped advisory in F013).
3. **Debugger / planner roles** — start with 3, add when the patterns earn it (per idea 003 explicit guidance).
4. **Subagent-to-subagent dispatch** — only the main agent dispatches in v1. Nested dispatch deferred.

### action: non-functional

- [x] constraints: zero perf/security impact — markdown files only.

### action: acceptance-criteria

- [x] approval: AUTONOMOUS DRAFT — 3 ACs mapped 1:1 to 3 tests

#### §11 Acceptance criteria

- [ ] AC1: The 3 agent role files exist at `templates/.sdd/agents/{researcher,executor,verifier}.md` AND mirrored at `.sdd/agents/{researcher,executor,verifier}.md`. Each file has frontmatter declaring `role`, `model_tier_default`, and `tools_allowed`. `role` matches filename basename; `model_tier_default` is one of `thinking` / `routine` / `mechanical`. {verify-by: T-01} — `tests/task-001.sh`

- [ ] AC2: The `/dispatch` slash command file exists at `templates/.claude/commands/dispatch.md` AND mirrored at `.claude/commands/dispatch.md`. Both files name the 3 roles (researcher / executor / verifier) in their body. {verify-by: T-02} — `tests/task-002.sh`

- [ ] AC3: `.sdd/data-model.md` contains an `### Subagent` entity heading with a body that names the 3 roles AND declares the 3 frontmatter fields (`role`, `model_tier_default`, `tools_allowed`). {verify-by: T-03} — `tests/task-003.sh`

### action: signoff-steps

- [x] manual-steps: 1 smoke

#### §12 Sign-off

1. After merge, run `/dispatch verifier "Check §11 ACs"` against an in-flight feature and confirm the subagent reads `verifier.md` system-prompt prose + returns a coherent AC-gap report. {best-effort: Sam at SHIP smoke}

### action: wireframe

- [x] wireframe: skipped — pure markdown / doctrine shape, no UI; flow in §7 captures the architecture diagrammatically

### action: plan-decompose

- [x] tasks: AUTONOMOUS DRAFT — 3 tasks T01-T03

#### §14 Plan-Decompose

- [ ] T01: Create 3 agent role files in both `templates/.sdd/agents/` and `.sdd/agents/` (researcher.md / executor.md / verifier.md) with the required frontmatter + system-prompt body. Test: `tests/task-001.sh` GREEN. AC1 mapped.
- [ ] T02: Create `/dispatch` slash command in both `templates/.claude/commands/` and `.claude/commands/` documenting `<role> <task>` invocation. Test: `tests/task-002.sh` GREEN. AC2 mapped.
- [ ] T03: Add `Subagent` entity section to `.sdd/data-model.md` + doctrine paragraph to `templates/CLAUDE.md` (mirrored to live `CLAUDE.md`). Test: `tests/task-003.sh` GREEN. AC3 mapped.

### action: edge-case-sweep

- [x] ec-sweep: 3 EC
- [x] ec-pick: AUTONOMOUS DRAFT

#### §15 Edge cases

1. EC#1 — user runs `/dispatch <role>` against a role file that doesn't exist (typo). Agent reads convention from `dispatch.md` body + reports "no such role; try researcher / executor / verifier". Documented in dispatch.md body; no runtime evaluator needed in v1.
2. EC#2 — `.sdd/agents/` exists with custom roles beyond the 3 ships. Convention allows it: any file under `.sdd/agents/<role>.md` with the right frontmatter is dispatchable. Documented in `Subagent` entity prose.
3. EC#3 — main agent forgets to spawn the subagent and just answers in-line as itself. This is a behavioural-drift risk same as every Claude-Code-honoured convention (F013 `skip_when`, F011 `automation.level`). Mitigated by: (a) doctrine paragraph in CLAUDE.md, (b) slash command body explicitly says "DISPATCH a subagent — do not answer as the main agent." Not mechanically enforced in v1 (same precedent as the SKIP convention).

### Exit checks
- [x] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [x] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full-autonomous

**Run mode:** full-autonomous

### action: build-task

(driven by §14 tasks T01-T03)

### exit_checks

- [ ] C-build-tasks-green: every task is GREEN — `grep -cE '^- \[x\] T[0-9]+' "$SECTION_FILE"` matches T-row count in §14
