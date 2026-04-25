---
description: Advance the SDD workflow by one step (ask, propose, or act on the next [ ] blocker).
---

$ARGUMENTS

You are running the SDD workflow. Do exactly one step — no more, no less.

## What to do

1. Read `.sdd/INDEX.md`. Identify the active feature from the `**Active:**` pointer line.
   - If there's no active feature and the user's `$ARGUMENTS` describe a new feature intent, pick the next free feature id (e.g. `001`), create `.sdd/features/<id>-<slug>/` by copying the template, copy `.sdd/rubric.md` to `.sdd/features/<id>-<slug>/spec.md`, update INDEX.md's `**Active:**` pointer and `## In flight` list, commit with `[SDD] init: features/<id>-<slug>`, then continue.
   - If there's no active feature and `$ARGUMENTS` is empty, ask the user: "What do you want to work on? (new feature name, or name an existing backlog item)."

2. Read `.sdd/features/<active>/spec.md`. Find the current phase (`[PHASE: X]`) and the first `[ ]` in that phase's sections.

3. Update the `Active blocker:` line at the top of spec.md to point at this blocker.

4. Take ONE action:
   - **[USER-LED] section** → ask the user a single plain-English question about this blocker. Do NOT fill from assumption. Push for specifics if the answer is vague.
   - **[AGENT-LED] section** → propose a concrete answer with tradeoffs. Explain in plain English. Show ≥2 alternatives and what each gives up. Ask the user "does this work for you?" Iterate until they agree, then write the agreed answer into spec.md.
   - **BUILD task (status: RED)** → ensure the test file exists, run it (must be RED), write code, run again (must be GREEN), then update the task line to `status: GREEN` and commit. **Honour the recorded `Run mode`** in the PHASE: BUILD section — step-by-step pauses after each task; checkpoint/autonomous loops per the CLAUDE.md protocol.
   - **Entering BUILD phase for the first time** (no `Run mode` recorded yet) → do NOT execute T1. Instead, ask the user for the run mode per the BUILD phase entry protocol in CLAUDE.md, record their choice, commit, then the NEXT `/next` starts T1.
   - **All [ ] in current phase filled** → advance `[PHASE: X]` to the next phase, update INDEX.md's pointer line, and commit with `[SDD:<id>] phase: <from> → <to>`. Then run `/next` again (or tell the user to).

5. Commit your changes using the convention in `.sdd/CLAUDE.md`:
   - Section filled: `[SDD:<id>] spec: <section name>`
   - Task commit: `[SDD:<id>][T<n>] <message>`
   - Phase advance: `[SDD:<id>] phase: <from> → <to>`

## Rules

- **Never** fill a `[ ]` without the user's input in USER-LED sections.
- **Never** advance phases with open `[ ]` in the current phase.
- **Never** batch multiple blockers in one turn. One step at a time. The user needs to see your thinking at each step.
- If the pre-commit hook blocks you, read its message, fix the blocker, and retry — do not try to bypass the hook.

End your turn by stating: "What's next: `<the next blocker>`" so the user knows what to expect on the next `/next`.
