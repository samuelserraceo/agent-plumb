---
playbook: feature
---

# auto-advance AGENT-LED steps

[PHASE: SHIP]

**Active blocker:** SHIP action: verify-test-run

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

- **`full`** → if action has `requires_user_approval: false` → execute + commit + advance silently. Skip the CTA. (Destructive list is NOT consulted at Full; the per-action `requires_user_approval: true` flag is the only gate. Destructive actions are classified `true` in v1.6.0's matrix, so they prompt under Full via the flag.)
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

- [x] approval: 1 new config field (`parameters.automation.level`, string `full|most|checkpoint`, default `checkpoint`). 0 new project-state entities. 1 new framework-level concept (`AutomationLevel`, typed string — NOT a data-model.md entity, analogous to BUILD's `Run mode`). 0 new fields on existing entities. 3 edge cases at data layer: backward compat (no flag = checkpoint); downgrade mid-walk (subsequent /next respects new level, no persistent walk-state); single destructive-gate rule — under `most` the §11 `destructive_actions` list is the gate (overrides per-action flag); under `full` the per-action `requires_user_approval: true` frontmatter is the only gate; destructive actions (mark-shipped, manifest-repin, --delete-branch, decisions.md append, .shipped marker) happen to be classified `requires_user_approval: true` in v1.6.0's matrix lock, so they end up gated under both tiers — but via two distinct mechanisms (the §11 list is NOT a Full-tier guard). Sam approved 2026-05-11.

**Draft (pre-filled from brief; awaiting /next approval):** One new config field, no new entities.

- **New config field:** `parameters.automation.level` (string: `full | most | checkpoint`, default `checkpoint`). Lives under `parameters:` in `.sdd/config.md`, alongside the existing `pace.halt_on_red_after_attempts`, `ralph.timeout_per_iter`, etc.
- **No new project-state entities** (spec.md, INDEX.md, decisions.md, patterns.md, etc. unchanged). The `requires_user_approval` frontmatter per-action already exists on every action file; this feature changes the DEFAULT BEHAVIOUR the framework applies when reading those flags based on the chosen tier.
- **One new framework-level concept** (NOT an entity in `data-model.md`, just a typed string): `AutomationLevel` (`full | most | checkpoint`). Analogous to BUILD's `Run mode` (today's "Shell Ralph / Conversation / Checkpoint" choice) but applied to SPEC + SHIP too.
- **Existing entities** (Action, Playbook, Hook, Setup brick, Pi extension package, Wave [F010]): no new fields.
- **Edge cases at the data layer:** (1) backward compat — existing projects with no `parameters.automation.level` default to `checkpoint`; (2) downgrade — adopter switches `full → checkpoint` mid-walk; subsequent /next calls respect the new level (no persistent state for "this walk started at Full"); (3) destructive-gate rule — single source of truth per tier: under `most` the §11 `destructive_actions` list IS the gate (it overrides each action's `requires_user_approval` flag); under `full` the per-action `requires_user_approval: true` frontmatter IS the gate (the §11 list is NOT consulted at Full). Destructive actions like `mark-shipped`, manifest-repin commits, `--delete-branch`, `decisions.md` append, and `.shipped` marker happen to be classified `requires_user_approval: true` in v1.6.0's matrix lock, so they're gated under both tiers — but the GATING MECHANISM differs by tier. Documented this way after CR cycle-1 #1 + cycle-3 #2 corrections.

### action: flows

- [x] flows: 3 flows — Flow 1: User picks automation level at setup (`/sdd-setup` or `/sdd-config` → wizard → writes `parameters.automation.level`); Flow 2: Full-tier auto-advance (`/next` skips approve CTA when action `requires_user_approval: false`; destructive list is NOT consulted at Full); Flow 3: Most-tier destructive gate (action on §11 destructive list still prompts under Most regardless of per-action flag). Sam approved 2026-05-11.

**Draft (pre-filled from brief; awaiting /next approval):** 3 flows.

1. **Flow 1 — User picks automation level at setup** (user story #3). User runs `/sdd-setup` (new project) or `/sdd-config` (existing project) → wizard asks "Automation level for AGENT-LED steps? [Full / Most / Checkpoint]" with a 1-paragraph plain-English description of each tier → user picks → `.sdd/config.md` writes `parameters.automation.level: <tier>` → subsequent /next calls respect it.

2. **Flow 2 — /next walks an AGENT-LED step under `full`** (user stories #1, #2). /next resolves the next blocker → AGENT-LED step. Framework reads `automation.level: full`. If the action's `requires_user_approval: false`, /next executes the step's body (agent proposes + commits) WITHOUT prompting Sam for approve. Reports done; advances to next step. The §11 destructive list is NOT consulted at Full — per-action flag is the only gate; destructive actions already carry `requires_user_approval: true` in v1.6.0's matrix so they prompt via the flag.

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

- [x] approval: 10 ACs (AC1-AC10), each with `{verify-by: T-NNN}` / `{best-effort: <who>}` / `{prod-only: <why>}` annotation per anti-theatre. T300-T306 reserved for 7 mechanical ACs; AC8 best-effort named-eye at SHIP; AC9-10 PROD-ONLY at SHIP (real-session walk under Full / Most-tier destructive gate). Coverage maps to §10 non-functional (perf cached read = AC1+AC2; backward-compat default = AC1; destructive gate = AC10; audit trail unchanged = implicit in commit-shape preservation). Sam approved 2026-05-11.

**Acceptance criteria (10 ACs):**

**Mechanically verifiable (7 ACs):**

- **AC1 — Default tier is `checkpoint`.** Fresh project (no `parameters.automation.level` in `.sdd/config.md`) → `resolve-parameters.sh` returns `checkpoint`. {verify-by: T300}
- **AC2 — Config field accepts `full | most | checkpoint`.** `resolve-parameters.sh parameters.automation.level` returns the configured tier when set to any of the three valid values. {verify-by: T301}
- **AC3 — Invalid tier rejected.** Setting `parameters.automation.level: invalid` → `resolve-parameters.sh` errors with a clear message + falls back to `checkpoint`. {verify-by: T301}
- **AC4 — `/sdd-setup` includes the automation question.** Setup wizard prose contains an "Automation level" question with Full/Most/Checkpoint options + plain-English description of each tier. {verify-by: T303}
- **AC5 — `/sdd-config` supports tier change.** `/sdd-config automation full` updates `.sdd/config.md` to `parameters.automation.level: full`. {verify-by: T304}
- **AC6 — `/next` slash command prose contains the 3-way decision tree.** `.claude/commands/next.md` (or templates equivalent) describes: "if tier=full AND action.requires_user_approval=false → auto-advance; else if tier=most AND action in destructive list → prompt; else if tier=most → auto-advance; else if tier=checkpoint → prompt". {verify-by: T305}
- **AC7 — Destructive-actions list is enumerated in `.sdd/config.md`.** `.sdd/config.md` contains a section/field listing destructive action slugs: `mark-shipped`, `manifest-repin`, `--delete-branch`, `decisions.md-append`, `.shipped-marker`, `repin`. {verify-by: T306}

**Best-effort named-eye (1 AC):**

- **AC8 — Existing per-action `requires_user_approval` flags correctly classify SPEC + SHIP actions.** Manual audit of all `.sdd/actions/*.md` confirms each action's flag matches the doctrine ("technical → false; product/business/scope/destructive → true"). {best-effort: Sam at SHIP — eye-check the matrix}

**PROD-ONLY (2 ACs):**

- **AC9 — Real-session walk under Full tier completes a feature without prompts on technical actions.** In a real Claude Code session with `automation.level: full`, walking a fixture feature's SPEC → BUILD → SHIP triggers no approve CTAs on AGENT-LED steps marked `requires_user_approval: false`. Product-judgement steps still prompt. {prod-only: requires live agent session at first-SHIP walk}
- **AC10 — Most-tier destructive gate fires on mark-shipped.** In a real Claude Code session with `automation.level: most`, reaching mark-shipped on a fixture feature triggers an approve CTA via the §11 `destructive_actions` list — even though Most otherwise auto-advances every AGENT-LED step regardless of per-action flag. Under `full`, mark-shipped's gate comes from its `requires_user_approval: true` frontmatter (v1.6.0 matrix classification), not from the destructive list. {prod-only: requires live agent session at first-SHIP walk}

### action: signoff-steps

- [x] manual-steps: 4 manual checks before SHIP — (1) fresh-install smoke (AC1+AC2+AC4); (2) real-session Full-tier walk (AC9 PROD-ONLY); (3) Most-tier destructive gate at mark-shipped (AC10 PROD-ONLY); (4) AC8 named-eye matrix audit of `requires_user_approval` flag across all `.sdd/actions/*.md`.

### action: wireframe

- [x] wireframe: non-UI wireframe.html from v1.2 wireframe-non-ui skeleton (277 lines). Shows the 3-way decision tree (Full/Most/Checkpoint), the new setup-wizard question, the 3 flows from §7, and the destructive-actions list. Out-of-scope panel mirrors §9. Sam to refine post-CR if shape unclear.

### action: plan-decompose

- [x] tasks: 7 ordered T-tasks T300-T306, one-per-mechanical-AC. T300 walking-skeleton (resolve-parameters.sh exposes new field). T301-T306 are largely independent files (different scripts / setup prose / config command / /next prose / config.md sections) — eligible for `[WAVE: 1]` dispatch once F010 fully lands. AC8 named-eye + AC9/AC10 PROD-ONLY at SHIP — no T-task.

**BUILD task plan — 7 ordered T-tasks (one test file per mechanical AC):**

```text
- [x] T300: resolve-parameters.sh exposes parameters.automation.level
            with default `checkpoint` when unset
            — proves AC1 + AC2
- [x] T301: resolve-parameters.sh accepts all 3 valid tier values
            (full / most / checkpoint), rejects invalid + falls back
            to checkpoint with clear error message
            — proves AC2 + AC3
- [x] T302: .sdd/config.md (live + template) gains a new
            parameters.automation: section with documented default
            (checkpoint) + plain-English description of each tier
            — proves AC7 groundwork + supports AC4/AC5
- [x] T303: /sdd-setup wizard adds an "Automation level" question
            with Full/Most/Checkpoint options + plain-English
            descriptions; writes parameters.automation.level on user
            answer
            — proves AC4
- [x] T304: /sdd-config supports `automation <tier>` subcommand to
            change parameters.automation.level post-setup
            — proves AC5
- [x] T305: .claude/commands/next.md (live + template) gains the
            3-way decision tree section (full/most/checkpoint)
            describing when to auto-advance vs prompt
            — proves AC6
- [x] T306: .sdd/config.md (live + template) lists the destructive-
            actions enumeration under parameters.automation.
            destructive_actions or sibling field
            — proves AC7
```

**Order rationale:** foundation first (T300/T301/T302 config-layer plumbing), then user-facing surface (T303 setup + T304 config commands), then the decision tree itself (T305 /next prose), then the destructive-actions enumeration (T306). T306 depends on T302's structure being in place.

**Walking-skeleton T01:** T300 — `resolve-parameters.sh` exposes the new field. Smallest end-to-end thread.

**Wave dispatch (F010 unlock):** T301/T302/T303/T304/T305/T306 are largely independent (different files: `.sdd/scripts/resolve-parameters.sh`, `.sdd/config.md`, `templates/.sdd/setup/`, `.claude/commands/sdd-config.md`, `.claude/commands/next.md`, `.sdd/config.md` again). Could mark `[WAVE: 1]` on T301-T306 once F010 fully lands + the framework-self-mod four-step dance is documented. For v1 ship them linearly — the dance per F010's lessons takes care to get right.

PROD-ONLY AC9 + AC10 + best-effort AC8 = no T-task; verified at SHIP via §12 signoff steps.

### action: edge-case-sweep

- [x] ec-sweep: 7 edge cases — (1) per-action `requires_user_approval: true` overrides tier-Full; (2) mid-walk tier change; (3) misclassified destructive action; (4) new action added post-AC7; (5) empty-string tier value; (6) pi.dev parity; (7) sealed framework file tamper.
- [x] ec-pick: 0 new ACs added (§11 hash-locked). 4 folded into existing ACs/tests (#2 → AC2, #3 → AC7, #5 → T301, #6 → AC9). 2 documented at SHIP (#1, #4). 1 already-covered (#7 by pre-commit-stage-verified.sh).

**Edge-case sweep — 7 candidates:**

| # | Edge case | Risk | Mitigation |
|---|---|---|---|
| 1 | User sets tier=Full but a per-action `requires_user_approval: true` flag exists | Medium | Frontmatter flag wins (per-action override). Documented in §5. |
| 2 | Mid-walk tier change (Full → Checkpoint during BUILD) | Low | `/next` re-reads tier per call (cached but invalidates on config.md change). Subsequent steps respect new tier. |
| 3 | Destructive action with `requires_user_approval: false` (misclassified) | Medium | Destructive list (AC7) gates regardless of frontmatter — flag is overridden by the destructive list at Most. Filed as bug if surfaces. |
| 4 | New action added post-AC7 not in destructive list but should be | Low | T306 documents how to add a slug to the enumeration. Future actions should think about destructive-ness at creation time. |
| 5 | `parameters.automation.level:` (empty string) | Low | Treated same as unset → default `checkpoint`. T301 fixture covers this. |
| 6 | `pi.dev` harness behaves differently than Claude Code on auto-advance | Medium | Both harnesses execute `/next` via the same SDD framework brain; tier check is in the brain, not harness-specific. Verified at SHIP (folded into AC9 PROD-ONLY scope). |
| 7 | Auto-advance under Full skips a step that touches a sealed framework file (manifest repin) | Low | Already in destructive list — manifest-repin commits prompt under Most. Under Full, the framework-tamper hook would still fire on the commit attempt (`pre-commit-stage-verified.sh`). |

**ec-pick disposition (Sam approved 2026-05-11):**

- **#1 (per-action flag override)** — Already covered by §5 Approach A's "respect the frontmatter" rule. No new AC.
- **#2 (mid-walk tier change)** — Folded into AC2 (`/next` reads tier per call).
- **#3 (misclassified destructive)** — Folded into AC7 (destructive list gates regardless).
- **#4 (new action enumeration)** — Documented at SHIP in `patterns.md` ("when adding a new action, classify it for the destructive list if applicable").
- **#5 (empty string)** — Folded into T301 fixture.
- **#6 (pi.dev parity)** — Folded into AC9 PROD-ONLY (the real-session walk should also run on pi.dev once F008's adapter is stable).
- **#7 (sealed framework file tamper)** — Already covered by existing `pre-commit-stage-verified.sh` hook; no new AC.

**Net effect:** 0 new ACs (§11 stays hash-locked). 4 folded into existing T-tasks (#2 → AC2; #3 → AC7; #5 → T301; #6 → AC9). 2 documented at SHIP (#1, #4). 1 already-covered (#7).

### Exit checks

- [x] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [x] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: Full autonomous in this session — orchestrator (this Claude) cranks T300-T306 linearly with test → code (+ repin dance for framework-script mods) → green commits. Same shape as F010's mid-SHIP recovery, smaller scope. Sam approved "manual fast" 2026-05-11.

**Run mode:** Full autonomous (this session, manual orchestration)

### action: build-task

(driven by §14 tasks T300-T306 — each task lands as one commit)

### Exit checks

- [x] C-build-tasks-green: T300-T306 all GREEN; framework tests pass {verify-by: verify-stage.sh}

## PHASE: SHIP

### action: verify-test-run

- [x] run-tests: 218/218 framework tests pass + 7/7 F011 per-feature tests (T300-T306)

### action: learn

- [x] summary: F011 adds `parameters.automation.level` (full/most/checkpoint, default checkpoint) + a destructive-actions enumeration in `.sdd/config.md`; the setup wizard's new 008-automation-level brick lets the user pick a tier at project start; `/sdd-config automation <tier>` changes the level post-setup; `/next`'s prose gains a 3-way decision tree describing when to auto-advance AGENT-LED steps vs prompt. F011 is documentation-shape — no runtime daemon; the agent reads the doctrine each turn from CLAUDE.md + the slash-command prose and applies it. Pairs with F008 (multi-model) + F010 (parallel waves) to deliver the drop-the-brief-walk-away shape Sam asked for. Backwards-compat: every existing project that has not picked a tier keeps today's checkpoint behaviour {verify-by: T300}.
- [x] lessons: 3 patterns appended to .sdd/patterns.md — documentation-shape features ship as slash-command prose; resolve-parameters framework-defaults must handle empty-string AND unset; grep -F still parses leading-dash and leading-dot args as flags

### action: push-pr

- [x] push-and-open: PR #236 opened — https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/236

### action: verify-ci-green

- [ ] ci: all CI checks GREEN on the PR

### action: mark-shipped

- [ ] shipped: INDEX.md updated, .shipped marker written, decisions.md appended

### Exit checks

- [ ] C-ship-pr-url: PR URL recorded in INDEX.md Shipped section {verify-by: verify-stage.sh}
- [ ] C-ship-marked: .shipped marker file exists in feature folder {verify-by: verify-stage.sh}
