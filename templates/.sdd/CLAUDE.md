# SDD Agent Instructions

You are working inside a Spec-Driven Development (SDD) workflow. This file tells you how to behave. Read it every session. Failure to follow these rules = broken workflow.

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

Some rubric sections are marked `[SKIPPABLE: <condition>]`. That means they don't apply to every kind of feature. Your job on those sections:

1. **Assess first.** Read the skip condition plus the feature's §1-3 context. Does this section meaningfully apply?
   - Example: feature is "nightly data-retention cron job" → §4 UX & Design and the wireframe are `[SKIPPABLE: non-UI features]` → they do not apply.
2. **Proactively offer to skip** before asking any question:
   > "§4 UX & Design brief is marked skippable for non-UI features. This feature is a backend cron job with no user interface, so I think we should skip it. Reply `/skip no UI surface — backend cron only` to skip, or tell me what UI considerations do apply."
3. **Respect the user's skip.** When the user invokes `/skip <reason>`, or replies with "skip" + a reason:
   - Replace every `[ ]` in that section with: `⏭ skipped — <reason captured verbatim>`
   - Add a `[SKIPPED]` marker at the end of the section heading line
   - Commit: `[SDD:<id>] spec: skip §<N> — <reason>`
   - Advance to the next blocker
4. **Never skip a non-skippable section.** §1, §2, §3, §5, §6, §7, §11, §12 are required always. If the user insists, push back once — it usually means they're tired, not that the section actually doesn't apply.
5. **Don't offer skip for sections not marked skippable.** And don't offer skip just because a question is hard — the whole point of the rubric is to surface the hard questions.

After a skip, the section still appears in the dashboard and in the PR body — shown as "skipped (reason)" rather than hidden, so the history is transparent.

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

Non-negotiable order:

1. Test file exists at path named in the task line (e.g., `features/<id>/tests/task-001.mjs`).
2. Run test → must be **RED**. If GREEN before you wrote code, the test is wrong — rewrite it.
3. Write code.
4. Run test → must be **GREEN**.
5. Commit. Update task status from `RED` → `GREEN` in `spec.md`.
6. Move to next task.

If a test stays RED after 3 attempts at fixing the code, stop and ask the user. Something is wrong with your understanding — don't spiral.

## Data contract discipline

- `.sdd/data-model.md` is the single source of truth for entities, fields, relations.
- When SPEC §6 adds or modifies an entity/field, propose the exact diff. On user approval, apply it to `data-model.md` in the same commit.
- Never duplicate a schema definition. Reference by name.
- If `data-model.md` is getting unwieldy (>500 lines), convert to `data-model/` directory with one file per entity + `manifest.md`. Announce the migration to the user first.

## Wireframes

- Static HTML + Tailwind (via CDN in `<head>`). No build step. Viewable in a browser with `open wireframe.html`.
- One file per feature at `features/<id>/wireframe.html`.
- Show every screen named in user stories.
- Label components, show placeholder text, mark interactive areas.
- Ask the user to open it and give feedback. Iterate until they write "approved". Then tick the `approved` box.

## Hooks (enforcement layer)

Three hooks run without your involvement:

1. `SessionStart` prints current phase + active blocker.
2. `UserPromptSubmit` injects `INDEX.md` + active `spec.md` summary at top of context. You always see the state — no excuse for drifting.
3. `PreToolUse(Bash)` on `git commit` refuses the commit if the current phase has open `[ ]`. If blocked, fill the blocker and retry.

If a hook blocks you, the error message tells you what's wrong. Fix the blocker. Do not try to work around the hook.

## Forbidden

- ❌ Filling a `[ ]` from assumption in USER-LED sections
- ❌ Advancing phase while `[ ]` remain in the current phase
- ❌ Writing code before the test file exists
- ❌ Large batched commits
- ❌ Editing `main` directly
- ❌ Introducing a new framework/library without a §5 "Alternatives considered" note
- ❌ Duplicating schema — it all lives in `data-model.md`

## Permitted (by the user, explicitly)

- User can edit `spec.md`, `INDEX.md`, `data-model.md`, `patterns.md` directly at any time. They are plain markdown, not sacred. Respect their edits on next read.

## Your first move when you start a session

1. Cat `.sdd/INDEX.md`.
2. Identify the active feature (usually marked `[ACTIVE]`).
3. Cat `.sdd/features/<active-id>/spec.md`.
4. Find the active blocker (top of file, or first `[ ]` in the current phase).
5. State out loud (one short sentence): "We're on `<feature>`, phase `<phase>`, next blocker is `<section>`. The question is: `<question>`."
6. Ask or propose.

That's it. Do this every single session.

---

## End every turn with a clear call-to-action

The user is often non-technical and doesn't know what to type next. Every turn MUST end with an explicit instruction telling them what verbatim thing to type or which slash command to run. No ambiguity. Pick the form that matches the situation:

- **You just finished filling a USER-LED section** → end with: *"Run `/next` to continue to the next blocker."*
- **You just drafted an AGENT-LED section and want approval** → end with: *"Reply `approve` if this works for you, or tell me what to change (e.g. 'simpler', 'swap X for Y', 'explain Z in plain English')."*
- **You just asked a USER-LED question** → end with: *"Type your answer and I'll fill §`<N>`."*
- **BUILD just wrote a test and is about to write code** → end with: *"Running the test now — watch for RED → GREEN. Run `/next` to advance."*
- **Phase advanced** → end with: *"Phase is now `<X>`. Run `/next` to start the first step."*
- **Current section is `[SKIPPABLE]` and the skip condition applies** → end with: *"Reply `/skip <one-line reason>` to skip §`<N>` — or tell me why it does apply and we'll fill it."*

Never end a turn with "What's next: §X" alone — always include HOW the user acts on it. Short, imperative, verbatim.
