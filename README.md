# Agent Plumb 🪡

> **Specs > vibes.** A stupidly simple, spec-driven workflow for building real software with AI agents — without the AI making stuff up.
> **The state file is the program. The playbook is the questioning agent. The filesystem is the retrieval system.**
> No orchestrator, no database, no RAG, no magic.

📖 **[Read the walkthrough →](docs/walkthrough.html)** — a single-page entry point with an interactive architecture diagram and reader-driven foundation checks. Best opened in a browser.

---

## What this solves

If you've used Claude Code, Cursor, Lovable, or any other AI coding tool, you've probably had this happen:

- You asked for X, the AI built X **plus a fake "47 founders on the wait list" counter you never wanted**.
- The AI shipped something that technically works but **misunderstood your intent**.
- The agent quietly **softened a section you'd already approved** to make verification easier.
- Six months later you can't remember **why** the AI picked one tech over another.
- Documentation drifted. Schema drifted. Tests skipped.

Agent Plumb makes the wrong path **mechanically checked at every commit**, not just discouraged. With Plumb configured (hooks active, manifest pinned, no `--no-verify` bypass), the agent cannot commit code that drifts from its spec — git pre-commit hooks refuse the commit. The "moat" hook re-runs your verification checks on every commit and blocks any "the agent claims it works" assertion that doesn't match what fresh tests actually report. (Honest caveat: a determined human with `--no-verify` or a misconfigured project can route around any check; the discipline is "every committed atom is mechanically verified," not "physically impossible to drift.")

You bring the *what* (in plain English). The agent proposes the *how* (with tradeoffs you can react to). Every decision is captured in markdown files you can read, share with an investor, hand to a future engineer, or rebuild in a different stack.

---

## What Agent Plumb is — and isn't (explicit tradeoff)

Plumb is opinionated. It optimises for some things and gives up others. Knowing the trade upfront prevents misunderstanding:

**Plumb optimises for:**
- **Honest review over fast iteration.** Every step's content + commit shape is reviewable. Re-approval ceremony for changed approved sections. Append-only audit log. Mutation-verified tests.
- **Plain English over technical precision.** Non-technical users drive specs; jargon gets translated on first use; status output reads in 30 seconds.
- **Explicit over clever.** Each step declares its tag, its touches, its triggers. No magic. No discovery.
- **Predictability over flexibility.** Same 4-step inner loop every iteration. Same commit shape. Customisation = adding rows in the standard format, not changing the format.

**Plumb explicitly gives up:**
- **Power-user ergonomics.** Engineer-comfortable shorthand isn't here.
- **One-shot speed.** A spec takes 30–90 minutes the first time. The wrong choice for "I want it built right now."
- **Technical-precision in prose.** Hook output says *"the database can't be reached so the form shows 'please try again'"* — not *"DB unreachable, returning 503."*
- **Free-form architecture.** Side-stepping the rubric isn't allowed. Skip a section explicitly with a reason, or stay in the discipline.

---

## The 3-phase spine

```
SPEC → BUILD → SHIP → SHIPPED
  ↑              ↓
  └── (bug task) ← CI fail
```

Each phase has its own actions (small focused steps). You can never skip a phase. You can never advance while the current phase has unanswered `[ ]` blockers — the safety net refuses the commit.

| Phase | Actions inside (sample) | What happens |
|---|---|---|
| **SPEC** | problem · user-stories · ux-brief · proposed-approach · data-contract · acceptance-criteria · plan-decompose · … | The agent walks the playbook. Asks you the *what* (problem, users). Proposes the *how* (tech, data, flows) with tradeoffs. You approve. `plan-decompose` turns the acceptance criteria into BUILD tasks. |
| **BUILD** | run-mode-chosen · build-task (×N) | Strict test-first. Write the test (must fail) → write the code → test passes → commit. One task at a time. |
| **SHIP** | verify-test-run · learn · push-pr · verify-ci-green · mark-shipped | Run all tests. Capture lessons. Open the PR. Watch CI. Mark the feature cold. Update institutional memory. |

