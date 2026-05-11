---
playbook: feature
---

# auto-advance AGENT-LED steps

[PHASE: SPEC]

**Active blocker:** §1 (first action: brief-intake)

## PHASE: SPEC

### action: brief-intake

- [x] brief: Sam pasted idea-005 as the brief — auto-advance AGENT-LED steps via `parameters.automation.level: full|most|checkpoint`. F008+F010 just shipped; SPEC+SHIP still require constant approve clicks (BUILD already auto). Brief approved 2026-05-11 after 3-grill Q&A: (1) respect existing `requires_user_approval` frontmatter + flip defaults; (2) Most-tier destructive gate covers mark-shipped, manifest-repin commits, `--delete-branch` merges, decisions.md edits; (3) USER-LED stays interactive (only AGENT-LED auto-advances). Pre-filled §1/§3/§6/§7/§8/§10 below.

### action: problem

- [x] who: Sam + future SDD adopters running multi-step features. Today every AGENT-LED step in SPEC + SHIP asks "approve?" even when the proposal is purely technical (no product/business/scope call).
- [x] why-now: F008 (multi-model) + F010 (parallel waves) just shipped. Framework at the cusp of drop-the-brief-walk-away shape, but SPEC + SHIP still require constant approvals — last unlock to compound F008+F010.
- [x] what-breaks: Every click costs wall-clock + flow break. F008-shape walks had 30+ approve clicks on purely technical steps. Sam already established this doctrine for BUILD (`feedback_full_autonomous_build.md`); SPEC + SHIP haven't followed yet.

**Who has this problem:** Sam primarily — solo developer running multi-step SDD features. Every AGENT-LED step in SPEC + SHIP asks "approve?" even when the proposal is purely technical (no product/business/scope call to make). Same pain on every walk. Per Sam's own idea-005 note: "wasting my time and insulting my intelligence."

Future SDD adopters running the framework on bigger workloads hit the same pain — multiplied by their walk count.

**Why now:** Three signals lined up:

1. **F008 + F010 just shipped.** Multi-model (F008) + parallel waves (F010) unlocked drop-the-brief autonomy at the BUILD layer. SPEC + SHIP still require constant approve clicks — bottlenecks the F008+F010 win.
2. **BUILD-autonomy doctrine is already established.** `feedback_full_autonomous_build.md` lives in Sam's memory; Ralph headless mode + full-autonomous Run mode are already shipped. SPEC + SHIP haven't inherited yet.
3. **2026-05-10 idea-005 captured** with explicit Sam quote "wasting my time and insulting my intelligence" — the cost is felt, not theoretical.

**What breaks if we don't solve it:** Two compounding costs:

1. **Wall-clock + flow break on every walk.** F008-shape features (10+ ACs, 30+ tasks) have 30+ approve clicks on purely technical proposals across SPEC + SHIP. Each click is ~10s + a flow-break — adds up to multi-minute friction per walk + breaks the agent's flow-state advantage that F008+F010 just unlocked.
2. **Strategic: framework's biggest leverage stays unused on technical steps.** SDD's leverage is "the agent CAN do most steps unattended." Without auto-advance, that leverage applies only to BUILD. SPEC + SHIP keep the human-in-the-loop on every technical decision the agent could safely make alone.

### action: user-stories

