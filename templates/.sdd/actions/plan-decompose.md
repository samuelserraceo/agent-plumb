---
type: action
slug: plan-decompose
tag: AGENT-LED
model_tier: routine
prelude_refresh: true
title: "plan-decompose"
short_label: "Plan"
steps:
  - { id: tasks, action: "convert acceptance criteria into ordered build tasks (one test file per task)", field: "BUILD.tasks" }
used_by: [feature]
references: [acceptance-criteria, success, user-stories, ux-brief]
touches: [".sdd/<work-item>/spec.md", ".sdd/<work-item>/wireframe.html"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

Convert `acceptance-criteria` into ordered tasks. Each task = one test file + one commit. This is what BUILD will execute.

**Fresh-project bootstrap preflight (closes #178) — runs FIRST.** Before the coverage check, before drafting any tasks: detect whether this is the first feature in a fresh project. If yes, auto-prepend a `T00 [CHORE]` task that scaffolds the project skeleton; downstream tasks then assume the skeleton exists. Without this, T01 hits *"file not found: package.json"* on the first BUILD iteration and halts (exactly the failure mode pipelogic_v2 hit at F01 BUILD entry, 2026-05-07).

Detection — stack-aware "is the project skeleton in place?" check (read `.sdd/stack.md` or look for any of these markers at the project root):

| Stack signal           | "Fresh project" if missing             |
|------------------------|-----------------------------------------|
| Node / TypeScript      | `package.json`                          |
| Python                 | `pyproject.toml` OR `requirements.txt`  |
| Rust                   | `Cargo.toml`                            |
| Go                     | `go.mod`                                |
| Ruby                   | `Gemfile`                               |
| .NET                   | `*.csproj`                              |

If `.sdd/stack.md` declares a stack, use that to pick the marker; otherwise infer from existing files in the project root. If the marker exists, **skip** the bootstrap preflight — the skeleton is already in place. If the marker is missing, this is feature 1 of a fresh project.

If fresh, prepend this task BEFORE T01 — keep it stack-aware. Read `.sdd/stack.md` for the declared stack, then fill the placeholders below from that stack's idioms (don't hardcode Node/Next).

```markdown
- [ ] T00 [CHORE]: Project bootstrap — install dependencies + framework skeleton
  Test path: features/<id>/tests/task-000-bootstrap.smoke.<stack-test-ext> (stack-appropriate smoke that verifies the scaffold boots — e.g. "dev server returns 200 on /" for a web app, "binary builds and exits 0" for a CLI, "package imports cleanly" for a library)
  Effort: S
  Touches: stack-specific manifest + lockfile + framework-default config + framework entry-point(s)
  Note: chore-shape — test-first discipline relaxed; the smoke verifies the scaffold boots/runs for the declared stack, not feature behaviour
```

Stack-specific touches you fill in from `stack.md` (examples — pick the row that matches; the agent populates the actual paths from the project's stack):

| Stack         | Manifest + lockfile             | Framework config              | Entry-point(s)              |
|---------------|---------------------------------|-------------------------------|------------------------------|
| Node + Next.js | `package.json` + `pnpm-lock.yaml` | `tsconfig.json`, `next.config.ts` | `src/app/layout.tsx`, `src/app/page.tsx` |
| Python        | `pyproject.toml` + `requirements.txt` | `ruff.toml`, `mypy.ini`     | `src/main.py` or framework-specific |
| Rust          | `Cargo.toml` + `Cargo.lock`     | `rust-toolchain.toml`         | `src/main.rs` or `src/lib.rs` |
| Go            | `go.mod` + `go.sum`             | (often none — toolchain only) | `main.go`                    |
| Ruby          | `Gemfile` + `Gemfile.lock`      | `.rubocop.yml`                | `config.ru` (Rack) or `app.rb` |
| .NET          | `*.csproj` + `packages.lock.json` | `Directory.Build.props`     | `Program.cs`                 |

**If `.sdd/stack.md` doesn't yet declare a stack** — i.e. project-bootstrap-time-so-fresh-that-the-stack-isn't-decided-either — pause and ask the user before proceeding: *"What stack are we building this on? I'll fill T00's bootstrap details from your answer and write the stack into stack.md so future actions read it."* Don't guess; this is exactly the *never assume — always ask* doctrine.

The `[CHORE]` tag tells BUILD's run-mode that this task is mechanical (no human spec decision needed) so even checkpoint-every-1 modes proceed without pausing. Downstream tasks (T01+) use the stack's manifest / config / entry-point without re-creating them.

## Walking-skeleton T01 (closes #211 — vertical-first doctrine)

**Why this exists.** AI agents default to **horizontal building**: complete one architectural layer before starting the next. Result: months of beautiful surface code that breaks at the first real integration. The cure is **vertical-first** (also called walking skeleton, tracer bullet, steel thread): pick one narrow story that exercises every architectural layer in the simplest way possible, then widen by adding more vertical slices. Each slice forces real cross-layer integration on real code; abstractions emerge from demand, not premature design. Dogfood evidence: pipelogic_v2 F01's planned T15 (theme toggle) assumed the full app shell existed across multiple layers — it didn't, and BUILD halted on iteration 1. patterns.md captured this as *"Foundation features need a T0 bootstrap task"* — that lesson became #178's bootstrap preflight (which scaffolds the runtime). **#211 is the next layer up: when the stack declares ≥3 architectural layers, T01 itself should be a vertical slice through ALL of them, not a single-layer increment.**

**Detection — when does this apply?** Read `.sdd/stack.md` and count distinct architectural layers it declares. Common layer markers:

| Layer | stack.md signal |
|---|---|
| Frontend | `Web: Next.js / React / Vue / SvelteKit / …` |
| Backend / API | `Backend: Node / FastAPI / Rails / …` |
| Database | `Data store: Postgres / Mongo / Redis / …` |
| Job runner | `Cron / queue / worker: …` |
| External service | `Third-party: Stripe / Resend / Cloudflare / …` |
| Agent layer | `MCP server: enabled` / `Tier 3: enabled` |

**If stack.md declares ≥3 distinct layers AND this is the project's first behaviour-touching feature** (no prior shipped feature has exercised all layers end-to-end — check `.sdd/INDEX.md` `## Shipped`), the walking-skeleton check fires. Otherwise skip — the project already has a vertical proven by prior shipped work, or it's small enough that T01 = a single AC is fine.

**The check (two paths, parallel to the §4-constraints coverage check below).**

1. **Read §11.** Does at least one existing AC touch every layer end-to-end? *Concrete test: imagine the AC's success line — does proving it require writing or reading data through every architectural layer named in stack.md? If yes, that AC is the walking-skeleton candidate.*
2. **(a) If yes → T01 maps to that AC.** Note the AC explicitly in T01's prose: *"T01: <AC text> — walking-skeleton (touches every layer; subsequent tasks widen)."* Mark its `touches:` with paths from each layer (e.g., `app/page.tsx + app/api/route.ts + db/migrations/0001_init.sql + extensions/sdd-mcp-server/server.py`). No extra AC needed.
3. **(b) If no → propose adding a walking-skeleton AC + re-approve §11.** Surface to the user: *"§11's ACs are layer-specific (each touches one or two layers, not all of them). For an N-layer project, BUILD will fall into the horizontal trap unless T01 lights up the whole stack first. I propose adding **AC<N>: <single-sentence story that touches every layer, even if each layer is trivial>**. Then T01 maps to it; subsequent tasks widen by adding behaviour ACs."* Same two-step pattern as the §4-constraints check below: user approves the new AC → §11 re-approved via inline `/re-approve` → THEN draft tasks.

**Concrete example — pipelogic_v2's 7-layer stack.** stack.md declares: Frontend (Next.js) + Backend (Next API routes) + Database (Postgres) + Compute layer (SQL views) + Apps layer (saved queries) + Agent layer (MCP) + Sources layer (CSV/GSheet ingestion). 7 layers. F02's walking-skeleton AC could be:

> *"AC1: User uploads `orders.csv` → row count appears in the Map page within 5 seconds. Then typing 'top SKU last week?' into the agent returns a SKU string that matches the manually-computed answer from the CSV."*

That single AC, when proven, requires every layer working: source ingestion (L1), table storage (L2), materialised view query (L3), frontend display (L4), saved query app (L5), agent invocation (L6) — plus the Map page (L0). T01 maps to it, T01's `touches:` names a path from each layer, and the test asserts the end-to-end behaviour. Subsequent F02 tasks (T02+) widen by adding behaviour-only ACs that don't introduce new layers.

**Decline path.** If the user has a reason to skip the walking-skeleton (e.g., *"L6 agent isn't built yet — F02 only ships L0-L5"*), they can decline. Record the reason in `decisions.md`; downstream features carry the gap.

**Coverage check FIRST — and it's a TWO-STEP process when gaps exist.** After the bootstrap preflight (which runs once, never again) AND the walking-skeleton check (also once-per-project), verify every constraint in `ux-brief` (mobile, accessibility, i18n, locale, dark mode, etc.) is reflected in ≥1 AC in §11. Surface ALL gaps in one go, don't drip them.

**§11 is section-locked** (`requires_user_approval: true`) — its content is hashed at approval time and the moat refuses any commit that diverges from the hash. So you can't silently add new ACs; that would break section-locking. Split the work into two atomic steps:

1. **(a) If new ACs are needed:** propose them, the user approves them via natural conversation, then re-approve §11 via the inline `/re-approve` flow in `/next.md` (a v0.9 doctrine — the inline re-approval handler appends the new ACs, re-runs `hash-section`, updates the §11 hash in `verification.json`, and lands a re-approval entry in `decisions.md`). Only after §11 is re-approved with the new ACs does the next step start.
2. **(b) THEN, in a follow-up step:** write the task list against the now-complete §11.

If §11 already covers every §4 constraint, skip step (a) and go straight to step (b).

**Map ACs → tasks 1:1.** T1 → AC1, T2 → AC2, etc. Order matters: dependencies first (e.g., schema migration before form), then features.

**Format:**

```markdown
- [ ] T01: User form submission and email dispatch
  Test path: features/<id>/tests/task-001.mjs
  Effort: S
- [ ] T02: Email confirmation link validation
  Test path: features/<id>/tests/task-002.mjs
  Effort: XS
```

**Effort estimates** (be honest):
- **XS** — < 30 min · **S** — 30 min - 2h · **M** — 2-6h · **L** — 6-16h · **XL** — 16h+

If multiple tasks cluster as L or XL, split them. *"Implement the entire payment flow"* → split into *"Stripe form"*, *"token validation"*, *"transaction record"*, *"receipt email"*.

**Validation:** ≥1 task required (exit-check `C-spec-tasks`). If 0 tasks, the feature is too thin or ACs are too vague.

**Output:** fill `spec.md` under `### plan-decompose` with the task list.

**What it looks like:**

Now I'll turn the checklist (acceptance criteria) into a concrete to-do list of build steps. Each step = one test + the code to make it pass + one commit.

Example: *"T01 — write the signup form's HTML; T02 — submit form posts to /api/signup; T03 — invalid emails return a clear error; T04 — valid emails create a row in the database; T05 — confirmation email gets sent within 5 sec; ..."* You see the whole list before I start, and you pick the **run mode** (do you want to eye-check each step, or let me run all the way through?).

**End the turn with:** *"SPEC is now complete. Reply `looks good` to advance to BUILD, or tell me what to reorder/split/merge. Then run `/next` to continue."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If this action's answer changes anything user-visible (a screen, a button, a flow, a page transition, a form field), **also update `wireframe.html`** in the same commit. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.

Mechanical enforcement (a state_rule that refuses spec commits without wireframe staging when wireframe.html exists) lands in v0.11 — see issue #45.
