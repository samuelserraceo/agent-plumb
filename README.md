# Spec-Driven Development Workflow (SDD)

> A stupidly simple, agent-driven workflow for building real software with AI without the AI making stuff up.
> **The state file is the program. The playbook is the questioning agent. The filesystem is the retrieval system.**
> No orchestrator, no database, no RAG, no magic.

📖 **[Read the v1.0 → v1.9 walkthrough →](docs/walkthrough.html)** — single-page entry-point with an interactive architecture diagram, three reader-driven foundation-validation checks, and a review mode you can use to flag sections and export feedback. Best opened in a browser. Current as of v1.8.3 + v1.9 ship-batch (multi-model adapter, auto-advance steps, MCP-doctrine sentinel, /sdd-verify-stack post-wizard reality check, /ship CR convergence gate, lego-style model-tier-per-action, specialised subagents).

---

## What this solves

If you've used Claude Code, Cursor, Lovable, or any other AI coding tool, you've probably had this happen:

- You asked for X, the AI built X **plus a fake "47 founders on the wait list" counter you never wanted**.
- The AI shipped something that technically works but **misunderstood your intent**.
- The agent quietly **softened a section you'd already approved** to make verification easier.
- Six months later you can't remember **why** the AI picked one tech over another.
- Documentation drifted. Schema drifted. Tests skipped.

SDD makes the wrong path **mechanically impossible**, not just discouraged. The agent literally cannot commit code that drifts from its spec, because git pre-commit hooks refuse the commit. The "moat" hook re-runs your verification checks on every commit and blocks any "the agent claims it works" assertion that doesn't match what fresh tests actually report.

You bring the *what* (in plain English). The agent proposes the *how* (with tradeoffs you can react to). Every decision is captured in markdown files you can read, share with an investor, hand to a future engineer, or rebuild in a different stack.

---

## What SDD is — and isn't (explicit tradeoff)

SDD is opinionated. It optimises for some things and gives up others. Knowing the trade upfront prevents misunderstanding:

**SDD optimises for:**
- **Honest review over fast iteration.** Every step's content + commit shape is reviewable. Re-approval ceremony for changed approved sections. Append-only audit log. Mutation-verified tests.
- **Plain English over technical precision.** Non-technical users drive specs; jargon gets translated on first use; status output reads in 30 seconds.
- **Explicit over clever.** Each step declares its tag, its touches, its triggers. No magic. No discovery.
- **Predictability over flexibility.** Same 4-step inner loop every iteration. Same commit shape. Customisation = adding rows in the standard format, not changing the format.

**SDD explicitly gives up:**
- **Power-user ergonomics.** Engineer-comfortable shorthand isn't here.
- **One-shot speed.** A SPEC takes 30–90 minutes the first time. The wrong choice for "I want it built right now."
- **Technical-precision in prose.** Hook stderr says *"the database can't be reached so the form shows 'please try again'"* — not *"DB unreachable, returning 503."*
- **Free-form architecture.** Side-stepping the rubric isn't allowed. Skip a section explicitly with a reason or stay in the discipline.

---

## The 3-phase spine (v0.9)

```bash
SPEC → BUILD → SHIP → SHIPPED
  ↑              ↓
  └── (bug task) ← CI fail
```

Each phase has its own actions (small focused steps). You can never skip a phase. You can never advance while the current phase has unanswered `[ ]` blockers — the safety net (the `pre-commit-rules.sh` enforcer with state_rules) refuses the commit.

| Phase | Actions inside (sample) | What happens |
|---|---|---|
| **SPEC** | problem · success · user-stories · ux-brief · proposed-approach · data-contract · acceptance-criteria · plan-decompose · … | Agent walks the playbook. Asks you the *what* (problem, users, success). Proposes the *how* (tech, data, flows) with tradeoffs. You approve. Last action turns ACs into BUILD tasks. |
| **BUILD** | run-mode-chosen · build-task (×N) | Strict test-first. Write the test (must fail) → write the code → test passes → commit. One task at a time. |
| **SHIP** | verify-test-run · verify-prod-only-acs · learn · push-pr · verify-ci-green · mark-shipped | Run all tests. Capture lessons. Open the PR. Watch CI. Mark feature cold. Update institutional memory. |

**v0.9 atomic-step granularity (F4):** each `[ ]` row in spec.md is one atomic step = one commit. The agent advances exactly one step per `/next`.

---

## Quick start

