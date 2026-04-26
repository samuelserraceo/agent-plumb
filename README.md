# Spec-Driven Development Workflow (SDD)

> A stupidly simple, agent-driven workflow for building real software with AI without the AI making stuff up.
> **The state file is the program. The rubric is the questioning agent. The filesystem is the retrieval system.**
> No orchestrator, no database, no RAG, no magic.

---

## What this solves

If you've used Claude Code, Cursor, Lovable, or any other AI coding tool, you've probably had this happen:

- You asked for X, the AI built X **plus a fake "47 founders on the wait list" counter you never wanted**.
- The AI shipped something that technically works but **misunderstood your intent**.
- Six months later you can't remember **why** the AI picked one tech over another.
- Documentation drifted. Schema drifted. Tests skipped.

SDD makes the wrong path **mechanically impossible**, not just discouraged. The agent literally cannot commit code that drifts from its spec, because git pre-commit hooks refuse the commit.

You bring the *what* (in plain English). The agent proposes the *how* (with tradeoffs you can react to). Every decision is captured in a markdown file you can read, share with an investor, hand to a future engineer, or rebuild in a different stack.

---

## The 5-phase loop

```
SPEC → PLAN → BUILD → VERIFY → LEARN → SHIPPED
  ↑                       ↓
  └── (bug task) ← CI fail
```

You can never skip a phase. You can never advance while the current phase has unanswered questions.

| Phase | What happens |
|---|---|
| **SPEC** | Agent walks a rubric. Asks you the *what* (problem, users, success). Proposes the *how* (tech, data, flows) with tradeoffs. You approve. |
| **PLAN** | Spec gets broken into atomic tasks, each with a test file. |
| **BUILD** | Strict test-first. Write the test (must fail) → write the code → test passes → commit. |
| **VERIFY** | Run all tests. Generate a human sign-off checklist from your spec. |
| **LEARN** | Capture lessons → `patterns.md`. Update `INDEX.md` with what shipped. Mark feature cold. |

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

This adds a `.sdd/` folder, a `.claude/` folder, a project-root `CLAUDE.md`, and three runtime scripts (`scripts/ralph.sh`, `scripts/ship.sh`, `scripts/install-agent-browser.sh`). It also installs `agent-browser` globally for browser-based UAT.

### 3. Open Claude Code in your project

```bash
claude
```

A banner shows the current state. On a fresh project: *"No active feature."*

### 4. Start your first feature

Just talk:

> Let's work on a waitlist signup

The agent picks the right entry point automatically:

| You say | Entry point | What happens |
|---|---|---|
| "Build me X" / "Add a feature for Y" | `/next` | Creates branch `sdd/001-x`, starts SPEC rubric |
| "Something is broken: …" | `/bug` | Creates branch `sdd/001-bug-x`, smaller rubric |
| "Just an idea: …" | `/idea` | Captures to `.sdd/ideas/`, no commitment |

### 5. Walk the rubric

The agent asks you one section at a time. Most questions are USER-LED (it asks you in plain English; common patterns are offered as multiple choice with a free-form escape). Some are AGENT-LED (it proposes a concrete answer with at least 2 alternatives; you push back or approve).

When SPEC is fully filled, PLAN runs, then BUILD. At BUILD entry the agent asks **how you want to run it**:

1. **Step-by-step** — pause after every task
2. **Checkpoint every 5** (recommended) — auto-loop, pause every 5 tasks for review
3. **Full autonomous** — agent loops in the session until done or blocked
4. **Shell Ralph** — `./scripts/ralph.sh` in a terminal, fresh Claude per task, walk away for hours

### 6. Ship

```
/ship
```

Pushes the branch, opens a PR, watches CI. On pass: marks shipped, distills the feature to a one-liner in INDEX, marks the feature folder cold, flips phase to LEARN. On fail: captures the CI error as a bug task, flips back to BUILD.

---

