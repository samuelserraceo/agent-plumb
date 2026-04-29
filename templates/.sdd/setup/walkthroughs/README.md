# /sdd-setup install walkthroughs

When the user picks a third-party tool during /sdd-setup (CodeRabbit, Resend, Sentry, Stripe, etc.), the wizard records the choice but until v0.13.x didn't actually walk the user through the install. The user had to know to do it themselves.

This directory holds **install walkthroughs** — one file per provider — that the wizard reads when a tool is picked. Each walkthrough is a structured doc the agent walks the user through, step by step, in plain English.

## Walkthrough file shape

Every walkthrough at `walkthroughs/<provider>.md` has this structure:

```yaml
---
provider: coderabbit               # the slug the wizard uses to find this file
display_name: CodeRabbit           # what the agent calls it when talking to the user
category: pr-reviewer              # which question the user got here from
records_in: ".sdd/config.md"       # already-recorded location of the choice
records_at: "parameters.review.bot"
---

# Install walkthrough body — plain English, step by step.
```

The body has three parts:

1. **What this provider does** — one short paragraph the agent can read aloud if the user wants context before installing.
2. **Steps to install** — numbered list of imperatives. Each step ends with "I'll wait — reply `done` when you've finished" or similar verifiable handoff.
3. **Verification** — a check the agent runs after the user says `done`, to confirm the install actually worked. If verification fails, the agent says what's wrong and offers to retry.

## Why this lives in `setup/walkthroughs/` and not in the brick file itself

Foundation 2 (Lego). The brick file (e.g. `003-pr-reviewer.md`) is the QUESTION; the walkthrough file is the INSTALL. Different concerns, different files. A future user who picks CodeRabbit AND Sentry AND Stripe walks three separate walkthroughs, not one giant brick.

The wizard auto-discovers walkthroughs by `provider:` slug — drop a new file in `walkthroughs/`, and any brick that records that provider as the user's choice will pick it up.

## Currently shipped walkthroughs

- `coderabbit.md` — CodeRabbit GitHub-app install (OAuth flow)

Future PRs add: `sourcery.md`, `resend.md`, `postmark.md`, `sentry.md`, `honeybadger.md`, `stripe.md`, `paddle.md`, `clerk.md`, `auth0.md`, `supabase-auth.md`, `plausible.md`, `posthog.md`. Each is its own focused file; the wizard auto-loads.

## What if the user doesn't want the walkthrough?

Every walkthrough invocation is **opt-in via a yes/no prompt** at the start. The user can say "skip — I'll install it myself later" and the wizard moves on. The choice is still recorded in config.md / stack.md; only the install walk is deferred.

The wizard re-asks at the next /sdd-config or first feature that depends on the provider being installed (e.g. the first feature that mentions sending email re-prompts the Resend install if it hasn't happened yet).
