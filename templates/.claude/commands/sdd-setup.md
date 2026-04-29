---
description: First-session setup wizard. Walks the user through the plain-English questions in .sdd/setup/ and fills the right files. Run once per project; re-run any time to update individual answers.
argument-hint: ""
---

# /sdd-setup

The first-session setup wizard. **Run this ONCE** when you bootstrap a fresh
SDD project, before your first `/start`. It walks you through a small number
of plain-English questions, infers the technical stack from your answers, and
fills the right files. After it's done, the agent never has to ask "what
database again?" or "what's the test runner?" — it's all recorded.

## How this is shaped (Lego)

Each question is its own file in `.sdd/setup/`. The wizard reads that
directory, walks the questions in numbered order (`001-*.md`, `002-*.md`,
…), and for each one:

1. Asks the **plain-English question** from the file's body.
2. Waits for your reply.
3. Translates your answer into a structured record using the file's
   `agent_infers` list (the technical decisions the agent makes for you).
4. Shows you the record before writing — you can adjust before save.
5. Writes the record to the file/section declared in `records_in` /
   `records_at`.

If you want to add a new question, drop a new file in `.sdd/setup/`. If you
want to remove one, delete the file. The wizard auto-discovers the brick set;
no orchestrator code to edit.

## Usage

```text
/sdd-setup
```

No arguments. The wizard runs interactively. You can `skip` any question and
come back later via `/sdd-config`.

## What this command does

1. **Reads `.sdd/setup/`** in alphanumeric order.
2. For each question file with `when: start` in its frontmatter:
   - Renders the body as the question to ask the user.
   - Awaits the answer (number + optional adjustment, OR free-form).
   - Translates the answer to a record per the file's `agent_infers` list.
   - Shows the user the proposed record (e.g. *"I'll write this to stack.md
     under `## Project shape`: Type: a website. Stack: TypeScript + Next.js.
     Why: most common shape for this kind of work."*).
   - Awaits confirmation (`approve` / adjust / skip).
   - Writes to the declared file + section on approval.
3. Skips questions with `when: sub-stage` — those are only re-asked via
   `/sdd-config` later.
4. After all start-questions are answered, prints a one-paragraph summary +
   the suggested next command (`/start "<title>"`).

## What this command does NOT do

- Does NOT install dependencies (`npm install`, `pip install`, etc.). The
  wizard suggests the install command at the end; you run it.
- Does NOT scaffold the first feature. After the wizard, you type
  `/start "<title>"` to begin actual work.
- Does NOT touch the framework templates. Nothing in `templates/.sdd/` is
  modified — the wizard writes to project-level files (`.sdd/stack.md`,
  `.sdd/config.md`, `.sdd/data-model.md`).
- Does NOT decide for the user. Per foundation 3 (never assume), the wizard
  always shows the proposed record before writing. The user can adjust or
  override anything.

## Re-running the wizard

You can re-run `/sdd-setup` any time. For each question, if the answer is
already in place, the wizard offers:

- **Skip** — leave the existing answer alone.
- **Overwrite** — replace with a new answer.
- **Merge** — add the new info as a sub-bullet (useful for multi-stack
  projects, e.g. one app + one CLI).

For editing one specific question without walking the whole list, use
`/sdd-config <question-id>` instead.

## Plain-English principle (CLAUDE.md doctrine rule 8)

Every question file uses **plain English with multi-choice + free-form
escape**, per the CLAUDE.md non-technical-user-lens doctrine:

- Questions never use technical jargon as the question itself ("Where will it
  run?" not "What's your deployment target?").
- Each option is described by what it DOES for the user, not what it IS
  ("anyone can visit it in a browser" not "client-side rendered web app").
- Every question ends with "describe your own" so locked-in choices feel like
  conversation, not a survey.

## Adding a new question to the wizard

Drop a new `<NNN>-<slug>.md` file in `.sdd/setup/`. See `.sdd/setup/README.md`
for the file shape (frontmatter + body). The wizard picks up the new question
automatically on next run; no edit to this slash command needed.

---

**End the turn with:** `Reply with the number for the first question, or describe in your own words.`