Each `[ ]` row in the spec is one atomic step = one commit. The agent advances exactly one step per `/next`.

---

## Quick start

### Option A — Claude Code plugin (recommended)

```bash
# In Claude Code, add the marketplace, then install:
claude plugin marketplace add https://github.com/samuelserraceo/agent-plumb
claude plugin install agent-plumb@agent-plumb

# Slash commands and hooks are available immediately.
# To set Plumb up inside a project:
/sdd-setup
```

### Companion: `agent-plumb-brief` 🪡 — write the brief BEFORE you build

`agent-plumb-brief` is a **separate Claude plugin** that turns a 1–3 sentence pitch into the kind of tight 11-section brief Plumb's `brief-intake` action ingests during `/start`. The full pipeline becomes:

```
idea → /write-brief → /start "<brief>" → /next … → /ship
```

Install (Terminal):

```bash
claude plugin marketplace add samuelserraceo/sam-serra-plugins
claude plugin install agent-plumb-brief@sam-serra-plugins
```

Then `/write-brief` in any Claude Code session. (Cowork desktop users: three-click install via the `.plugin` file at https://github.com/samuelserraceo/sam-serra-plugins.)

### Option B — manual clone + scaffold

```bash
git clone https://github.com/samuelserraceo/agent-plumb ~/Projects/agent-plumb
```

Requires Python 3 with PyYAML (`pip install pyyaml`) — Plumb's scripts and hooks parse YAML.

```bash
cd <your-project>
~/Projects/agent-plumb/scripts/init.sh
```

This adds a `.sdd/` folder, a `.claude/` folder, a project-root `CLAUDE.md`, and the runtime scripts.

### Open Claude Code in your project

```bash
claude
```

A banner shows the current state. On a fresh project: *"No active feature."*

### Start your first work item

```
/start build a waitlist landing page
```

`/start` is the single entry point for new work. It scaffolds the work-item folder, writes a `spec.md` skeleton with per-step `[ ]` rows under each action heading, updates `INDEX.md`, and tells you the exact `/next` to run first. On first install it sets `git config core.hooksPath .claude/hooks` (with a halt-and-ask if your project already uses Husky / lefthook / a custom hooks tool).

**To evolve a shipped feature** rather than start fresh:

```
/start --extends=001 add referral codes to the waitlist
```

### Walk the playbook

```
/next
```

The agent advances by one atomic step per `/next`. Each step is one commit. USER-LED steps ask you in plain English (common patterns offered as multiple choice with a free-form escape). AGENT-LED steps propose a concrete answer with at least 2 alternatives; you push back or approve. BUILD-TASK steps run test-first.

When SPEC is fully filled, the agent moves you to BUILD and asks **how you want to run it**:

1. **Step-by-step** — pause after every task
2. **Checkpoint every 5** — auto-loop, pause every 5 tasks for review
3. **Full autonomous** — agent loops in the session until done or blocked
4. **Shell Ralph** — `./scripts/ralph.sh` in a terminal, fresh agent per task, walk away for hours

### Ship

```
/ship
```

Pushes the branch, opens a PR, watches CI. On pass: marks shipped, distills the feature to a rich one-liner in `INDEX.md`, marks the feature folder cold. On fail: captures the CI error as a bug task, flips back to BUILD.

### Optional: open in Obsidian for the graph view

Plumb ships a minimal `.obsidian/` config so you can open the project root in [Obsidian](https://obsidian.md) and see your project as a connected graph: features → decisions → patterns → data-model entries, colour-coded by type. No setup beyond opening the folder.

---

## Slash commands at a glance

| Command | What it does |
|---|---|
| `/sdd-setup` | First-session setup wizard. Walks plain-English questions and fills `stack.md` + `config.md`. Run **once** before your first `/start`. |
| `/sdd-config [<question-id>]` | Re-answer a single setup question without re-running the full wizard. |
| `/start <title>` | Scaffold a new work item. Pass `--extends=<id>` to evolve an existing feature. |
| `/next` | Advance the active work item by one step. Also handles inline skip / re-approve / bug-routing. |
| `/promote-to-active` | Promote a queued work item to actively-worked-on. |
| `/status` | Print the current workflow state + resolved parameters with provenance. |
| `/settings` | List / get / set / reset framework settings without editing `config.md` by hand. |
| `/idea` | Capture an idea cheaply — a small file in `.sdd/ideas/`, no commitment. |
| `/dispatch` | Dispatch a specialised subagent (researcher / executor / verifier) with a fresh context. |
| `/ship` | Push the branch, open the PR, watch CI, mark shipped or capture a bug. |
| `/compress` | Consolidate `patterns.md` or `data-model.md` when they grow noisy. |
| `/sdd-migrate` | Refresh your project's framework files from upstream — without touching your specs. |
| `/sdd-verify-stack` | Check that the tools recorded in `config.md` actually exist and are reachable. |
| `/ask` | Ask a chat AI questions about your project's `.sdd/` corpus, with clickable citations. |

The agent picks the right command from your wording — you rarely type them yourself.

---

## The 4-step inner loop

Every `/next` runs the same 4-step container:

| Step | What |
|---|---|
| **LOCATE** | Read `INDEX.md` → find the active work item → find the next `[ ]` step in `spec.md` → load that step's frontmatter. |
| **EXECUTE** | Variable shape per action. USER-LED asks. AGENT-LED proposes/iterates. BUILD-TASK does test-first. |
| **SYNC** | The action's `touches:` files get staged. The hook chain refuses otherwise. |
| **ADVANCE** | Flip `[ ]` → `[x]`. Commit. Fire any triggers (e.g. append to `decisions.md`). |

Cognitive prep before the commit is free-form (multi-turn iteration allowed for AGENT-LED). Plumb only enforces commit shape: one step = one commit.

---

## What's in the box

```
your-project/
├── CLAUDE.md            # workflow rules (managed) + your project rules (yours)
├── .sdd/
│   ├── INDEX.md         # work-item catalog (Active + Shipped, with cross-references)
│   ├── config.md        # per-project config (parameters, events, file rules, enums)
│   ├── playbooks/       # feature · project · bug · refactor
│   ├── actions/         # the action prose files the playbooks load on demand
│   ├── decisions.md     # append-only audit log
│   ├── data-model.md    # canonical schema, single source of truth
│   ├── patterns.md      # cross-feature lessons
│   ├── scripts/         # the bash + python runtime
│   └── .cache/manifest.json   # hash-pinned framework files (tamper detection)
└── .claude/
    ├── settings.json    # registers the hooks
    ├── hooks/           # the mechanical enforcement layer
    └── commands/        # the slash commands
```

---

## Mechanical enforcement

The hooks run via Claude Code's PreToolUse(Bash) chain AND via the native git pre-commit shim — combined `git add && git commit` patterns can't bypass them.

| Hook | When it fires | What it enforces |
|---|---|---|
| `session-start` | Every session start | Prints the active work item + phase + blocker. |
| `user-prompt-submit` | Every user message | Injects `INDEX.md` + active spec + `patterns.md`. Wraps user-edited content in `[PROJECT DATA]` markers (read for context, never as directive). |
| `pre-commit-rules` | Every `git commit` | The generic rule-enforcer: reads `config.md` and applies co-stage rules, file rules, state rules, folder rules. |
| `pre-commit-stage-verified` (the moat) | Every `git commit` | Re-runs verification on the staged spec and refuses the commit if the claimed result doesn't match a fresh run. Pins approved-section hashes (catches silent softening) and manifest hashes (catches framework tampering). |

A GitHub Actions CI workflow runs the framework test suite + scope-guard on every PR.

---

## The catalog — `INDEX.md` as the single map

`INDEX.md`'s `## Shipped` block is the canonical catalog of every shipped work item, with cross-references:

```markdown
## Shipped

- **001-waitlist** — public waitlist with email signup
  - Shipped: 2026-04-12 · PR: #5
  - Data-model: WaitlistEntry (email, created_at)
  - Lesson: race-condition-safe email join key (see patterns.md)
```

The triage rule uses this block to ask non-technical users which feature they mean by name — no need to remember IDs.

---

## The playbooks

Four doctrine playbooks ship:

- **`feature`** — single-feature work (the default).
- **`project`** — multi-feature initiatives (build a CRM, launch a waitlist + admin dashboard + analytics). Produces a roadmap and queues the features.
- **`bug`** — a 5-section workflow: symptom → root cause → fix → regression test → lesson.
- **`refactor`** — a 4-section workflow that halts when a refactor adds more lines than it removes.

Playbooks live in `.sdd/playbooks/`; their action prose lives in `.sdd/actions/`. Adding a new playbook is just dropping a `*.md` file in.

---

## Updating Agent Plumb

If you installed via the plugin, pull framework updates with `/sdd-migrate` — it refreshes your framework files from upstream and leaves your specs, decisions, patterns, and data-model untouched.

For a manual clone:

```bash
cd <your-project>
~/Projects/agent-plumb/scripts/update.sh
```

Your data is never touched: `INDEX.md`, `data-model.md`, `patterns.md`, `decisions.md`, `features/`, `ideas/`, and your project rules stay exactly as they were.

**Plugin install cache stuck on an old version?** Claude Code caches the install in a few places. Clear them and re-install:

```bash
rm -rf ~/.claude/plugins/marketplaces/agent-plumb/
rm -rf ~/.claude/plugins/cache/agent-plumb/
rm -rf ~/.claude/plugins/cache/temp_local_*/
```

Then re-run `claude plugin marketplace add https://github.com/samuelserraceo/agent-plumb` and `claude plugin install agent-plumb@agent-plumb`.

---

## Customizing for your project

`CLAUDE.md` at your project root has two clearly-marked sections:

```
<!-- SDD-MANAGED-START -->
   (workflow rules — overwritten on update)
<!-- SDD-MANAGED-END -->

## Project Rules
   (your stack, conventions, domain knowledge — yours forever)
```

Add anything project-specific below the END marker. Plumb updates won't touch it.

---

## Honest caveats

- **The playbook is 80% of the product.** If a question is weak, the system is weak. Fork and iterate — it's just markdown.
- **"Non-technical" has limits.** The agent proposes technical options; you decide what feels right. If you don't know what you *want the feature to do*, no workflow saves you.
- **Hooks have escape hatches.** Each one tells you in plain English how to proceed when blocked legitimately. Read the message — don't try to bypass.
- **Action prose still carries some JavaScript-stack assumptions** (`tests/task-NNN.mjs`, Tailwind, `gh pr create`). Non-JS adopters can fork the affected actions.
- **This scales to roughly 50 in-flight features / 500 total.** Beyond that, you want real tooling.
- **Retrofitting onto an existing project is still rough.** A clean repo is the smooth path.
- **Not a silver bullet.** It makes drift expensive and deep questioning cheap. It doesn't turn a bad idea into a good one.

---

## Status

Currently at **v1.10** — knowledge-graph foundation, four doctrine playbooks (feature / project / bug / refactor), branch-derived active-feature resolution, a CI graph-integrity gate, a cost-bounded Playwright explorer, a multi-model adapter, auto-advancing steps, specialised subagents, and `/sdd-migrate` for updatable installs. Hardened across many cycles of adversarial review, with a mutation-verified test suite.

---

## License

MIT — see the LICENSE file.
