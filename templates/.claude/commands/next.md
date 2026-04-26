---
description: Advance the SDD workflow by one step (ask, propose, or act on the next [ ] blocker).
---

$ARGUMENTS

You are running the SDD workflow. Do exactly one step — no more, no less.

## What to do

1. Read `.sdd/INDEX.md`. Identify the active feature from the `**Active:**` pointer line.
   - **No active feature, user wants to start one** → run the **New-feature bootstrap** protocol below (Section A). This is non-negotiable: the feature branch MUST be created BEFORE any feature files are written, otherwise `/ship` later won't work.
   - **No active feature, `$ARGUMENTS` empty** → ask: "What do you want to work on? (new feature name, or pick an existing backlog item)."

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

---

## Section A — New-feature bootstrap (MUST follow this exact order)

When starting a brand-new feature, do these steps in order. Do NOT skip the branch creation; it's the difference between `/ship` working later and you having to do git surgery.

**Step 1 — Confirm git is initialized.**
```bash
git rev-parse --git-dir >/dev/null 2>&1 || git init -b main
```
If a fresh `git init` happened, also do an initial commit of the existing scaffolding so the feature branch has a parent:
```bash
if ! git rev-parse HEAD >/dev/null 2>&1; then
  git add -A && git commit -m "[SDD] init: scaffold (pre-feature)"
fi
```

**Step 2 — Confirm we're on `main` and clean.**
```bash
current=$(git rev-parse --abbrev-ref HEAD)
if [ "$current" != "main" ]; then
  echo "Not on main — currently on $current. Stop and resolve before starting a new feature."
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree has uncommitted changes. Either commit them or stash before starting a new feature."
  exit 1
fi
```
If either check fails, STOP and tell the user in plain English what to do (e.g. "Your tree has uncommitted changes — commit or stash first, then run `/next` again").

**Step 3 — Pick the feature id and slug.**
- Scan `.sdd/features/` for highest existing 3-digit prefix; new id = highest + 1, zero-padded (`001`, `002`, ...).
- Slug = kebab-case of the user's intent, ≤40 chars, ASCII only. Example: "post-signup survey" → `post-signup-survey`.
- Final folder name: `<id>-<slug>` (e.g. `002-post-signup-survey`).

**Step 4 — Create the feature branch FROM main BEFORE any file writes.**
```bash
git checkout -b sdd/<id>-<slug>
```
Now we're on the feature branch. Every commit from here flows there, not main. `/ship` later will push this branch and open a PR against main — the way the workflow is designed.

**Step 5 — Create the feature folder structure.**
```bash
cp -R .sdd/features/_template .sdd/features/<id>-<slug>
cp .sdd/rubric.md .sdd/features/<id>-<slug>/spec.md
```

**Step 6 — Edit `spec.md` header.** Replace the placeholder feature name with the user's intent. Set the `**Branch:**` line to `sdd/<id>-<slug>`. Set `[PHASE: SPEC]` and the `Active blocker` to `§1 Problem`.

**Step 7 — Update `.sdd/INDEX.md`:**
- `**Active:**` line → `features/<id>-<slug>   [SPEC]   blocker: §1 Problem`
- Add to `## In flight` list
- Remove from `## Backlog` if it was queued

**Step 8 — Commit the bootstrap.**
```bash
git add .sdd/INDEX.md .sdd/features/<id>-<slug>/
git commit -m "[SDD:<id>-<slug>] init: feature branch + spec scaffold"
```

**Step 9 — Confirm to the user, plain English:**
> Started feature `<id>-<slug>` on branch `sdd/<id>-<slug>`. First question coming up: §1 Problem — Who has it.

Then proceed with normal `/next` flow on the new feature (Step 2 of "What to do" above).

### If a hook blocks Step 8

The pre-commit-block hook will refuse Step 8's commit because the spec is full of `[ ]` markers (every section is unfilled at this point). To bypass it for the bootstrap commit only, set `**Active:**` to `_(none)_` temporarily in INDEX.md, commit, then immediately set it back and commit `[SDD:<id>-<slug>] index: activate`.

This dance is ugly. Captured for Round 3 — pre-commit-block should recognize bootstrap commits as a special case.
