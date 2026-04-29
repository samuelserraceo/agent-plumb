---
id: pr-reviewer
title: "Do you want a code reviewer bot?"
when: start
records_in: ".sdd/config.md"
records_at: "parameters.review"
agent_infers:
  - reviewer-bot
  - poll-interval
  - max-polls
---

# Do you want an automated code reviewer reading every PR?

Some bots read every change you push and post comments saying "this might break
in this case" or "this could be simpler." They catch issues before a human
reviewer (or the user) has to.

## Pick one (or describe your own)

1. **Yes — CodeRabbit (recommended)** — works smoothly with the SDD review
   convergence pattern (the framework documents how to handle CR's
   review-cycle output). Free for open-source repos, paid for private.
2. **Yes — GitHub's built-in Copilot review** — comes with most GitHub plans;
   simpler integration but lighter findings than CodeRabbit.
3. **Yes — something else** — Greptile, Qodo, custom bot. Describe it.
4. **No, just me reading the diff** — solo project, small changes. You'll review
   your own PRs by hand. (Fine for prototypes.)
5. **Not deciding yet** — the agent will skip this and ask again later via
   `/sdd-config`.

Reply with the number, or describe your own.

## What the agent does with your answer

| You said | Agent writes to config.md `parameters.review` |
|---|---|
| "Yes — CodeRabbit" | `bot: coderabbit`, `poll_interval: 60`, `max_polls: 30` (~30 min wait before nudging via `@coderabbitai review`). The agent also reminds the user to install the CodeRabbit GitHub app on the repo. |
| "Yes — Copilot review" | `bot: copilot`. Polling defaults are different (Copilot fires inline; no polling needed). |
| "Yes — something else" | `bot: <user's choice>` recorded verbatim; polling defaults left blank for the user to set. |
| "No" | `bot: none`, `manual: true`. Framework doesn't try to poll any bot. |
| "Not deciding yet" | Skip this question; nothing written. |

## What gets recorded

```yaml
# in .sdd/config.md frontmatter, under parameters:
review:
  bot: <choice>
  poll_interval: 60       # seconds between polls when waiting for review
  max_polls: 30           # ~30 min max wait before nudging
  manual: false           # true if user picked "no, just me"
```

## What this enables

The framework's `/ship` flow polls the chosen bot's review state and waits up
to `max_polls × poll_interval` seconds before either auto-merging (on clean
review) or pinging the bot. If `manual: true`, `/ship` skips the polling
entirely and waits for the user's `merge` confirmation.
