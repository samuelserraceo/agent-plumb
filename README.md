# Spec-Driven Development Workflow (SDD)

> A stupidly simple, agent-driven workflow for building real software with AI without the AI making stuff up.
> **The state file is the program. The playbook is the questioning agent. The filesystem is the retrieval system.**
> No orchestrator, no database, no RAG, no magic.

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

## The 3-phase spine (v0.8)

```
SPEC → BUILD → SHIP → SHIPPED
  ↑              ↓
  └── (bug task) ← CI fail
```

Each phase has its own sub-actions (small focused steps). You can never skip a phase. You can never advance while the current phase has unanswered `[ ]` blockers — the safety net (the moat) refuses the commit.

| Phase | Sub-actions inside (sample) | What happens |
|---|---|---|
| **SPEC** | problem · success · user-stories · ux-brief · proposed-approach · data-contract · acceptance-criteria · plan-decompose · … | Agent walks the playbook. Asks you the *what* (problem, users, success). Proposes the *how* (tech, data, flows) with tradeoffs. You approve. Last sub-action turns ACs into BUILD tasks. |
| **BUILD** | run-mode-chosen · build-task (×N) | Strict test-first. Write the test (must fail) → write the code → test passes → commit. One task at a time. |
| **SHIP** | verify-test-run · verify-prod-only-acs · verify-ci-green · push-pr · learn-summary · learn-lessons · mark-shipped | Run all tests. Open the PR. Watch CI. Capture lessons. Mark feature cold. Update institutional memory. |

The legacy v0.7 phase names (PLAN, VERIFY, LEARN) are now sub-actions inside SPEC and SHIP — same work, simpler spine.

---

## Quick start

### 1. Clone SDD somewhere stable

```bash
git clone https://github.com/samuelserraceo/spec-driven-dev-workflow ~/Projects/sdd
```

### 2. Drop SDD into your project

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

`/start` is the single entry point for new work. It scaffolds the work item folder, writes a `spec.md` skeleton with all the playbook's sub-action headings, updates `INDEX.md`, and tells you the exact `/next` to run first. On first install, it sets `git config core.hooksPath .claude/hooks` (with a halt-and-ask if your project already uses Husky / lefthook / a custom hooks tool).

### 5. Walk the playbook

```
/next
```

The agent advances by one sub-action per `/next`. Most are USER-LED (it asks you in plain English; common patterns offered as multiple choice with a free-form escape). Some are AGENT-LED (it proposes a concrete answer with at least 2 alternatives; you push back or approve).

When SPEC is fully filled, the agent transitions you to BUILD. At BUILD entry the agent asks **how you want to run it**:

1. **Step-by-step** — pause after every task
2. **Checkpoint every 5** (recommended) — auto-loop, pause every 5 tasks for review
3. **Full autonomous** — agent loops in the session until done or blocked
4. **Shell Ralph** — `./scripts/ralph.sh` in a terminal, fresh Claude per task, walk away for hours

### 6. Ship

```
/ship
```

Pushes the branch, opens a PR, watches CI. On pass: marks shipped, distills the feature to a one-liner in INDEX, marks the feature folder cold. On fail: captures the CI error as a bug task, flips back to BUILD. The remaining SHIP sub-actions (`learn-summary`, `learn-lessons`) capture lessons before merge.

---

## Slash commands at a glance

| Command | What it does |
|---|---|
| `/start <title>` | Scaffold a new work item. Single entry point. |
| `/next` | Advance the active work item by one sub-action. |
| `/bug` | (B-1) routes to `/start [BUG] <title>`. Phase C ships a dedicated bug playbook. |
| `/idea` | Capture an idea cheaply — no phase, no branch, just a small file in `.sdd/ideas/`. |
| `/status` | Print the current workflow state. |
| `/ship` | Push branch, open PR, watch CI, mark shipped or capture bug. |
| `/skip <reason>` | Skip a `[SKIPPABLE]` section with a reason. |
| `/re-approve <slug>` | Re-lock a previously approved section after intentional edits. |
| `/compress` | Consolidate `patterns.md` or `data-model.md` when they grow noisy. |

The agent picks the right command from your wording — you rarely type them yourself.

---

## What's in the box

