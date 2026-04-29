---
id: project-type
title: "What are you building?"
when: start
records_in: ".sdd/stack.md"
records_at: "## Project shape"
agent_infers:
  - language
  - framework
  - typical-test-runner
  - typical-deploy-target
---

# What are you building?

The most basic question — what kind of thing is this? The agent uses your answer
to suggest a sensible technical stack. You never have to know the names of the
tools.

## Pick one (or describe your own)

1. **A website** — anyone can visit it in a browser. Sign up, log in, click
   buttons, see content. (Most projects start here.)
2. **A phone app** — runs on iPhone or Android, downloaded from an app store.
3. **A backend service** — no UI, other software talks to it (an API).
4. **An internal tool** — only your team uses it. Could be a small website, a
   spreadsheet replacement, or a dashboard.
5. **A command-line tool** — the user runs it in their terminal.
6. **A script that runs on a schedule** — fires once a day / hour / etc., does
   one job, no UI.
7. **Something else** — describe it.

Reply with the number, or describe your own.

## What the agent does with your answer

The agent picks a sensible default stack based on your answer and writes it to
`.sdd/stack.md` under the `## Project shape` heading. You never have to pick
between "TypeScript + Next.js" and "Python + Django" yourself — the agent does.

Some examples of what the agent infers:

| You said | Agent writes to stack.md |
|---|---|
| "A website" | TypeScript + Next.js (most common shape; React for the UI; Vercel for hosting). Suggests Playwright for browser tests. |
| "A phone app" | Suggests React Native (cross-platform) by default; asks if you'd rather native iOS / Android. |
| "A backend service" | Python + FastAPI for ergonomics, OR Go + standard library for performance. Asks which fits. |
| "An internal tool" | Same as a website but with simpler hosting (Railway). |
| "A CLI" | Python with argparse (smallest dep tree) or Go (single binary). Asks which fits. |
| "A scheduled script" | Same as CLI; suggests a cron-job extension if shipping. |

If the user's answer doesn't map to one of these, the agent asks a follow-up in
plain English ("can you describe what it does in one sentence?") and proposes a
stack from that. Per foundation 3 (never assume), the agent ALWAYS shows its
proposed stack before writing — the user can override before save.

## What gets recorded

```markdown
## Project shape

- **Type:** <user's answer in their own words>
- **Stack chosen by the agent:** <language + framework>
- **Why:** <one-line reason — the agent's inference, written as the user could
  read it>
```