## Slash commands at a glance

| Command | What it does |
|---|---|
| `/next` | Advance the active feature by one step (SPEC question, PLAN task, BUILD test, etc.) |
| `/bug` | Start a focused bug fix — smaller rubric, no PLAN phase |
| `/idea` | Capture an idea cheaply — no phase, no branch, just a small file in `.sdd/ideas/` |
| `/status` | Print the current workflow state |
| `/ship` | Push branch, open PR, watch CI, mark shipped or capture bug |
| `/skip` | Skip a `[SKIPPABLE]` rubric section with a reason |
| `/compress` | Consolidate `patterns.md` or `data-model.md` when they grow noisy |

The agent picks the right command from your wording — you rarely type them yourself.

---

## What's in the box

```
.
├── README.md
├── templates/                           # what init.sh drops into your project
│   ├── CLAUDE.md                        # workflow rules (managed) + your project rules (yours)
│   ├── DEPRECATED.list                  # files removed in each version (used by update.sh)
│   ├── migrations/                      # per-version migration scripts
│   └── .sdd/
│       ├── INDEX.md                     # table of contents + active pointer + shipped + live state
│       ├── rubric.md                    # full feature rubric (12 sections + phases)
│       ├── rubric-bug.md                # smaller bug rubric (6 sections)
│       ├── rubric-idea.md               # tiny idea-capture rubric
│       ├── data-model.md                # canonical schema, single source of truth
│       ├── patterns.md                  # cross-feature learnings
│       ├── CLAUDE.version               # current SDD version
│       ├── archive/                     # frozen history (compressed patterns, old shipped)
│       ├── ideas/                       # captured ideas, one file each
│       └── features/_template/          # scaffold for new feature folders
└── .claude/
    ├── settings.json                    # registers all hooks
    ├── hooks/                           # 7 deterministic enforcement hooks (see below)
    └── commands/                        # /next /bug /idea /status /ship /skip /compress
└── scripts/
    ├── init.sh                          # one-time install into a project
    ├── update.sh                        # pull new SDD rules into existing projects
    ├── ralph.sh                         # headless BUILD loop
    ├── ship.sh                          # the actual /ship implementation
    └── install-agent-browser.sh         # global agent-browser install
```

---

## The 7 hooks (mechanical enforcement)

Each does one thing, fails closed, idempotent.

