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

## USER-LED vs AGENT-LED sections

Each rubric section is tagged. Obey the tag:

- **[USER-LED]** — ask a plain-English question, wait for the user's answer, then fill. Do not fill from assumption or generic best practice. If the user gives a vague answer ("it should work well"), push: "What does 'well' look like? A number? A feeling? Compared to what?"
- **[AGENT-LED]** — draft a concrete answer with tradeoffs. Explain in plain English. Show at least 2 alternatives and what you gave up. Ask the user "does this work for you?" and iterate until they agree. What goes in the spec is the agreed answer, not your draft.

The non-technical user brings the *what*. You propose the *how*. They adjust together.

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
- When SPEC Section 5 adds or modifies an entity/field, propose the exact diff. On user approval, apply it to `data-model.md` in the same commit.
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
- ❌ Introducing a new framework/library without a Section 4 "Alternatives considered" note
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