### Option A — Claude Code plugin (recommended for teams)

```bash
# In Claude Code, add the marketplace (your team's git URL or this repo)
/plugin marketplace add https://github.com/samuelserraceo/spec-driven-dev-workflow
/plugin install sdd@sdd-marketplace

# After install, slash commands and hooks are available immediately.
# To set up SDD inside a project:
/sdd-setup
```

To pull in framework updates later (refresh `.sdd/` from upstream):

```bash
bash .sdd/scripts/sdd-migrate.sh --upstream=<path-to-sdd-framework-checkout>           # dry-run
bash .sdd/scripts/sdd-migrate.sh --apply --upstream=<path-to-sdd-framework-checkout>   # apply
```

The migrate tool keeps your `INDEX.md` / `decisions.md` / `patterns.md` / `data-model.md` / `stack.md` / `principles.md` / `.sdd/features/**` untouched. Read the [feature 007 wireframe](.sdd/features/007-sdd-migrate-refresh-project-s-sdd-tree-from-upstream-framework/wireframe.html) for the full categorisation flow.

### Option B — manual clone + scaffold

### 1. Clone SDD somewhere stable

```bash
git clone https://github.com/samuelserraceo/spec-driven-dev-workflow ~/Projects/sdd
```

### 2. Drop SDD into your project

Requires Python 3 with PyYAML (`pip install pyyaml`) — the framework's scripts and hooks parse YAML.

```bash
cd <your-project>
~/Projects/sdd/scripts/init.sh
```

This adds a `.sdd/` folder, a `.claude/` folder, a project-root `CLAUDE.md`, and runtime scripts (`scripts/ralph.sh`, `scripts/ship.sh`).

### 3. Open Claude Code in your project

```bash
claude
```

A banner shows the current state. On a fresh project: *"No active feature."*

### 4. Start your first work item

```
/start build a waitlist landing page
```

`/start` is the single entry point for new work. It scaffolds the work item folder, writes a `spec.md` skeleton with per-step `[ ]` rows under each action heading, updates `INDEX.md`, and tells you the exact `/next` to run first. On first install, it sets `git config core.hooksPath .claude/hooks` (with a halt-and-ask if your project already uses Husky / lefthook / a custom hooks tool).

**For evolving a shipped feature** rather than starting fresh:

```
/start --extends=001 add referral codes to the waitlist
```

The new spec.md frontmatter records `extends:`, and `mark-shipped` writes a richer `## Shipped` block with cross-references — see *The catalog* below.

### 5. Walk the playbook

```
/next
```

The agent advances by one atomic step per `/next`. Each step is one commit. USER-LED steps ask you in plain English (common patterns offered as multiple choice with a free-form escape). AGENT-LED steps propose a concrete answer with at least 2 alternatives; you push back or approve. BUILD-TASK steps run test-first.

When SPEC is fully filled, the agent transitions you to BUILD. At BUILD entry the agent asks **how you want to run it**:

1. **Step-by-step** — pause after every task
2. **Checkpoint every 5** (recommended) — auto-loop, pause every 5 tasks for review
3. **Full autonomous** — agent loops in the session until done or blocked
4. **Shell Ralph** — `./scripts/ralph.sh` in a terminal, fresh Claude per task, walk away for hours

### 6. Ship

```
/ship
```

Pushes the branch, opens a PR, watches CI. On pass: marks shipped, distills the feature to a rich one-liner block in INDEX with cross-references, marks the feature folder cold. On fail: captures the CI error as a bug task, flips back to BUILD.

### Optional: open in Obsidian for the graph view