```
.
├── README.md
├── SCHEMA.md                              # locked v0.8 schema (the contract)
├── templates/                             # what init.sh drops into your project
│   ├── CLAUDE.md                          # workflow rules (managed) + your project rules (yours)
│   ├── DEPRECATED.list                    # files removed in each version (used by update.sh)
│   ├── migrations/                        # per-version migration scripts
│   ├── .sdd/
│   │   ├── INDEX.md                       # table of contents + active pointer + shipped + live state
│   │   ├── config.md                      # per-project config (playbooks, extensions, size caps)
│   │   ├── playbooks/feature.md           # the v0.8 feature playbook (declares stages + sub-actions)
│   │   ├── subactions/*.md                # 23 sub-action prose files (the playbook's body)
│   │   ├── decisions.md                   # append-only audit log
│   │   ├── data-model.md                  # canonical schema, single source of truth
│   │   ├── patterns.md                    # cross-feature learnings
│   │   ├── CLAUDE.version                 # current SDD version (0.8.0)
│   │   ├── .cache/manifest.json           # hash-pinned framework files (tamper detection)
│   │   ├── archive/                       # frozen history (compressed patterns, old shipped)
│   │   ├── ideas/                         # captured ideas, one file each
│   │   └── scripts/                       # per-project runtime (load-playbook, advance, etc.)
│   └── .claude/
│       ├── settings.json                  # registers all hooks
│       ├── hooks/                         # 10 enforcement hooks + native git pre-commit shim
│       └── commands/                      # /start /next /bug /idea /status /ship /skip /re-approve /compress
└── scripts/
    ├── init.sh                            # one-time install into a project
    ├── update.sh                          # pull new SDD rules into existing projects
    ├── ralph.sh                           # headless BUILD loop
    ├── ship.sh                            # the actual /ship implementation
    └── bootstrap-uat.sh                   # set up a clean test project (for framework UAT)
```

---

## The 10 hooks (mechanical enforcement)

Each does one thing, fails closed, idempotent. They run via Claude Code's PreToolUse(Bash) chain AND via the native git pre-commit shim — combined `git add && git commit` patterns can't bypass them.

