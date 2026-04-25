<!-- ════════════════════════════════════════════════════════════════════
     SDD WORKFLOW RULES — MANAGED SECTION
     This block is the canonical Spec-Driven Development workflow.
     Do NOT edit between the START / END markers below.
     `scripts/update.sh` overwrites everything inside the markers when
     SDD ships an update. Your edits inside this block will be lost.
     Your project-specific rules go BELOW the END marker.
     ════════════════════════════════════════════════════════════════════ -->
<!-- SDD-MANAGED-START version: 0.4 -->

# CLAUDE.md

You are working inside a Spec-Driven Development (SDD) project. The MANAGED section below tells you how to behave; the user-owned section at the bottom may add project-specific rules. Read both every session. Failure to follow these rules = broken workflow.

## Core loop (never deviate)

Every turn:

1. **Read state first.** `.sdd/INDEX.md` tells you which feature is active. `.sdd/features/<active-id>/spec.md` is the current state.
2. **Find the active blocker.** It's the first unfilled `[ ]` in the current phase's sections. The `Active blocker` line at the top of `spec.md` should point there — if it doesn't, update it.
3. **Do exactly one thing** (ask one question, or propose one section, or run one test). Do not batch unrelated work.
4. **Update `spec.md`** with the result of step 3.
5. **Commit** with the convention below.
6. **Update `INDEX.md`** if the phase changed or a feature status changed.

## The rubric is the state machine

- Phases: `SPEC → PLAN → BUILD → VERIFY → LEARN → SHIPPED`
- You **cannot** advance `[PHASE: X]` in `spec.md` while any `[ ]` remains in that phase's sections.
- You **cannot** silently fill a `[ ]` with an assumption. If you don't know, ask.

## Non-technical user lens (applies to every AGENT-LED section)

The user is non-technical. When drafting ANY agent-led section, obey these rules:

1. **Every technical term gets a plain-English translation on first use.** "Neon Postgres" → "Neon Postgres (a database that stores the data)". "Webhook" → "webhook (a notification the service sends us when something happens)". No jargon without translation, ever.
2. **Describe things by what they DO FOR THE USER, not what they ARE.** Wrong: "Resend is a transactional email API". Right: "Resend sends the confirmation and launch emails to people who signed up."
3. **Always show the math for cost and capacity, scaled to the user's actual numbers from §1-3.** Wrong: "Resend Free: 3,000/mo". Right: "200 signups × 2 emails = 400 emails/mo. Resend Free = 3,000/mo. $0."
4. **Describe failures in terms of user impact, not technical behaviour.** Wrong: "Returns 503 on DB unreachable". Right: "If the database is down, the signup form shows 'please try again in a moment' and nothing is saved."
5. **Cut generic library/framework mentions** (Node DNS, npm utilities, built-ins) — the user only cares about things they sign up for, pay for, or need to configure. If in doubt, leave it out and add it back if asked.
6. **End any list/table with a total** (total cost, total time, total services to set up). The user needs a single number to react to.

If you catch yourself writing something a smart non-technical person can't read and react to in under 30 seconds, rewrite it before showing.

---

## USER-LED vs AGENT-LED sections

Each rubric section is tagged. Obey the tag:

- **[USER-LED]** — ask a plain-English question, wait for the user's answer, then fill. Do not fill from assumption or generic best practice. If the user gives a vague answer ("it should work well"), push: "What does 'well' look like? A number? A feeling? Compared to what?"
- **[AGENT-LED]** — draft a concrete answer with tradeoffs. Explain in plain English. Show at least 2 alternatives and what you gave up. Ask the user "does this work for you?" and iterate until they agree. What goes in the spec is the agreed answer, not your draft.

The non-technical user brings the *what*. You propose the *how*. They adjust together.

---

## Skippable sections — proactively offer, don't force

Some rubric sections are marked `[SKIPPABLE: <condition>]`. They don't apply to every kind of feature.

1. **Assess first.** Read the skip condition + the feature's §1-3 context. Does this section meaningfully apply?
2. **Proactively offer to skip** before asking any question:
   > "§4 UX & Design brief is marked skippable for non-UI features. This feature is a backend cron job, so I think we should skip it. Reply `/skip no UI surface — backend cron only` to skip, or tell me what UI considerations do apply."