The framework ships a minimal `.obsidian/` config so you can open the project root in [Obsidian](https://obsidian.md) and immediately see your project as a connected graph: features → decisions → patterns → data-model entries, colour-coded by type. No setup beyond opening the folder.

If you also use **Copilot for Obsidian** or **Smart Connections** (Brian Petro's), they work normally over the `.sdd/` markdown content — useful for asking *"why did we pick Postgres on this project?"* and getting the right decision quoted back. The framework doesn't auto-configure those plugins; install + connect them yourself. Wiring SDD's MCP server semantic search to the same model is on the v1.x roadmap (closes that gap once an embedding model is settled on).

### Dogfood — the framework runs SDD on itself

From v1.0, the framework's own work-items walk SDD's SPEC → BUILD → SHIP loop. This repo has **two `.sdd/` paths**:

- **`templates/.sdd/`** — the framework SOURCE that gets shipped to consumer projects. Editing here changes what every consumer gets on their next `scripts/init.sh` run.
- **`.sdd/` at repo root** — the framework's OWN consumer state. `INDEX.md`, `decisions.md`, `data-model.md`, `patterns.md`, `stack.md`, plus a copy of the framework files (`playbooks/`, `actions/`, `scripts/`) so `/start` and `/next` work on the framework's own work-items.

When you edit a framework file in `templates/.sdd/`, the in-sync test (T120 in `test/run-framework-test.sh`, headed `# T120 — SDD self-host parity`) reminds you to update the matching file in `.sdd/` too. The framework eats its own dog food: a fix that hurts to ship through SDD on this repo would hurt the same way for any consumer, and we feel it first.

---

## Slash commands at a glance

| Command | What it does |
|---|---|
| `/sdd-setup` | First-session setup wizard. Walks plain-English questions and fills `stack.md` + `config.md`. Run **once** when bootstrapping a fresh SDD project, before your first `/start`. |
| `/sdd-config [<question-id>]` | Re-answer a single setup question without re-running the full wizard. Use when stack changes (new service, new reviewer, new hosting target). |
| `/start <title>` | Scaffold a new work item. Pass `--extends=<id>` for evolution of an existing feature. |
| `/next` | Advance the active work item by one step. Also handles inline skip / re-approve / bug-routing — see /next.md. |
| `/idea` | Capture an idea cheaply — no phase, no branch, just a small file in `.sdd/ideas/`. |
| `/status` | Print the current workflow state + resolved F5 parameters with provenance source. |
| `/settings` | List/get/set/reset framework settings without editing `config.md` by hand. Bare `/settings` lists everything; `get <key>` / `set <key> <value>` / `reset <key>` for targeted edits. |
| `/ship` | Push branch, open PR, watch CI, mark shipped or capture bug. |
| `/compress` | Consolidate `patterns.md` or `data-model.md` when they grow noisy. |

The agent picks the right command from your wording — you rarely type them yourself. v0.9 retired `/bug`, `/re-approve`, and `/skip` — the framework's "Triage on first message" rule routes new requests, and `/next` handles re-approval + skip inline.

---

## The 4-step inner loop (v0.9 atomic-step)

Every `/next` runs the same 4-step container:

| Step | What |
|---|---|
| **LOCATE** | Read `INDEX.md` → find active work item → find next `[ ]` step row in `spec.md` → load that step's frontmatter from the action library. |
| **EXECUTE** | Variable shape per action `tag:`. USER-LED asks. AGENT-LED proposes/iterates. BUILD-TASK does test-first. |
| **SYNC** | Action's `touches:` files staged. Hook chain refuses otherwise. |
| **ADVANCE** | Flip `[ ]` → `[x]`. Commit. Fire `triggers:` (e.g., `section_approved` → append decisions.md). |

Cognitive prep before the commit is free-form (multi-turn iteration allowed for AGENT-LED). The framework only enforces commit shape: one step = one commit.

---

## What's in the box (v0.9)

```
.
├── README.md
├── .github/workflows/sdd-ci.yml             # framework tests + scope-guard on PRs
├── templates/                               # what init.sh drops into your project
│   ├── CLAUDE.md                            # workflow rules (managed) + your project rules (yours)
│   ├── DEPRECATED.list                      # files removed in each version (used by update.sh)
│   ├── migrations/                          # per-version migration scripts
│   ├── .sdd/
│   │   ├── INDEX.md                         # work-item catalog (Active + Shipped with cross-references)
│   │   ├── config.md                        # per-project config (parameters / events / file_classes /
│   │   │                                       co_stage_block / file_rules / state_rules / folder_rules /
│   │   │                                       closed enums / hash normalisation)
│   │   ├── playbooks/feature.md             # the v0.9 feature playbook
│   │   ├── actions/*.md                     # 22 action files (the playbook's body)
│   │   ├── decisions.md                     # append-only audit log
│   │   ├── data-model.md                    # canonical schema, single source of truth
│   │   ├── patterns.md                      # cross-feature learnings
│   │   ├── CLAUDE.version                   # current SDD version
│   │   ├── .cache/manifest.json             # hash-pinned framework files (tamper detection)
│   │   ├── archive/                         # frozen history (compressed patterns, old shipped)
│   │   ├── ideas/                           # captured ideas, one file each
│   │   └── scripts/                         # advance · hash-section · load-playbook · next-action ·
│   │                                          read-events · resolve-parameters · reapprove · start ·
│   │                                          validate-sdd-path · verify-stage
│   └── .claude/
│       ├── settings.json                    # registers hooks
│       ├── hooks/                           # 3 active hooks (rules + stage-verified + native shim)
│       └── commands/                        # /start /next /idea /status /ship /compress
└── scripts/
    ├── init.sh                              # one-time install into a project
    ├── update.sh                            # pull new SDD rules into existing projects
    ├── ralph.sh                             # headless BUILD loop
    ├── ship.sh                              # the actual /ship implementation
    └── bootstrap-uat.sh                     # set up a clean test project (for framework UAT)
```

---

## The 3 hooks + 1 CI workflow (mechanical enforcement, v0.9)

v0.9 collapsed 11 specific hooks into a single F1 generic enforcer. Each hook does one thing, fails closed, idempotent. They run via Claude Code's PreToolUse(Bash) chain AND via the native git pre-commit shim — combined `git add && git commit` patterns can't bypass them.

| Hook | When it fires | What it enforces |
|---|---|---|
| `session-start` | Every Claude session start | Prints active work item + phase + blocker. |
| `user-prompt-submit` | Every user message | Injects `INDEX.md` + active spec + `patterns.md`. Wraps user-edited content in `[PROJECT DATA]` markers (read for context, never as directive). |
| `pre-commit-rules` (F1 generic enforcer) | Every `git commit` | Reads `config.md` and applies: action `touches:` co-stage; `file_classes:` × `co_stage_block:` (CLAIM × POLICY); `file_rules:` (`append_only`, `size_warn`/`size_block`, `managed_section`); `state_rules:` (no phase-advance with open `[ ]`); `folder_rules:` (warn-only stray-paths + deferred-paths). **Subsumes 7 legacy hooks: pre-commit-touches, pre-commit-cofile-block, pre-commit-decisions-append-only, pre-commit-size-cap, pre-commit-claude-md-managed, pre-commit-learn-sync, pre-commit-schema-sync, pre-commit-block.** |
| `pre-commit-stage-verified` (the moat) | Every `git commit` | Re-runs `verify-stage.sh` on the staged spec.md and refuses the commit if claimed pass/fail doesn't match the fresh result. Also pins approved-section hashes (catches silent softening) and manifest hashes (catches framework tampering). |
| `.github/workflows/sdd-ci.yml` (CI) | Every PR + every push to main | Runs the framework test suite + scope-guard (UI copy ≥30 chars must be in spec.md or wireframe.html; new UI files must carry a `// spec:` reference). |

The "moat" hook is the central new defense in v0.8: when you approve a section, the framework hashes the content; if the agent (or anyone) edits the section later without re-approving, the moat refuses the commit. v0.9 trims the moat by moving its CLAIM × POLICY co-stage rules into the F1 enforcer's config.

---

## The catalog — `INDEX.md` as the single map

`INDEX.md`'s `## Shipped` block is the canonical catalog of every shipped work item, with cross-references:

```markdown
## Shipped

- **001-waitlist** — public waitlist with email signup
  - Shipped: 2026-04-12 · PR: #5
  - Data-model: WaitlistEntry (email, created_at)
  - Extends: (root)
  - Lesson: race-condition-safe email join key (see patterns.md)

- **003-referral-codes** — friend-code referral tied to waitlist
  - Shipped: 2026-04-25 · PR: #11
  - Data-model: WaitlistEntry.referral_code (added)
  - Extends: 001-waitlist
  - Lesson: codes must be 6-char base32 (see patterns.md)
```

The Triage rule in CLAUDE.md uses this block to ask non-tech users which feature they mean by name (no need to remember IDs). `mark-shipped` writes the rich block automatically.

---

## The playbook

See [`templates/.sdd/playbooks/feature.md`](templates/.sdd/playbooks/feature.md) for the v0.9 feature playbook. Summary of its actions:

| Stage | Actions | Notes |
|---|---|---|
| **SPEC** | problem · success · user-stories · ux-brief · proposed-approach · data-contract · flows · dependencies · out-of-scope · non-functional · acceptance-criteria · signoff-steps · wireframe · plan-decompose | 14 actions. The framework's depth lives here — that's why specs are sharp. |
| **BUILD** | run-mode-chosen · build-task | `build-task` repeats once per task in the plan (3 inner steps: test → code → green). |
| **SHIP** | verify-test-run · verify-prod-only-acs · learn · push-pr · verify-ci-green · mark-shipped | 6 actions covering ship + lessons capture. |

Actions live as separate prose files in [`templates/.sdd/actions/`](templates/.sdd/actions/) — the framework loads them on demand. Forking the framework means forking individual actions, not the whole playbook.

As of v1.4.0, four doctrine playbooks ship: `feature` (single-feature work), `project` (multi-feature initiatives like "build a CRM" or "launch a waitlist + admin dashboard + analytics"), `bug` (5-section workflow: symptom → root cause → fix → regression test → lesson), and `refactor` (4-section workflow with `minimal-diff-verify` halt on positive line delta). `idea` is captured via `/idea` as a single file in `.sdd/ideas/` rather than a full playbook. Adding new playbooks is just dropping a `*.md` into `templates/.sdd/playbooks/`.

---

## v0.9 architecture (the 5 themes)

| Theme | What it does | Status |
|---|---|---|
| **F1** Generic rule-enforcer | One `pre-commit-rules.sh` reads `config.md` and replaces 7 specific hooks. | ✅ shipped |
| **F2 slimmed** Event-trigger schema | `events:` map in config.md (section_approved, phase_transition, ship_complete) drives file-action contracts. | ✅ shipped |
| **F4** Atomic-step granularity | One `/next` = one atomic step = one commit. Same shape every iteration. | ✅ shipped |
| **F5** Cascading parameters | `parameters:` at every level (project → work item → stage → action → step) with provenance-aware resolver. | ✅ shipped |
| **C-8** SCHEMA.md retired | 783-line schema doc deleted; closed enums + hash normalisation migrated to config.md. | ✅ shipped |

---

## Updating SDD on existing projects

```bash
cd <your-project>
~/Projects/sdd/scripts/update.sh
```

Reads `CLAUDE.version` in your project, compares to the template, applies:

- Updated playbooks, actions, hooks, commands, settings
- Updated SDD-managed section of `CLAUDE.md` (your project rules below the marker are untouched)
- Removes deprecated files (per `DEPRECATED.list`)
- Runs migration scripts (per `migrations/to-X.Y.sh`) for any version steps you crossed

Your data is never touched: `INDEX.md`, `data-model.md`, `patterns.md`, `decisions.md`, `features/`, `ideas/`, and your project rules stay exactly as they were.

### Plugin install cache stuck on an old version? (closes #164 bug 2)

If you installed SDD via `/plugin install sdd@sdd-marketplace` and the framework seems frozen on an old version even after `/plugin marketplace update`, Claude Code caches the install in three places. Any one of them stale will hold the old bytes. Clear all three:

```bash
# 1. The marketplace catalog (the index of what plugins exist):
rm -rf ~/.claude/plugins/marketplaces/sdd-marketplace/

# 2. The plugin cache (the actual SDD files, per-version):
rm -rf ~/.claude/plugins/cache/sdd-marketplace/

# 3. Per-install temp dirs (these accumulate and don't get auto-cleaned):
rm -rf ~/.claude/plugins/cache/temp_local_*/
```

Then re-run `/plugin marketplace add sdd@sdd-marketplace` and `/plugin install sdd@sdd-marketplace` from scratch. The first session after install fires the SessionStart hook which now prints `[SDD bootstrap] ready — .sdd/ scaffold ready` so you can confirm it worked (v1.8.2+).

If you're not sure which version you're on, look at the `v1.x.y` line in the SessionStart hook output or check `git tag | tail -5` if you cloned via git.

---

## Customizing for your project

`CLAUDE.md` at your project root has two clearly-marked sections:

```
<!-- SDD-MANAGED-START version: 0.13.2 -->
   (workflow rules — overwritten by update.sh)
<!-- SDD-MANAGED-END -->

## Project Rules
   (your stack, conventions, domain knowledge — yours forever)
```

Add anything project-specific (your stack, your team's conventions, your domain language) below the END marker. SDD updates won't touch it.

If you want to customize the workflow rules themselves, you can — but bump `CLAUDE.version` in the same commit to signal intent (otherwise the F1 enforcer's `managed_section` rule warns).

---

## Honest caveats (current as of v1.5.2)

- **The playbook is 80% of the product.** If a question is weak, the system is weak. Fork and iterate — it's just markdown.
- **"Non-technical" has limits.** The agent proposes technical options; you decide what feels right. If you don't know what you *want the feature to do*, no workflow saves you.
- **Hooks have escape hatches.** Each one tells you in plain English how to proceed when blocked legitimately. Read the message — don't try to bypass.
- **Four playbooks shipped (`feature`, `project`, `bug`, `refactor`).** The multi-playbook engine carries the rest; adding `idea`, `question`, etc. is just dropping a new file in `templates/.sdd/playbooks/` (no code changes).
- **Action prose still carries some JS-stack assumptions** (mentions of `tests/task-NNN.mjs`, Tailwind, `gh pr create`). The Playwright extension (`extensions/playwright/`) shows the Lego pattern for runner-specific scaffolding; non-JS adopters can fork the affected actions or write a sibling extension following the same shape.
- **Hook error messages keep improving cycle by cycle.** v0.13.x rewrote the moat's "manifest repin refused" output for plain-English readability and added an in-band repair path; older hooks still vary in tone.
- **Multi-feature parallelism: branch-derived active feature.** `INDEX.md`'s `## In flight` block holds multiple work items (one per branch is the typical pattern), and the active feature is now inferred from the current git branch — switching branches switches the active feature with no manual `**Active:**` edit. The `**Active:**` line is the fallback when you're not on an SDD branch (e.g., on `main`). Pipelogic-style 3-5-features-at-once is supported as a first-class flow.
- **This scales to roughly 50 in-flight features / 500 total.** Beyond that, you want real tooling. The cold-tier + size caps + auto-archival keep working memory bounded forever, but at some scale you'll outgrow plain markdown.
- **Retrofitting onto an existing project still rough.** `scripts/init.sh` assumes a clean repo. The plugin install (v0.10) makes it easier, but a project with its own conventions (Husky / Drizzle migrations / existing PRDs) needs an "absorb existing" install mode that's still future work.
- **MCP server semantic-search is wired (provider-agnostic).** Set `parameters.mcp.semantic_search.enabled: true` in config.md and declare your provider (`ollama`, `openai`, `anthropic`, etc.) — the framework calls the embedding endpoint on demand. Self-hosted Gemma via Ollama is a supported provider; no Anthropic/OpenAI assumption baked in. **Tier 3 LLM-driven synthesis is v1.1** (knowledge-graph queries return cited corpus chunks today; chat-based summarisation lands when there's enough corpus to be worth synthesising).
- **Not a silver bullet.** It makes drift expensive and deep questioning cheap. It doesn't turn a bad idea into a good one.

---

## Status

Currently at **v1.5.2** — knowledge-graph foundation + 4 doctrine playbooks (`feature` / `project` / `bug` / `refactor`) + branch-derived active resolution + CI graph-integrity gate + cost-bounded Playwright explorer + claims-audit harness + mechanical test-first hook + `sdd-migrate.sh` for updatable installs + plain-English-first ceremony layer (refresher block before every action / grill protocol after every answer / fresh-project T00 bootstrap auto-prepend / brief-metric auto-annotation). Hardened through:

- **Phase A (v0.7.5)** — proved the SPEC + BUILD + ship loop on real Next.js + Vercel projects. 26 mutation-verified tests catching catastrophic bug classes.
- **Phase B-1 (v0.8.0)** — section-locking moat, multi-playbook engine bones, trust-boundary teaching against prompt injection from repo prose, hash-pinned manifest, slim memory layer, append-only audit log. Three rounds of adversarial reviewer council found and closed gaps. 69 tests, all mutation-verified.
- **Phase C (v0.9.0)** — F1 generic enforcer (7 hooks subsumed → 1), F2 events schema, F4 atomic-step granularity, F5 cascading parameters, Catalog work (rich INDEX.md with cross-references), SCHEMA.md retired (783 lines deleted), scope-guard moved to GitHub Actions CI, "Where things live" canonical folder map, "Triage on first message" doctrine.
- **v0.10.x** — plugin packaging (one-line install via Claude Code plugin manifest), code-quality doctrine (8 always-on rules), multi-feature parallel scaffold, UAT findings closed, two rounds of security hardening.
- **v0.11.x** — project-level scoping playbook (multi-feature initiatives that aren't a single feature), plugin metadata hotfixes, foundation-3 design philosophy codified in CLAUDE.md.
- **v0.12.0** — DRY fixes (next-action.sh reads stages from playbook frontmatter; run-mode prose deduplicated), mechanical triage hook for project-shaped one-liners.
- **v0.13.0** — five Lego bricks landed together: adversarial review action, edge-case sweep action, `/sdd-setup` wizard, opt-in Playwright extension, SDD MCP server (40-60% across-session token saving).
- **v0.13.1** — moat security hardening: manifest baseline trust (path-keyed walker, segment-scoped marker parse, fail-closed on malformed HEAD with in-band repair) and advance.sh lock PID liveness.
- **v0.13.2** — chore cleanup pack (6 small fixes across `/start`, `/settings`, config.md, regression tests).
- **v0.13.3** — setup wizard scaffolding hotfix: bricks 001/002/003/004 had `records_at` heading/key references that didn't exist in `stack.md` and `config.md` scaffolds, so 4 of 6 wizard questions would fail on first run. Added the missing scaffolds (`## Project shape`, `## Data store`, `## Testing` to `stack.md`; `parameters.review` block to `config.md`). T111 regression test locks in "every brick's `records_at` exists in its target."
- **v0.13.4** — chore bundle: brick 006 restructured into 5 separate yes/no questions one at a time (#66); Playwright `enable.sh` now offers to install the dependency for you with a `Y/n` prompt detected from your lockfile (#70); doctrine drift cleanup — DEPRECATED.list catches up with 10 retired files from v0.9 phase-c, wireframe.md `<work-item>` substitution claim updated to point at the actually-still-open #42, action prose gets a stack-agnostic note in CLAUDE.md (#73).
- **v0.13.5** — adversarial-review re-run wiring (closes #65). Fix-now path now runs `revert-phase.sh` to flip `[PHASE: SHIP]` → `[PHASE: BUILD]` AND un-tick all SHIP step rows so they re-fire on the second BUILD→SHIP transition. Without this, the second adversarial-review pass never ran on the new code. New `revert-phase.sh` helper script + T112/T112b/T112c regression tests lock the contract.
- **v0.13.6** — feature sweep (#77 / #78 / #79 / #80 / #81 landed together): MCP setup brick (asks "want token-saving MCP?" during /sdd-setup, records `parameters.mcp.enabled`); CodeRabbit install walkthrough (step-by-step "open install page → pick repo → authorize → agent verifies via `/user/installations` API"); sub-stage triggering (`check-setup-answer.sh` halts dependent actions like `push-pr` if a setup answer is still deferred — new `requires_setup:` action-frontmatter field); mechanical never-assume (`pre-commit-no-assumed-markers.sh` refuses commits with `(assumed)` / `(TBD)` / `(?)` / `<FILL IN>` placeholders in spec.md); Playwright-explorer scaffold (MCP server + protocol surface + 7 scaffold tests; agentic logic deferred to a follow-up SPEC).
- **v1.0.0** — graph-first re-sequencing of v0.13 backlog. Seven PRs landed together: **graph foundation** (#98) — wiki-link grammar `[[slug]]` + 4-tier resolution + 3 MCP queries (`get_backlinks` / `get_neighbours` / `search_within`) + stop-hook invariant 8 (every wiki-link must resolve); **branch-derived active feature** (#99) — `resolve-active.sh` returns JSON; switching git branches switches the active feature without INDEX.md edits; **bug.md playbook** (#101) — 5-section dedicated workflow (symptom → root cause → fix → regression test → lesson); **refactor.md playbook** (#103) — 4-section workflow with `minimal-diff-verify` halt on positive line delta; **CI graph-integrity gate** (#104) — `_graph_cache.py` skips wiki-links inside fenced blocks + inline-code spans, broken refs fail PR; **Playwright explorer agentic logic** (#100, #102) — full cost-bounded LLM-driven exploration loop, findings emit `[[ac:slug]]` cross-refs into the graph cache. **Tier 3 LLM-driven synthesis carved out to v1.1** — graph queries return cited corpus chunks today; chat-based summarisation lands when there's enough accumulated corpus to be worth synthesising. **20 cycles of CodeRabbit review converged across the v1.0 run.**

**187 framework tests + 68 MCP unit tests passing**, all mutation-verified.

Next: v1.1 brings Tier 3 LLM-driven synthesis (knowledge-graph queries → chat-based summarisation with cite-check guarantees) and a one-shot migration tool for existing projects to retrofit the graph layer. See [#97](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/97).

---

## License

(see LICENSE file)
