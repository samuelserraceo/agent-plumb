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
| "Yes — CodeRabbit" | `bot: coderabbit`, `poll_interval: 180`, `max_polls: 5` (15 min total wait — matches the project's review-discipline pattern of polling every 3 min and nudging via `@coderabbitai full review` after ~5 min if quiet). Then agent walks the user through the **CodeRabbit install walkthrough** at `.sdd/setup/walkthroughs/coderabbit.md` — opens browser to `coderabbit.ai/integrations/github`, walks the install steps in plain English, verifies via `gh api`, and optionally seeds `.coderabbit.yaml` config. (Closes #67.) |
| "Yes — Copilot review" | `bot: copilot`. Polling defaults left at `poll_interval: 60`, `max_polls: 5` (Copilot review is faster; if it hasn't fired in ~5 min, something's wrong). Walkthrough TBD — for now agent prints manual install instructions. |
| "Yes — something else" | `bot: <user's choice>` recorded verbatim; polling defaults left blank for the user to set. Agent looks for a matching walkthrough at `.sdd/setup/walkthroughs/<choice>.md` and runs it if present; otherwise prints generic "install the bot yourself, then continue" instructions. |
| "No" | `bot: none`, `manual: true`. Framework doesn't try to poll any bot. |
| "Not deciding yet" | Skip this question; nothing written. |

**Skip-walkthrough escape:** every walkthrough invocation starts with a yes/no prompt. The user can say `skip walkthrough` and the wizard moves on — the bot choice is still recorded in config.md, but with `pending_install: true` so the framework re-prompts at the first `/ship` or `/sdd-config pr-reviewer`.

## What gets recorded

```yaml
# in .sdd/config.md frontmatter, under parameters:
review:
  bot: <choice>
  poll_interval: 180      # seconds between polls (3 min cadence for CodeRabbit)
  max_polls: 5            # ~15 min before nudging the bot for a fresh full review
  nudge_command: "@coderabbitai full review"   # what /ship posts when polls run out
  manual: false           # true if user picked "no, just me"
```

The `nudge_command` field captures the explicit phrasing the framework's `/ship` flow uses when it asks the bot for a fresh review. CodeRabbit's documented pattern (per the project's review-discipline notes) is `@coderabbitai full review` — that's the default written above. For other bots, the agent fills in their equivalent.

## What this enables

The framework's `/ship` flow polls the chosen bot's review state and waits up
to `max_polls × poll_interval` seconds before either auto-merging (on clean
review) or pinging the bot. If `manual: true`, `/ship` skips the polling
entirely and waits for the user's `merge` confirmation.