- [x] stories: 4 stories — Sam solo (auto-advance technical SPEC+SHIP), Sam multi-feature (SPEC+SHIP inherits BUILD's full-autonomy), Marco-style adopter (setup-time tier choice), cautious-mode adopter (Checkpoint stays default for new users).

**User stories (4 total):**

1. **Sam solo — auto-advance technical SPEC+SHIP.** As Sam running a single SDD feature, I want technical AGENT-LED steps in SPEC + SHIP to advance automatically (without prompting me for approve), so I am not approving 30+ purely-technical proposals per walk. (Builds on `feedback_decide_dont_ask.md` + `feedback_full_autonomous_build.md`.)

2. **Sam multi-feature — SPEC + SHIP inherits BUILD's autonomy.** As Sam coordinating multiple features at once, I want SPEC and SHIP phases to inherit BUILD's existing full-autonomy default, so my framework handles the full ceremony without me being the bottleneck across N parallel walks.

3. **Marco-style adopter — setup-time tier choice.** As a future SDD adopter scaling up walks, I want a setup-time choice for automation level (`Full` / `Most` / `Checkpoint`), so I can pick the trade-off appropriate for my risk tolerance without editing internal flags.

4. **Cautious-mode adopter — Checkpoint stays default.** As a new SDD adopter learning the framework, I want the default to stay `Checkpoint` (today's behaviour), so I learn each step interactively before opting in to `Full` or `Most`.

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — non-UI feature (framework config-flag + walk-behaviour change; chat-as-UX setup-wizard question is the only user-facing surface, visualised in §13 wireframe per the wireframe-redesign rule, same pattern as F008 + F010).

**§4 skipped:** Auto-advance is a framework-internal walk-behaviour change. The only user-facing surface is the `/sdd-setup` wizard question (one-line CLI prompt + plain-English option list) — chat-as-UX, not visual UI. Visualisation lives in §13 wireframe (flow + architecture + concrete examples) per the v1.2 wireframe-redesign rule.

### action: proposed-approach

- [x] approval: Approach A — leverage existing per-action `requires_user_approval` frontmatter; framework reads `parameters.automation.level` (Full / Most / Checkpoint, default Checkpoint) and applies a 3-way decision tree at /next time. Most-tier gates destructive actions; Checkpoint = today's behaviour. Builds on v1.6.0 PR-C's matrix lock + compounds F008 + F010. Sam approved 2026-05-11.

**Approach A wins — Config-flag toggle (RECOMMENDED, locked):**

Use the EXISTING per-action `requires_user_approval: true|false` frontmatter that every action already has. The framework reads `parameters.automation.level` once per `/next` call and applies one of three decision trees:

- **`full`** → if action has `requires_user_approval: false` AND action slug NOT in destructive list → execute + commit + advance silently. Skip the CTA.
- **`most`** → same as Full BUT destructive-list actions (`mark-shipped`, `manifest: repin` commits, `--delete-branch`, `decisions.md` append, `.shipped` marker, repin) still prompt.
- **`checkpoint`** → today's behaviour (prompts at every AGENT-LED step regardless of frontmatter flag).

Trade-offs:

- ✅ Smallest change — leverages existing frontmatter; just changes `/next`'s decision tree.
- ✅ Per-action flags already audited by their authors during v1.6.0 PR-C work (`requires_user_approval` matrix lock).
- ✅ Backwards compatible — default `checkpoint` = today's behaviour, no change for existing projects.
- ⚠️ One-time audit of every action's `requires_user_approval` flag to confirm correct classification (probably already correct from PR-C; should be cheap).

**Approach B — Explicit `auto-advance: true|false` per-step (rejected).** Add a NEW frontmatter field to every action's step. Most explicit but doubles the frontmatter surface for the same decision. Bigger change for marginal benefit over A.

**Approach C — Tier-driven auto-advance with explicit allowlists (rejected).** Two lists in config.md (allow + deny). Two sources of truth; A's "respect the frontmatter" is simpler and already partially audited.

**Why Approach A wins:**

1. **Pillar 1 (Simplicity).** Smallest delta to the framework: zero new frontmatter fields, just a new config flag + decision-tree in `/next`'s slash command prose.
2. **Builds on PR-C's work.** v1.6.0's `requires_user_approval` matrix lock already audited every action's flag. We get a head start.
3. **Reversible.** Removing the `automation.level` config flag reverts to today's behaviour with no other changes.
4. **Killer compound with F008 + F010.** Full-tier means: SPEC sections auto-advance (technical drafts), F010 dispatches waves automatically, F008's multi-model picks cheap workers — the framework approaches drop-the-brief-walk-away.

**Implementation surface (preview, fleshed out in §14 plan-decompose):**

- **New config field** at `parameters.automation.level` (string: `full|most|checkpoint`, default `checkpoint`).
- **Updated `/sdd-setup`** to ask the automation question + record the answer.
- **Updated `/sdd-config`** to allow changing the tier post-setup.
- **Updated `/next` slash command prose** with the 3-way decision tree (Full/Most/Checkpoint).
- **§11 destructive-actions list** — enumerated in this spec, encoded in `.sdd/config.md` `file_classes` or a sibling allowlist.

### action: data-contract

- [x] approval: 1 new config field (`parameters.automation.level`, string `full|most|checkpoint`, default `checkpoint`). 0 new project-state entities. 1 new framework-level concept (`AutomationLevel`, typed string — NOT a data-model.md entity, analogous to BUILD's `Run mode`). 0 new fields on existing entities. 3 edge cases at data layer: backward compat (no flag = checkpoint); downgrade mid-walk (subsequent /next respects new level, no persistent walk-state); mark-shipped keeps approve gate even at Full per §11 destructive-actions list. Sam approved 2026-05-11.

**Draft (pre-filled from brief; awaiting /next approval):** One new config field, no new entities.

- **New config field:** `parameters.automation.level` (string: `full | most | checkpoint`, default `checkpoint`). Lives under `parameters:` in `.sdd/config.md`, alongside the existing `pace.halt_on_red_after_attempts`, `ralph.timeout_per_iter`, etc.
- **No new project-state entities** (spec.md, INDEX.md, decisions.md, patterns.md, etc. unchanged). The `requires_user_approval` frontmatter per-action already exists on every action file; this feature changes the DEFAULT BEHAVIOUR the framework applies when reading those flags based on the chosen tier.
- **One new framework-level concept** (NOT an entity in `data-model.md`, just a typed string): `AutomationLevel` (`full | most | checkpoint`). Analogous to BUILD's `Run mode` (today's "Shell Ralph / Conversation / Checkpoint" choice) but applied to SPEC + SHIP too.
- **Existing entities** (Action, Playbook, Hook, Setup brick, Pi extension package, Wave [F010]): no new fields.
- **Edge cases at the data layer:** (1) backward compat — existing projects with no `parameters.automation.level` default to `checkpoint`; (2) downgrade — adopter switches `full → checkpoint` mid-walk; subsequent /next calls respect the new level (no persistent state for "this walk started at Full"); (3) `mark-shipped` keeps the approve gate even at Full (per the §11 destructive-action list).

### action: flows

- [x] flows: 3 flows — Flow 1: User picks automation level at setup (`/sdd-setup` or `/sdd-config` → wizard → writes `parameters.automation.level`); Flow 2: Full-tier auto-advance (`/next` skips approve CTA when action `requires_user_approval: false` AND not destructive); Flow 3: Most-tier destructive gate (action on destructive list still prompts even at Most). Sam approved 2026-05-11.

**Draft (pre-filled from brief; awaiting /next approval):** 3 flows.

1. **Flow 1 — User picks automation level at setup** (user story #3). User runs `/sdd-setup` (new project) or `/sdd-config` (existing project) → wizard asks "Automation level for AGENT-LED steps? [Full / Most / Checkpoint]" with a 1-paragraph plain-English description of each tier → user picks → `.sdd/config.md` writes `parameters.automation.level: <tier>` → subsequent /next calls respect it.

2. **Flow 2 — /next walks an AGENT-LED step under `full`** (user stories #1, #2). /next resolves the next blocker → AGENT-LED step. Framework reads `automation.level: full`. Framework reads action's `requires_user_approval: false` (default for technical actions) AND the action isn't on the destructive list (§11 enumerates) → /next executes the step's body (agent proposes + commits) WITHOUT prompting Sam for approve. Reports done; advances to next step.

3. **Flow 3 — /next walks an AGENT-LED step under `most` against a destructive action** (Most tier safety gate). Same as Flow 2 BUT the action's slug matches the §11 destructive list (e.g. `mark-shipped`, manifest-repin commits, `--delete-branch` merges, `decisions.md` append). Framework still prompts Sam for approve, even though `automation.level: most` would otherwise auto-advance. Reports the gate reason ("destructive action under Most tier — confirm").

### action: dependencies

- [x] deps: Hard — existing per-action `requires_user_approval` frontmatter (on every action file), `/sdd-setup` + `/sdd-config` commands (need new automation question), `config.md` `parameters:` structure (need new `automation:` subsection), `resolve-parameters.sh` (needs to expose the new field). Soft — F008 (multi-model) + F010 (parallel waves) — pays full dividend when both in use. Explicitly NOT — no new MCP, no new npm packages, no new entities in `data-model.md`, no new harness API, no commit-shape changes. Sam approved 2026-05-11.

**Draft (pre-filled from brief; awaiting /next approval):** Three buckets.

**Hard deps (must work for 011 to ship):**
- Existing per-action `requires_user_approval` frontmatter on every action file under `.sdd/actions/`. (Already in place across all v1.6.0 actions.)
- Existing `/sdd-setup` wizard (needs extension with the new "automation level" question — see Flow 1).
- Existing `/sdd-config` slash command (needs extension for changing the tier post-setup).
- Existing `config.md` `parameters:` structure (needs new `automation:` subsection).
- Existing `.sdd/scripts/resolve-parameters.sh` (needs to expose `parameters.automation.level` to actions/next.sh).

**Soft deps:**
- F008 (multi-model) + F010 (parallel waves) — this feature pays full dividend when those are in use. Without them, auto-advance is still useful but compounds less.

**Explicitly NOT depending on:**
- No new MCP servers, no new npm packages, no new entities in `data-model.md`.
- No new harness API (works identically on Claude Code + pi.dev via F008).
- No changes to commit shape — every auto-advanced step still lands as its own `[SDD:<id>] spec: <action>/<step>` commit.

### action: out-of-scope

- [x] list: 5 explicit deferrals — (1) per-step `auto-advance:` frontmatter (Approach B from §5); (2) explicit allow/deny lists (Approach C from §5); (3) per-feature override (e.g., feature frontmatter overrides project default); (4) decision-tree audit logging (which steps auto-advanced vs prompted); (5) misclassified `requires_user_approval` flag audit-and-fix sweep (trust v1.6.0 PR-C's matrix lock).
- [x] approval: Sam approved 2026-05-11.

**Out of scope — 5 explicit deferrals:**

1. **Per-step `auto-advance:` frontmatter (Approach B from §5).** Explicitly rejected — leverage existing `requires_user_approval` instead. Approach A wins on smallest-delta + leverages PR-C's matrix lock.
2. **Explicit allow/deny lists (Approach C from §5).** Rejected — two sources of truth; Approach A's "respect the frontmatter" is simpler and already partially audited.
3. **Per-feature override.** Today a project sets one `parameters.automation.level`. A feature can't override (e.g., "this risky feature uses Checkpoint even though the project is Full"). Not in scope for v1; can ship later if friction surfaces — design space: feature-level frontmatter `automation_level:` field, OR a `/sdd-config --feature 011 full` per-feature override command.
4. **Decision-tree audit logging.** Today there's no record of which steps auto-advanced vs prompted under which tier. Could ship as a follow-up observability feature (Append a marker line to `decisions.md` or a sibling `.sdd/.cache/automation.log` per step). Not blocking — git log still shows every commit; just doesn't say "auto-advanced under Full".
5. **Misclassified `requires_user_approval` flag audit-and-fix sweep.** Out of scope to audit-and-fix every action's frontmatter flag. We trust v1.6.0 PR-C's existing matrix lock. If misclassified flags surface in usage (e.g., a "technical" action turns out to need product judgement), file as bugs against that action; don't block 011.

### action: non-functional

- [x] constraints: Performance — zero-cost runtime (one config flag read per /next, cached via resolve-parameters.sh; no new network/IO). Security — default stays Checkpoint (backwards compat); Most-tier destructive-action gate (mark-shipped, manifest-repin commits, --delete-branch, decisions.md append, .shipped marker, repin commits — all still prompt under Most); trust-boundary markers ([FRAMEWORK INSTRUCTIONS] / [PROJECT DATA]) unchanged; audit trail preserved via standard `[SDD:<id>] spec: <action>/<step>` commit shape. Compliance — MIT unchanged, no PII collected, no new telemetry, local-only config flag. Sam approved 2026-05-11.

**Draft (pre-filled from brief; awaiting /next approval):**

**Performance:**
- Zero-cost at runtime — `parameters.automation.level` is a config flag read once per `/next` call (cached via `resolve-parameters.sh`). Same orchestrator turn count as today.
- No new network calls, no new file I/O beyond the existing config.md read.

**Security:**
- **Default stays `checkpoint`** (today's behaviour) — backwards compat. Existing projects don't change unless adopter opts in.
- **`most` tier destructive-action gate** — `mark-shipped`, manifest-repin commits, `--delete-branch` merges, append-only `decisions.md` edits, `.shipped` marker writes, and `pre-commit-stage-verified.sh` repin commits all STILL prompt under `most` (even when their per-action flag would auto-advance under `full`).
- **Trust-boundary markers unchanged** — `[FRAMEWORK INSTRUCTIONS]` / `[PROJECT DATA]` markers preserved on every auto-advanced step.
- **Audit trail preserved** — every auto-advanced step lands its own atomic commit with the same `[SDD:<id>] spec: <action>/<step>` shape, so `git log` is still the audit-of-record. Auto-advance changes WHO triggers the commit (framework vs user) but not the commit shape or content.

**Compliance:**
- MIT license unchanged.
- No new PII, no new telemetry — auto-advance is local config-flag behaviour only.

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
