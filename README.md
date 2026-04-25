# Spec-Driven Development Workflow (SDD)

> A stupidly simple, agent-driven workflow for building software with AI.
> **The state file is the program. The rubric is the questioning agent. The filesystem is the retrieval system.**
> No orchestrator, no database, no RAG.

---

## Who this is for

Solo builders and small teams — especially non-technical founders — who want to ship real software with AI agents without the agent drifting, assuming, or skipping the hard questions.

If you've ever had an AI agent build something that technically works but fundamentally misunderstood your intent — this fixes it.

---

## The loop

```
SPEC → PLAN → BUILD → VERIFY → LEARN → SHIPPED
  ↑                       ↓
  └── (bug task) ← CI fail
```

One feature moves through five phases. You **cannot** skip a phase. You cannot advance while any blocker (`[ ]`) in the current phase is unanswered.

1. **SPEC** — the agent walks a rubric. Some sections it asks you about in plain English (problem, success, user stories, sign-off). Other sections it *proposes* a concrete answer and explains tradeoffs (technical approach, data contract, flows, acceptance criteria). You bring the *what*, the agent proposes the *how*, you adjust together.
2. **PLAN** — once the spec is complete, the agent breaks it into atomic tasks, each linked to a test file.
3. **BUILD** — strictly test-first. For each task: write the test (must fail), write the code, test passes, commit. Move on.
4. **VERIFY** — runs every test via [agent-browser](https://agent-browser.dev). Generates a human sign-off checklist from your spec.
5. **LEARN** — on CI green, capture lessons, update the project's `patterns.md`, mark shipped.

---

## Why it works

### The state file *is* the program

Every feature has one `spec.md` file. That file is both the PRD and the state machine. Its sections have `[ ]` placeholders that the agent must fill — honestly, with your input — before it can do anything else. When all `[ ]` in the current phase are filled, the phase advances. That's the entire workflow logic.

No orchestrator. No engine. Just markdown and a tiny rubric.

### The filesystem *is* retrieval

Instead of a vector store:

```
.sdd/
  INDEX.md              # table of contents — one line per feature
  data-model.md         # canonical schema — every entity, every field
  patterns.md           # cross-feature learnings
  CLAUDE.md             # agent instructions
  features/
    001-user-auth/spec.md
    002-payments/spec.md
    ...
```

The agent's working context is bounded: `INDEX.md` + one active `spec.md` + `patterns.md`. Shipped features sit in the tree but out of context until referenced. Scales to hundreds of features without RAG.

### Enforcement without fragile hooks

Three tiny hooks:

1. `SessionStart` — prints the current state banner.
2. `UserPromptSubmit` — injects the state into every turn. The agent *cannot* forget where it is.
3. `PreToolUse(git commit)` — refuses commits if the current phase has open `[ ]`.

Each hook does one thing. None are clever. All are idempotent. That's why they work.

---

## Quick start

### 1. Install

```bash
git clone https://github.com/<you>/spec-driven-dev-workflow sdd-template
cd <your-project>
<path-to>/sdd-template/scripts/init.sh
```

This drops `.sdd/`, `.claude/`, and `rubric.md` into your project. It also installs `agent-browser` globally for UAT (skip with `--no-browser` if you prefer Playwright).

### 2. Open Claude Code in your project

The `SessionStart` hook prints the workflow state. On a fresh install it'll say "no active feature" and tell you how to start one.

### 3. Work your first feature

```
You: "Let's work on user auth"
Claude: (creates features/001-user-auth/, asks you Section 1.1: who has this problem?)
You: "People without accounts who want to sign up"
Claude: (writes it in, asks Section 1.2, and so on)
```

After SPEC, Claude proposes the tech approach (Section 4) with alternatives and tradeoffs — in plain English. You push back or agree. Then PLAN, BUILD, VERIFY, LEARN.

### 4. BUILD run modes

When the feature crosses PLAN → BUILD the agent asks how you want to run it:

1. **Step-by-step** — pause after every task.
2. **Checkpoint every 5** — auto-loop with periodic pauses (recommended).
3. **Full autonomous (conversation mode)** — agent loops in the session until blocked or done.
4. **Shell Ralph (headless)** — run `./scripts/ralph.sh` in a terminal. Each task gets a **fresh Claude invocation** with clean context — no bloat, no token creep. Best for 2+ hour unattended runs. See *Shell Ralph* below.

Universal halting rules apply in every mode (stuck after 3 attempts, hook block, real design gap, missing credentials).

### 5. Ship

```
/ship
```

Pushes the branch, opens a PR, watches CI. On pass, marks shipped. On fail, captures the error as a bug task and flips phase back to BUILD.

---

## Shell Ralph (the headless loop)

The original Ralph pattern: a shell `while` loop that spawns a **fresh** Claude invocation per iteration. Agent reads state files, does one task, exits. Context never bloats. Interrupt-resumable.

```bash
cd <project-root>
./scripts/ralph.sh                   # default: 50 iter max, 10 min/iter
MAX_ITERS=20 ./scripts/ralph.sh      # override
```

Only operates in BUILD phase. For SPEC / PLAN / VERIFY / LEARN, use conversation mode — those phases need discussion, not a loop.

Stops on:
- All tasks GREEN → advances to VERIFY, exits 0
- Halting rule fires (stuck after 3 attempts, hook block, design gap, missing creds) → exits 1 with the reason
- `MAX_ITERS` reached → exits 1 (re-run to continue; state is safe in files)
- Ctrl-C → exits 130 cleanly

Output is one line per iteration (`RALPH_STATUS: CONTINUE T3 duplicate email`). For detail, tail `git log` in another window.

**Caveat:** shell Ralph uses `--dangerously-skip-permissions` under the hood so the agent doesn't block on interactive approvals. That's safe here because the workflow's own enforcement (pre-commit hook, rubric `[ ]` gates, atomic commits, test-first) is doing the guardrail work — but you should only run it on a project you're OK letting the agent edit freely.

---

## Layout of this repo

```
.
├── README.md               # you are here
├── rubric.md               # the canonical SPEC rubric — the heart of the system
├── templates/              # what init.sh drops into your project
│   ├── .sdd/
│   │   ├── INDEX.md
│   │   ├── CLAUDE.md
│   │   ├── current-state.md
│   │   ├── data-model.md
│   │   ├── patterns.md
│   │   └── features/_template/
│   └── .claude/
│       ├── settings.json
│       ├── hooks/          # session-start, user-prompt-submit, pre-commit-block, learn-sync, schema-sync, scope-guard
│       └── commands/       # /next, /status, /ship, /compress, /skip
└── scripts/
    ├── init.sh
    ├── install-agent-browser.sh
    ├── ralph.sh                # shell Ralph loop for headless BUILD
    └── ship.sh
```

---

## The rubric (what the agent *actually* asks)

See [`rubric.md`](rubric.md) for the full canonical version. Summary:

| Section | Mode | What it captures |
|---|---|---|
| 1. Problem | user-led | Who, why now, what breaks without it |
| 2. Success | user-led | Verifiable outcomes |
| 3. User stories | user-led | As X, I want Y, so that Z |
| 4. **UX & Design brief** | **user-led** | **Tone, references, voice, emotional goal** — _skippable for non-UI features_ |
| 5. **Proposed approach** | **agent-led** | **Recommended solution + alternatives + tradeoffs** |
| 6. **Data contract** | **agent-led** | **Every entity, field, transition, edge case** |
| 7. Flows | agent-led | Happy path + 3 edge cases |
| 8. Dependencies | agent-led | APIs, auth, third parties — _skippable if nothing paid_ |
| 9. Out of scope | user-led | Explicit exclusions |
| 10. Non-functional | agent-led | Perf, security, a11y — _skippable if nothing relevant_ |
| 11. Acceptance criteria | agent-led | One test file per criterion |
| 12. Human sign-off | user-led | Manual test steps |

The depth of sections 5 and 6 is what makes this different from "the agent asks some questions." Each proposal shows alternatives, tradeoffs, and unknowns — *you don't need to know the technology, you just need to read plain-English tradeoffs and say what feels right.*

Skippable sections (§4, §8, §10, wireframe) are offered with a reason — type `/skip <reason>` to skip, or push back if they do apply.

---

## Customizing

- **The rubric** is just a markdown file. Edit it. Rename sections. Add/remove items. Your workflow.
- **Commands** in `templates/.claude/commands/` are Claude Code slash commands — edit the prompts to fit your style.
- **Hooks** are three shell scripts. Each ~30–80 lines. Read them, edit them, remove them.
- **Tests** use agent-browser by default. To swap to Playwright, change the task template in `rubric.md` and your `tests/` conventions.

---

## Honest caveats

- **The rubric is 80% of the product.** If its questions are weak, the system is weak. Fork and iterate.
- **"Non-technical" has limits.** The agent proposes technical options; you decide what feels right. If you don't know what you *want the feature to do*, no workflow saves you.
- **The commit-block hook can be annoying.** Disable it in `settings.json` if you find the soft enforcement (context injection) sufficient.
- **This scales to roughly 50 in-flight features / 500 total.** Beyond that, you want real tooling.
- **Not a silver bullet.** It makes drift expensive and deep questioning cheap. It doesn't turn a bad idea into a good one.

---

## Contributing

The rubric and the slash-command prompts are the most valuable things to improve. If a new section or a sharper question saves someone from a bad assumption, it pays for itself 100x. PRs welcome.

---

## License

MIT.
