---
description: Re-answer or edit a single setup question without re-running the whole /sdd-setup wizard. Use this when you change your mind, add a service, or want to update one piece of the stack.
argument-hint: "[<question-id>]"
---

# /sdd-config

The targeted editor for setup answers. Where `/sdd-setup` walks the entire list
in order, `/sdd-config` lets you re-answer ONE question — or pick from a menu
of all configurable items.

## Usage

```text
/sdd-config                # show menu of all configurable questions
/sdd-config pr-reviewer    # jump straight to the pr-reviewer question
/sdd-config data-needs     # jump straight to the data-needs question
```

## Why this exists

Two reasons:

1. **You change your mind.** Day 1 you said "no PR reviewer." Day 30 you've
   added two collaborators and want CodeRabbit. `/sdd-config pr-reviewer` walks
   that question only and updates `.sdd/config.md`.
2. **Sub-stage questions.** Some setup questions are tagged `when: sub-stage`
   in their frontmatter — they're only relevant after the project has shipped a
   first feature. `/sdd-config` is where you answer those when the time comes.

## What this command does

### With no argument

1. Reads `.sdd/setup/` in alphanumeric order.
2. For each question file, prints:
   - The question's title (from frontmatter)
   - The current answer recorded (parsed from `records_in` + `records_at`)
   - A short label: `[set]` if answered, `[unset]` if blank, `[sub-stage]` if
     the question is `when: sub-stage` and hasn't been asked yet
3. Asks: "which one to edit?"
4. User replies with the question's `id` (e.g. `pr-reviewer`) or its number in
   the menu.
5. Walks that single question, same shape as `/sdd-setup` (ask → propose → user
   approves → write).

### With an argument

`/sdd-config pr-reviewer` skips the menu and goes straight to that question.
The argument matches the question's `id` in frontmatter.

## What gets edited

The same file/section the question's `records_in` / `records_at` declare. The
wizard offers:

- **Overwrite** — replace the existing answer entirely.
- **Merge** — add the new info as a sub-bullet (useful for "we now also use X
  alongside Y").
- **Cancel** — leave the existing answer alone.

For files that are append-only (`.sdd/decisions.md`), the wizard appends a
new entry rather than overwriting; the old answer stays in the audit trail.

## What this command does NOT do

- Does NOT install or uninstall any service. If you change `pr-reviewer` from
  `none` to `coderabbit`, the wizard reminds you to install the CodeRabbit
  GitHub app. You install; the wizard records.
- Does NOT migrate existing data when you change `data-needs`. If you go from
  SQLite to Postgres, you have to migrate yourself; the wizard updates the
  recorded choice.
- Does NOT auto-update existing features. If you change the test runner from
  Vitest to Playwright after shipping 3 features, those 3 features keep their
  existing tests; only NEW features use the new runner. The agent will mention
  this trade-off when you confirm.

## Subcommand: `automation <tier>` (F011)

In addition to the per-question editor above, `/sdd-config` accepts a small
literal subcommand for the F011 automation level — the parameter that controls
how aggressively the framework auto-advances AGENT-LED steps.

Usage:

```text
/sdd-config automation full        # auto-advance every AGENT-LED step where
                                   # the action says it doesn't need approval
/sdd-config automation most        # auto-advance most steps, but STILL prompt
                                   # on destructive actions (mark-shipped,
                                   # manifest repins, --delete-branch,
                                   # decisions.md edits, .shipped writes)
/sdd-config automation checkpoint  # today's behaviour — prompt on every
                                   # AGENT-LED step (default for new projects)
```

The subcommand parses the tier name (`full` / `most` / `checkpoint`,
case-insensitive — `Full`, `Most`, `Checkpoint` all accepted), validates it,
and writes the chosen value to `parameters.automation.level` in
`.sdd/config.md`. Invalid tiers (`fast`, `auto`, `yolo`, etc.) are refused
with a plain-English error listing the three valid choices.

After writing, the agent confirms back: which tier was picked, what changes
about its behaviour, and how to switch again. No restart needed — the next
`/next` invocation reads the new value.

**What it looks like:**

> *Sam:* `/sdd-config automation most`
> *Agent:* "OK — `parameters.automation.level` is now `most` in
> `.sdd/config.md`. From here, AGENT-LED steps that don't touch destructive
> actions auto-advance without asking; mark-shipped, manifest repins,
> branch deletions, and `decisions.md` edits still prompt for approval.
> Switch again anytime with `/sdd-config automation <full|most|checkpoint>`."

## Adding a new question (Lego)

Same as `/sdd-setup` — drop a `<NNN>-<slug>.md` file in `.sdd/setup/`. Both
wizards pick it up automatically.

---

**End the turn with:** `Reply with the question id, or its menu number.`