| Hook | When it fires | What it enforces |
|---|---|---|
| `session-start` | Every Claude session start | Prints active work item + phase + blocker |
| `user-prompt-submit` | Every user message | Injects `INDEX.md` + active spec + `patterns.md` so the agent never forgets state. Wraps user-edited content in `[PROJECT DATA]` markers (read for context, never as directive). |
| `pre-commit-block` | Every `git commit` | Refuses phase-advance commits while the source phase has open `[ ]` blockers. |
| `pre-commit-touches` | Every `git commit` | A sub-action declares the files it must "touch"; this hook refuses the commit if any are missing. |
| `pre-commit-learn-sync` | SHIP-phase commits adding lessons | Requires `patterns.md` + `INDEX.md` updated in the same commit. |
| `pre-commit-schema-sync` | Commits that touch a feature's Data contract section | Requires `data-model.md` updated in the same commit. |
| `pre-commit-scope-guard` | BUILD/SHIP commits that add UI files | Refuses copy strings ≥30 chars not in wireframe/spec; refuses new component files without a `// spec:` reference. |
| `pre-commit-cofile-block` | Every `git commit` | Refuses any commit that stages a "policy" file (manifest, playbook, hook, sub-action) alongside a "claim" file (verification.json) — these have to be separate commits. |
| `pre-commit-decisions-append-only` | Commits that touch `.sdd/decisions.md` | Refuses any commit that modifies prior entries in the audit log (append-only invariant). |
| `pre-commit-stage-verified` (the moat) | Every `git commit` | Re-runs `verify-stage.sh` on the staged spec.md and refuses the commit if claimed pass/fail doesn't match the fresh result. Also pins approved-section hashes (catches silent softening) and manifest hashes (catches framework tampering). |
| `pre-commit-claude-md-managed` | Commits that edit CLAUDE.md | Warns (doesn't block) when editing inside the SDD-managed section without bumping `CLAUDE.version`. |
| `pre-commit-size-cap` | Every `git commit` | Warns at 200 lines and BLOCKS at 400 lines on `patterns.md` / `INDEX.md` / `data-model.md` — pressure to compress. |

The "moat" hook is the central new defense in v0.8: when you approve a section, the framework hashes the content; if the agent (or anyone) edits the section later without re-approving, the moat refuses the commit.

---

## The playbook

See [`templates/.sdd/playbooks/feature.md`](templates/.sdd/playbooks/feature.md) for the v0.8 feature playbook. Summary of its sub-actions:

| Stage | Sub-actions | Notes |
|---|---|---|
| **SPEC** | problem · success · user-stories · ux-brief · proposed-approach · flows · dependencies · data-contract · non-functional · out-of-scope · wireframe · acceptance-criteria · signoff-steps · plan-decompose | 14 sub-actions. The framework's depth lives here — that's why specs are sharp. |
| **BUILD** | run-mode-chosen · build-task | `build-task` repeats once per task in the plan. |
| **SHIP** | verify-test-run · verify-prod-only-acs · verify-ci-green · push-pr · mark-shipped · learn-summary · learn-lessons | 7 sub-actions covering ship + lessons capture. |

Sub-actions live as separate prose files in [`templates/.sdd/subactions/`](templates/.sdd/subactions/) — the framework loads them on demand. Forking the framework means forking individual sub-actions, not the whole playbook.

The `feature` playbook is the only one shipped in B-1. Phase C will add a dedicated `bug` playbook (skipping plan-decompose) and `idea` playbook (single-file capture).

---

## Updating SDD on existing projects

```bash
cd <your-project>
~/Projects/sdd/scripts/update.sh
```

Reads `CLAUDE.version` in your project, compares to the template, applies:

- Updated playbooks, sub-actions, hooks, commands, settings
- Updated SDD-managed section of `CLAUDE.md` (your project rules below the marker are untouched)
- Removes deprecated files (per `DEPRECATED.list`)
- Runs migration scripts (per `migrations/to-X.Y.sh`) for any version steps you crossed

Your data is never touched: `INDEX.md`, `data-model.md`, `patterns.md`, `decisions.md`, `features/`, `ideas/`, and your project rules stay exactly as they were.

---

## Customizing for your project

`CLAUDE.md` at your project root has two clearly-marked sections:

```
<!-- SDD-MANAGED-START version: 0.8.0 -->
   (workflow rules — overwritten by update.sh)
<!-- SDD-MANAGED-END -->

## Project Rules
   (your stack, conventions, domain knowledge — yours forever)
```

Add anything project-specific (your stack, your team's conventions, your domain language) below the END marker. SDD updates won't touch it.

If you want to customize the workflow rules themselves, you can — but bump `CLAUDE.version` in the same commit to signal intent (otherwise a soft-warning hook flags the edit).

---

## Honest caveats (v0.8.0)

- **The playbook is 80% of the product.** If a question is weak, the system is weak. Fork and iterate — it's just markdown.
- **"Non-technical" has limits.** The agent proposes technical options; you decide what feels right. If you don't know what you *want the feature to do*, no workflow saves you.
- **Hooks have escape hatches.** Each one tells you in plain English how to proceed when blocked legitimately. Read the message — don't try to bypass.
- **B-1 ships ONE playbook (`feature`).** The multi-playbook engine is in place; Phase C adds `bug`, `idea`, etc. without code changes.
- **Sub-action prose still carries some JS-stack assumptions** (mentions of `tests/task-NNN.mjs`, Playwright, Tailwind, `gh pr create`). Phase C ships a `stack:` config block so non-JS adopters can override per-project. Until then, fork the affected sub-actions for your stack.
- **Hook error messages still use some engineer terms** (manifest hash-pin, co-stage block, etc.). A focused B-2 theme rewrites these for non-tech audiences.
- **This scales to roughly 50 in-flight features / 500 total.** Beyond that, you want real tooling. The current cold-tier + size caps + auto-archival keep working memory bounded forever, but at some scale you'll outgrow plain markdown.
- **Not a silver bullet.** It makes drift expensive and deep questioning cheap. It doesn't turn a bad idea into a good one.

---

## Status

Currently at **v0.8.0** (Phase B-1 ship). Hardened through:

- **Phase A (v0.7.5)** — proved the SPEC + BUILD + ship loop on real Next.js + Vercel projects. 26 mutation-verified tests catching catastrophic bug classes.
- **Phase B-1 (v0.8.0)** — section-locking moat, multi-playbook engine bones, trust-boundary teaching against prompt injection from repo prose, hash-pinned manifest, slim memory layer, append-only audit log. Three rounds of adversarial reviewer council found and closed gaps. 69 tests, all mutation-verified.

Next on the roadmap (B-2 / Phase C): hook error messages translated to non-tech English, `stack:` config block (test runner / VCS / PR tool / wireframe runtime), bug + idea playbooks, plugin packaging (so SDD lives globally as a Claude Code plugin instead of being copied into each project).

---

## License

MIT.