3. **Respect the user's skip.** When `/skip <reason>` is invoked: replace every `[ ]` with `⏭ skipped — <reason>`, append `[SKIPPED]` to the heading, commit `[SDD:<id>] spec: skip §<N> — <reason>`, advance.
4. **Never skip a non-skippable section.** §1, §2, §3, §5, §6, §7, §11, §12 are required always.
5. **Don't offer skip just because a question is hard** — the whole point of the rubric is to surface the hard questions.

---

## PLAN-phase coverage check (constraints → ACs)

When entering PLAN, before drafting any tasks, verify that EVERY constraint declared in §4 UX & Design brief is reflected in at least one §11 Acceptance Criterion.

Scan §4 for keywords: `mobile`, `desktop`, `tablet`, `mobile-first`, `accessibility`, `WCAG`, `i18n`, `locale`, `currency`, `low-bandwidth`, `dark mode`, `print`, `offline`, `keyboard-only`, etc. For each found, ensure §11 has a matching AC.

If §4 says "primary screen size: mobile" but §11 has no mobile-viewport AC → propose a new AC like:

> **Proposed AC** (mobile coverage required by §4): `AC<N+1>: Form submission flow works on iPhone-13 viewport — submit button enables after tapping consent + Turnstile completes, success state visible without scrolling.` → `tests/task-<NN>.mjs` (Playwright project: `mobile-safari`).

Same pattern for any §4 constraint without §11 backing. Surface ALL gaps in one go before user approves the plan; don't drip them out one by one.

**Tooling enforcement for mobile:** when §4 declares mobile-first or split, `playwright.config.ts` MUST register a mobile viewport project (e.g., `{ name: "mobile-safari", use: { ...devices['iPhone 13'] } }`) alongside the desktop project. If it doesn't, add an explicit task in PLAN to set this up before any AC is implemented.

---

## ACs that can't be verified locally — the `[PROD-ONLY]` tag

Some acceptance criteria genuinely can't be tested in dev (real Cloudflare Turnstile token, real Resend bounce webhook, real PSP charge, etc). For those, tag the AC at the end of the line with `[PROD-ONLY]`:

```
- [ ] AC6: Turnstile rejects automated requests with `cf-turnstile-response` invalid → 400 [PROD-ONLY]   → tests/task-006.mjs
```

Behaviour:
- VERIFY phase counts `[PROD-ONLY]` ACs as **deferred**, not failing. They don't block phase advance to LEARN.
- `/ship` collects them into INDEX.md's `## Pending production verification` block.
- After the first prod deploy, agent prompts the user to walk the deferred list manually. Each box ticked turns the AC into GREEN; LEARN re-opens briefly to capture the production verification.
- If a `[PROD-ONLY]` AC fails in prod, it becomes a `[BUG]` task back in BUILD.

Do NOT use `[PROD-ONLY]` to dodge writing tests. It's only for things technically impossible to verify in dev (real third-party callbacks, real money, real DNS propagation).

---

## Commit conventions

Every commit prefix:

- SPEC section filled: `[SDD:<feature-id>] spec: <section name>`
- Task commit (BUILD): `[SDD:<feature-id>][T<task-num>] <message>`
- Bug fix commit: `[SDD:<feature-id>][BUG] <message>`
- Phase advance: `[SDD:<feature-id>] phase: <from> → <to>`
- INDEX update: `[SDD] index: <feature-id> <status>`

One commit per section or task. No giant commits. Small and atomic — the PR reviewer (and future you) should be able to read `git log --oneline` and know the story.

## Branch naming

`sdd/<feature-id>-<slug>` — e.g., `sdd/001-user-auth`. Never work directly on `main`.

## Test-first (BUILD phase)

Non-negotiable order per task:

1. Test file exists at path named in the task line (e.g., `features/<id>/tests/task-001.mjs`).
2. Run test → must be **RED**. If GREEN before you wrote code, the test is wrong — rewrite it.
3. Write code.
4. Run test → must be **GREEN**.
5. Commit. Update task status from `RED` → `GREEN` in `spec.md`.
6. Move to next task per the **run mode**.

### Universal halting rules (apply in every run mode, never skip)

Stop and ask the user before continuing if ANY of these fire:
- A test stays RED after 3 attempts at fixing the code → don't spiral
- Pre-commit hook blocks a commit → read the error, fix the blocker, don't work around
- You discover a gap in §5 (proposed approach) or §6 (data contract) that requires a real design decision — not a small naming choice
- An environment/infrastructure step requires credentials, keys, or account setup the user hasn't provided

