---
description: Advance the SDD workflow by one step (ask, propose, or act on the next [ ] blocker).
---

$ARGUMENTS

You are running the SDD workflow. Do exactly one step — no more, no less.

## What to do

1. Read `.sdd/INDEX.md`. Identify the active work item from the `**Active:**` pointer line.
   - **No active work item** → tell the user, in plain English: *"No active work item. Run `/start <one-line title>` to scaffold a new one (e.g., `/start build a waitlist landing page`)."* Stop here. `/next` does not bootstrap — `/start` is the single entry point for new work.

2. Read `.sdd/<active>/spec.md` (the path comes from INDEX.md's `**Active:**` line — it might be `features/<id>-<slug>` for B-1, or other folder names if Phase C playbooks ship). Find the current phase (`[PHASE: X]`) and the first `[ ]` in that phase's sections.

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
- **Never** bootstrap a new work item from `/next` — that's `/start`'s job. If the user asks `/next` to start something new, route them to `/start <title>`.
- If the pre-commit hook blocks you, read its message, fix the blocker, and retry — do not try to bypass the hook.

End your turn with an explicit next-action prompt per the call-to-action rules in `.sdd/CLAUDE.md`. Format: state what you just did + what to type next + (if applicable) the question or option you're presenting. Never end with "What's next: §X" alone.
