---
id: extras
title: "Extras: 6 quick yes/no questions"
when: start
records_in: ".sdd/stack.md"
records_at: "## Extras"
agent_infers:
  - auth-provider
  - email-sender
  - payment-processor
  - error-tracker
  - analytics
  - ai-provider
---

# A few quick yes/no questions about the rest of your stack

Most prototypes don't need any of these on day one. But picking them up early means the agent never has to ask later, and your first feature's database structure (called the *data model* — the list of things your app keeps track of, like users, posts, payments) factors them in correctly. The agent walks **six separate yes/no questions** here — answer each one in turn. If you say yes, the agent asks a quick follow-up about which provider; if you say no, the agent moves on to the next question.

If you're not sure on any one, just say "not sure" and the agent will skip it for now. You can always add or change any of these later via `/sdd-config extras`.

---

## Question 1 of 6: will users need to sign in?

> *Examples: signup pages, login pages, "forgot password" emails, sessions that remember who you are, "your account" pages.*

Reply: **yes** / **no** / **not sure**

- **If yes:** the agent follows up with: *"Common login providers — Clerk (easiest, most-managed), Auth0 (most flexible, enterprise), Supabase Auth (cheapest if you're using Supabase Postgres), or describe your own. Which fits?"*
- **If no:** the agent records `Auth: none yet` and moves on.
- **If not sure:** the agent records `Auth: tbd` and asks again at the first feature that touches user accounts.

---

## Question 2 of 6: will the app send emails?

> *Examples: confirmation emails, password resets, weekly digests, transactional notifications, "reset your password" links.*

Reply: **yes** / **no** / **not sure**

- **If yes:** *"Common email providers — Resend (cheapest, easy to set up), Postmark (best at making sure emails actually land in the inbox, not spam), SendGrid (long-established, bigger company), AWS SES (cheapest if you send a lot, more setup work). Pick one or describe your own."*
- **If no / not sure:** record accordingly; ask later if a feature needs email.

---

## Question 3 of 6: will the app charge money?

> *Examples: paid subscriptions, one-time charges, in-app purchases, marketplace transactions.*

Reply: **yes** / **no** / **not sure**

- **If yes:** *"Almost everyone uses Stripe (most flexible; connects to the most other tools you might use). Alternatives: Paddle (handles tax filings for you — popular for subscription businesses), Lemon Squeezy (simplest if you're a solo developer). Pick one or describe your own."*
- **If no / not sure:** record accordingly.

---

## Question 4 of 6: should you know when something breaks in production?

> *Examples: a user gets an error page, a background job crashes, an API call fails. Without error tracking, you only find out when a user complains.*

Reply: **yes** / **no** / **not sure**

- **If yes:** *"Common error-tracking providers — Sentry (most popular; works with most development tools out of the box), Honeybadger (simpler, smaller), Rollbar (older, still solid). Pick one or describe your own."*
- **If no / not sure:** record accordingly. (For pre-launch prototypes this is often fine to skip.)

---

## Question 5 of 6: do you want to see how people use the app?

> *Examples: page views, button clicks, conversion funnels, "what's the most-used feature?", "where do users drop off?".*

Reply: **yes** / **no** / **not sure**

- **If yes:** *"Common analytics providers — Plausible (privacy-first, simple), PostHog (full product analytics + experiments), Mixpanel (deep funnels), Google Analytics (free but heaviest). Which fits?"*
- **If no / not sure:** record accordingly.

---

## Question 6 of 6: will the product itself use AI / an LLM at runtime?

> *Examples: a chatbot users talk to, a "summarise this" button, AI-generated content, a recommendation feed driven by an LLM. The key word is **at runtime** — i.e. real users in production trigger AI calls. If you're only using AI as a development tool (Claude Code, Cursor, etc.) the answer here is **no**.*

Reply: **yes** / **no** / **not sure**

- **If yes:** *"Common LLM providers — Anthropic (Claude family — strongest reasoning + 200K context window), OpenAI (GPT family — most ecosystems integrate first), Google (Gemini — cheapest at scale, very fast), Vercel AI Gateway (one API key in front of all of them — useful if you want to switch later), or self-hosted via Ollama (no per-call cost; you run the model on your own machine). Pick one, or describe your own."*
- **If no:** the agent records `AI: none in product runtime — dev-side only` and stops proposing AI features in later actions. **This is the right answer for products where AI is a dev tool, not a user-facing feature.**
- **If not sure:** record `AI: tbd` and re-ask at the first feature whose problem mentions chat / summary / generation / recommendation.

**Why this question matters:** without it, the agent might propose *"let's add an LLM-powered feature here!"* when you specifically don't want AI in your product. Capturing the stance up-front avoids that whole class of misaligned proposals.

---

## What the agent does after all 6 questions

For each question, records the answer + chosen provider (or "none yet" / "tbd" / "none in product runtime") in `.sdd/stack.md` under `## Extras`. The agent does NOT install or configure any of these in this step — that's a separate auto-walk install flow (#67). What this step captures is the CHOICE; the install walks happen later, gated on the choice.

## What gets recorded

```markdown
## Extras

- **Auth:** <provider, or "none yet" / "tbd">
- **Email:** <provider, or "none yet" / "tbd">
- **Payments:** <provider, or "none yet" / "tbd">
- **Error tracking:** <provider, or "none yet" / "tbd">
- **Analytics:** <provider, or "none yet" / "tbd">
- **AI / LLM in product:** <provider, or "none in product runtime — dev-side only" / "tbd">
- **Other:** <free-form notes if the user mentioned anything else>
```

## Why this is in the setup wizard at all

You could leave each of these for `/sdd-config` to ask later — and that's fine. The reason it's a start-of-project question is that the shape of your app changes depending on these choices: if you know you're using Stripe, the agent plans the database to track Users, Subscriptions, and Charges from feature 1. If you discover Stripe at feature 5, the database might need bigger changes (reorganising how data is stored is more work later than planning it correctly now).

If you said "tbd" to any question, the agent will re-ask at the first feature whose problem touches that area — e.g. the first feature that mentions "send confirmation email" will re-prompt question 2.