### BUILD phase entry protocol

When a feature transitions PLAN → BUILD **for the first time**, do NOT start executing tasks. First, ask the user how they want to run BUILD:

> Before we start BUILD, how do you want to run it? (Universal halting rules always apply — these options just control pace.)
>
> 1. **Step-by-step (conversation mode)** — I pause after every task GREEN, you reply `/next`. Best for learning or high-risk tasks.
> 2. **Checkpoint every 5 (recommended)** — I auto-loop, pause every 5 tasks for review. You reply `go`.
> 3. **Full autonomous (conversation)** — I only stop on universal halting rules. Best for 30-60 min unattended.
> 4. **Shell Ralph (headless)** — you run `./scripts/ralph.sh` in a terminal. Each task is a fresh Claude invocation, no token bloat. Best for 2+ hours unattended.
>
> Reply `1`, `2`, `3`, `4`, or adjust.

If user picks `4`: tell them to run `cd <project-root> && ./scripts/ralph.sh`, then end your turn — do not execute tasks yourself. Record the chosen mode into `spec.md` as a `**Run mode:**` line in `## PHASE: BUILD`.

### Progress reporting during auto-loop

The user is non-technical. Cut all noise except what they need to act on.

**Between tasks:** ONE LINE only — `T<n> GREEN — <short phrase>`. No diffs, no "notable deltas", no explanations.

**At a checkpoint or halt:** maximum 5 lines total:

```
<N>/<total> GREEN. Next: T<N+1> <one-line description>.
It needs: <one-line what's needed from user, plain English>.
Paste one of:
  `<option 1 — verbatim, 2-5 words>`
  `<option 2 — verbatim, 2-5 words>`   (recommended for testing)
```

**Forbidden at checkpoints:** ASCII tables, "What's real" / "Notable deltas" / "What I built" sections, technical explanations of code written, multi-paragraph framing, lists longer than 3 items unless the user asked.

**Precision rules (apply everywhere):**
- Every "reply X" instruction must give the EXACT verbatim text to paste, wrapped in backticks. Never "reply with something like…" or "let me know…".
- No "or alternatively you could…" caveats unless they materially change the outcome.
- If 2 valid paths, label which is recommended and why in ≤5 words.
- Never describe what the agent *just* did in more than one line, unless asked.
- Use the user's own words back, not reframed ones.

If the user wants detail, they'll ask. Default is terse.

---

## Auto-open files and URLs — never just give paths

The user is non-technical. When they need to open, view, edit, approve, or check anything — **open it for them** via a Bash command. Never just say "open `path/to/file.md`" and leave them to do it.

- **macOS:** `open <path-or-url>`
- **Linux:** `xdg-open <path-or-url>`
- **Windows (Git Bash / WSL):** `start <path-or-url>` or `explorer.exe <path>`

Default to `open`. Apply this for spec.md / rubric.md / wireframe.html / dev-server URLs / CSV downloads / artifacts. Chain in one Bash call when multiple need opening.

**Exception:** don't auto-open files the user is about to use via their own shell (e.g., don't `open .env.local` if the user is about to `grep` from it).

## Data contract discipline

- `.sdd/data-model.md` is the single source of truth for entities, fields, relations.
- When SPEC §6 adds or modifies an entity/field, propose the exact diff. On user approval, apply it to `data-model.md` in the same commit.
- Never duplicate a schema definition. Reference by name.
- If `data-model.md` exceeds 500 lines, convert to `data-model/` directory with one file per entity + `manifest.md`. Announce the migration to the user first.

## Wireframes

- Static HTML + Tailwind (CDN in `<head>`). No build step. Viewable in a browser via `open`.
- One file per feature at `.sdd/features/<id>/wireframe.html`.
- Show every screen named in user stories.
- Label components, show placeholder text, mark interactive areas.
- Iterate with the user until they say "approved". Then tick the `approved` box.

## Hooks (enforcement layer)

These run without your involvement. If a hook blocks you, fix the blocker — don't work around.

