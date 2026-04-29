---
id: extras
title: "Extras: any other tools?"
when: start
records_in: ".sdd/stack.md"
records_at: "## Extras"
agent_infers:
  - auth-provider
  - email-sender
  - payment-processor
  - error-tracker
  - analytics
---

# Are there any other services you already use (or want to use)?

This question catches the things that don't fit cleanly into the other
categories: authentication, email-sending, payments, error tracking, analytics.
Most prototypes don't need any of these on day one. But if you already know
"we'll use Auth0 for login" or "Stripe for payments," capturing it now means
the agent never has to ask later.

## Pick all that apply (or describe your own)

1. **Login / authentication** — users sign in with email + password, Google,
   GitHub, etc. (Common providers: Clerk, Auth0, Supabase Auth, NextAuth.)
2. **Email sending** — confirmation emails, password resets, marketing.
   (Common providers: Resend, Postmark, SendGrid, AWS SES.)
3. **Payments** — credit cards, subscriptions, one-time charges. (Almost
   always Stripe; alternatives: Paddle, Lemon Squeezy.)
4. **Error tracking** — when something breaks in production, you find out about
   it. (Common: Sentry, Honeybadger, Rollbar.)
5. **Analytics** — page views, event tracking, conversion funnels. (Common:
   Plausible, PostHog, Mixpanel, Google Analytics.)
6. **None of these on day one** — keep it simple; we'll add as needed.
7. **Something else** — describe it.

Reply with all the numbers that apply (e.g. `1, 3, 5`), or describe in your own
words.

## What the agent does with your answer

For each item picked, the agent records the provider in `.sdd/stack.md` under
`## Extras`. If the user picked a category but didn't name a specific provider,
the agent asks a follow-up question with 3 typical options + free-form escape
("Common login providers are Clerk (easiest), Auth0 (most flexible), and
Supabase (cheapest if you're already using Supabase Postgres). Which fits?").

The agent does NOT install or configure any of these — it only records the
choice. The user installs / configures themselves; the agent reminds them
during the relevant feature's BUILD phase.

## What gets recorded

```markdown
## Extras

- **Auth:** <provider, or "none yet">
- **Email:** <provider, or "none yet">
- **Payments:** <provider, or "none yet">
- **Error tracking:** <provider, or "none yet">
- **Analytics:** <provider, or "none yet">
- **Other:** <free-form notes>
```

## Why this is in the setup wizard at all

You could leave this for `/sdd-config` to ask piecemeal later — and that's
fine. The reason it's a start-of-project question is that integration shapes
matter: if you know you're using Stripe, the agent factors it into the proposed
data model from feature 1. If you discover Stripe at feature 5, the data model
might need a bigger refactor.

If you're not sure yet, pick option 6 (`None of these on day one`) and the
agent will ask again at relevant moments (e.g. when a feature mentions
"payments" or "send the user an email").