| Hook | When it fires | What it enforces |
|---|---|---|
| `session-start` | Every Claude session start | Prints active feature + phase + blocker |
| `user-prompt-submit` | Every user message | Injects `INDEX.md` + active spec + `patterns.md` so the agent never forgets state |
| `pre-commit-block` | Every `git commit` | Refuses commits while current phase has unanswered `[ ]` (with a bootstrap exception for new features) |
| `pre-commit-learn-sync` | LEARN-phase commits | Requires `patterns.md` + `INDEX.md` updated in same commit |
| `pre-commit-schema-sync` | Commits that touch a feature's Data contract section | Requires `data-model.md` updated in same commit |
| `pre-commit-scope-guard` | Commits that add UI files | Refuses copy strings ≥30 chars not in wireframe/spec; refuses new component files without a `// spec:` reference |
| `pre-commit-claude-md-managed` | Commits that edit CLAUDE.md | Warns (doesn't block) when editing inside the SDD-managed section without bumping `CLAUDE.version` |
| `pre-commit-size-cap` | Every `git commit` | Warns when `patterns.md` / `INDEX.md` / `data-model.md` cross size thresholds |

---

## The rubric

See [`templates/.sdd/rubric.md`](templates/.sdd/rubric.md) for the full feature rubric. Summary:

| § | Section | Mode | Skippable? |
|---|---|---|---|
| 1 | Problem | USER-LED | no |
| 2 | Success | USER-LED (with multi-choice) | no |
| 3 | User stories | USER-LED (with multi-choice) | no |
| 4 | **UX & Design brief** | **AGENT-LED** | yes (non-UI features) |
| 5 | **Proposed approach** | **AGENT-LED** | no |
| 6 | **Data contract** | **AGENT-LED** | no |
| 7 | Flows | AGENT-LED | no |
| 8 | Dependencies | AGENT-LED | yes (no paid services) |
| 9 | Out of scope | USER-LED | no |
| 10 | Non-functional | AGENT-LED | yes (rare) |
| 11 | Acceptance criteria | AGENT-LED (with multi-choice) | no |
| 12 | Human sign-off | USER-LED | no |

Sections 4, 5, 6 are the depth that makes this different from "the agent asks some questions." Section 4 captures your taste with concrete reference proposals. Section 5 proposes the *how* with at least 2 alternatives + tradeoffs in plain English. Section 6 forces the schema to be modelled before any code is written.

The bug rubric ([`rubric-bug.md`](templates/.sdd/rubric-bug.md)) is shorter: 7 sections focused on reproduction + root cause + regression test. The idea rubric ([`rubric-idea.md`](templates/.sdd/rubric-idea.md)) is 4 questions, ~60 second capture.

---

## Updating SDD on existing projects

```bash
cd <your-project>
~/Projects/sdd/scripts/update.sh
```

Reads `CLAUDE.version` in your project, compares to the template, applies:

- Updated rubrics, hooks, commands, settings
- Updated SDD-managed section of `CLAUDE.md` (your project rules below the marker are untouched)
- Removes deprecated files (per `DEPRECATED.list`)
- Runs migration scripts (per `migrations/to-X.Y.sh`) for any version steps you crossed

Your data is never touched: `INDEX.md`, `data-model.md`, `patterns.md`, `features/`, `ideas/`, and your project rules stay exactly as they were.

---

## Customizing for your project

`CLAUDE.md` at your project root has two clearly-marked sections:

```
<!-- SDD-MANAGED-START version: 0.7.1 -->
   (workflow rules — overwritten by update.sh)
<!-- SDD-MANAGED-END -->

## Project Rules
   (your stack, conventions, domain knowledge — yours forever)
```

Add anything project-specific (your stack, your team's conventions, your domain language) below the END marker. SDD updates won't touch it.

If you want to customize the workflow rules themselves, you can — but bump `CLAUDE.version` in the same commit to signal intent (otherwise a soft-warning hook flags the edit).

---

## Honest caveats

- **The rubric is 80% of the product.** If a question is weak, the system is weak. Fork and iterate — it's just markdown.
- **"Non-technical" has limits.** The agent proposes technical options; you decide what feels right. If you don't know what you *want the feature to do*, no workflow saves you.
- **Hooks have escape hatches.** Each one tells you in plain English how to proceed when blocked legitimately. Read the message — don't try to bypass.
- **This scales to roughly 50 in-flight features / 500 total.** Beyond that, you want real tooling. The current cold-tier + size caps + auto-archival keep working memory bounded forever, but at some scale you'll outgrow plain markdown.
- **Not a silver bullet.** It makes drift expensive and deep questioning cheap. It doesn't turn a bad idea into a good one.

---

## Status

Built end-to-end and stress-tested on a real Next.js + Vercel project (a waitlist signup app — 14 BUILD tasks, 48 tests across desktop + mobile-safari, all passing).

Currently at **v0.7.1**. The system has been hardened through three rounds of real use:

- **Round 1** — proved the SPEC + BUILD + VERIFY loop on feature 001
- **Round 2** — added determinism hooks, auto-archival, single-file CLAUDE.md, runtime script install
- **Round 3** — typed entry points (`/bug`, `/idea`), bootstrap-commit exception, multi-choice scaffolding

Next on the roadmap: design session on file/memory/retrieval at scale, modular rubric section library, plugin packaging (so SDD lives globally as a Claude Code plugin instead of being copied into each project).

---

## License

MIT.