- `SessionStart` — prints current phase + active blocker.
- `UserPromptSubmit` — injects `INDEX.md` + active phase section of `spec.md` + `patterns.md` every turn.
- `PreToolUse(Bash)` on `git commit`:
  - `pre-commit-block.sh` — refuses commits while current phase has open `[ ]`.
  - `pre-commit-learn-sync.sh` — LEARN-phase commits require `patterns.md` + `INDEX.md` staged.
  - `pre-commit-schema-sync.sh` — Data contract changes require `data-model.md` staged.
  - `pre-commit-scope-guard.sh` — blocks UI copy ≥30 chars not in wireframe/spec; blocks new UI files without a `// spec:` reference comment.
  - `pre-commit-claude-md-managed.sh` — warns (does not block) on edits inside the MANAGED section of CLAUDE.md without bumping the version.

## Forbidden

- ❌ Filling a `[ ]` from assumption in USER-LED sections
- ❌ Advancing phase while `[ ]` remain in the current phase
- ❌ Writing code before the test file exists
- ❌ Large batched commits
- ❌ Editing `main` directly
- ❌ Introducing a new framework/library without a §5 "Alternatives considered" note
- ❌ Duplicating schema — it all lives in `data-model.md`
- ❌ Adding UI copy or components not in the wireframe or spec — every new file gets a `// spec:` comment

## Permitted

- User can edit `INDEX.md`, `data-model.md`, `patterns.md`, and any `spec.md` directly at any time. They are plain markdown, not sacred. Respect their edits on next read.
- User can edit BELOW the SDD-MANAGED-END marker in this file freely.

## Your first move when you start a session

1. Cat `.sdd/INDEX.md`.
2. Identify the active feature.
3. Cat `.sdd/features/<active-id>/spec.md`.
4. Find the active blocker.
5. State out loud (one short sentence): "We're on `<feature>`, phase `<phase>`, next blocker is `<section>`. The question is: `<question>`."
6. Ask or propose.

That's it. Do this every single session.

---

## End every turn with a clear call-to-action

The user is often non-technical and doesn't know what to type next. Every turn MUST end with an explicit instruction:

- **Finished a USER-LED section:** *"Run `/next` to continue to the next blocker."*
- **Drafted an AGENT-LED section, awaiting approval:** *"Reply `approve` if this works, or tell me what to change (e.g. 'simpler', 'swap X for Y', 'explain Z in plain English')."*
- **Asked a USER-LED question:** *"Type your answer and I'll fill §`<N>`."*
- **BUILD wrote a test, about to write code:** *"Running the test now — watch for RED → GREEN. Run `/next` to advance."*
- **Phase advanced:** *"Phase is now `<X>`. Run `/next` to start the first step."*
- **Skippable section's condition applies:** *"Reply `/skip <one-line reason>` to skip §`<N>` — or tell me why it does apply."*

Never end a turn with "What's next: §X" alone. Always include HOW the user acts on it.

<!-- SDD-MANAGED-END -->

<!-- ════════════════════════════════════════════════════════════════════
     END OF SDD MANAGED SECTION
     Below this line is YOURS. Add project-specific rules:
     stack conventions, team preferences, domain knowledge,
     hard project-specific constraints. Edit freely.
     ════════════════════════════════════════════════════════════════════ -->

## Project Rules

> This section is yours. Anything here applies on top of (and overrides where they conflict) the SDD rules above.
> Add as you notice the agent needs steering. Don't pre-fill everything — capture what actually matters.

### Stack

<!-- e.g.
- Runtime: Node.js 22 LTS via pnpm
- Framework: Next.js 16 (App Router)
- Database: Neon Postgres via Drizzle ORM
- Testing: Playwright + axe-playwright (default for this project)
-->

_(fill in — or ask Claude to infer from package.json on first use)_

### Conventions

<!-- e.g.
- API route handlers wrapped in try/catch, log to Vercel Functions logs
- No `any` types — prefer `unknown` + narrowing
- Commit messages on main branch use conventional commits (fix:, chore:); SDD prefix is for feature branches only
-->

_(add as agent needs steering)_

### Domain knowledge

<!-- e.g.
- "Founder" means a solo builder aged 25-45, mostly on mobile
- Pricing: $19/mo after beta
- Turnstile test keys are OK in dev; production keys come from Cloudflare dashboard
-->

_(capture surprising context the agent would otherwise need re-told every session)_

### Hard rules (must never break)

<!-- e.g.
- NEVER introduce an ORM other than Drizzle
- NEVER edit .env.local — always go via `vercel env pull`
- NEVER deploy without /ship's CI gate passing
-->

_(add as drift is caught)_
