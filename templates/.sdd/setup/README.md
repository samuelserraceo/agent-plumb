# SDD setup questions — Lego library

This directory holds the **setup-question Lego bricks** the `/sdd-setup` wizard
walks through on first session, plus any additional questions you want re-asked
at sub-stages later via `/sdd-config`.

## Why this is a directory, not one big file

Per the foundation 2 (Lego) principle: each question is its own brick. Adding a
new question = adding one file. Removing a question = removing one file. The
wizard reads the directory and walks the bricks in numbered order. No monolithic
question list to keep in sync.

## Each question file

One Markdown file per question. Filename pattern: `<NNN>-<slug>.md` so they
sort naturally.

Frontmatter declares:

```yaml
---
id: <question-slug>            # short kebab-case identifier
title: "<short label>"         # 4-6 words
when: start | sub-stage        # 'start' = asked on first /sdd-setup;
                               # 'sub-stage' = only re-asked via /sdd-config
records_in: ".sdd/<file>"      # which file the answer lands in
records_at: "<heading or key>" # which section / YAML key
agent_infers: [<list>]         # what technical decisions the agent makes
                               # from the user's plain-English answer
---
```

Body is the **plain-English question** the agent asks. Per CLAUDE.md
non-technical-user-lens doctrine:

- The question itself uses no jargon. ("Where will this run?" not "What's your
  deployment target?")
- 3-5 typical options as a numbered list, with each option's plain-English
  consequence. ("Just my laptop — fine for prototypes." / "A public website —
  needs hosting like Vercel or Railway.")
- A "describe your own" free-form escape on every question.
- The agent's job is to take the user's answer and INFER the technical
  consequences (stack, dependency, config). The user never has to know "Next.js"
  or "Postgres" exists unless they want to.

## What the wizard does with each answer

1. Asks the question (renders the prose).
2. Waits for the user's reply (number + optional adjustment, OR free-form).
3. Translates the answer into a structured record using the `agent_infers`
   list.
4. **Drafts the record and shows the user the proposed diff** (per the
   AGENT-LED draft+approve pattern).
5. **Awaits user approval.** The wizard does NOT write the record to disk
   until the user confirms.
6. On approval, writes the record to the file/section declared in
   `records_in` / `records_at`.

## Re-running questions later

`/sdd-config` is the editor. It reads the same directory and lets the user pick
any question to re-answer. The file overwrite/skip/merge behaviour matches the
`/sdd-setup` re-run pattern.

## Adding a new question

1. Drop a new `<NNN>-<slug>.md` file in this directory.
2. Pick a number that fits the order you want it asked in.
3. Fill in the frontmatter + plain-English question body.
4. Done. The wizard picks it up automatically; no orchestrator code to edit.

This is the Lego shape — every new question is one brick, no scaffolding.
