# Stack

> **What this file is:** the canonical record of your project's tech stack — running services, providers, version pins, and architecture facts the AI must remember across sessions. The agent reads this on every session start so you never have to repeat "we're on Railway, not Vercel" or "we use pgBoss, not Trigger.dev".
>
> **Update when:** you add or remove a service, change a provider, pin a version, or make a stack-shaping architecture decision. Each `proposed-approach` action in SPEC includes a step that asks "any new dependency? update stack.md."
>
> **Format:** plain markdown. Edit by hand or via the agent.

---

## Running services

_(empty — fill in as you add infrastructure)_

<!-- Example shape:
- **Railway** — main app hosting + Postgres database
  - Env vars: `DATABASE_URL`, `REDIS_URL`
  - Console: https://railway.app/project/<id>
- **Vercel** — frontend deployment
  - Console: https://vercel.com/<team>/<project>
-->

## Providers

_(empty — fill in as you sign up for services)_

<!-- Example shape:
- **Clerk** — authentication
  - Env vars: `CLERK_SECRET_KEY`, `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
  - Console: https://dashboard.clerk.com
- **Resend** — transactional email
  - Env vars: `RESEND_API_KEY`
  - Console: https://resend.com
- **Neon Postgres** — primary database (via Railway addon)
  - Connection: `DATABASE_URL` env var
-->

## Pinned versions

_(empty — fill in as you commit to specific versions)_

<!-- Example shape:
- Node 20 (Railway runtime)
- Next.js 16.x
- pgBoss 9.x
- TypeScript 5.5
-->

## Architecture facts (the AI must remember)

_(empty — fill in as you make architectural commitments)_

<!-- Example shape:
- Background jobs run via **pgBoss** (NOT Trigger.dev or Inngest)
- Email auth uses **Clerk magic links** (NOT JWT tokens)
- File uploads stream through **Vercel Blob** (NOT S3)
- Cache layer is **Redis on Railway** (NOT in-memory)
-->

## Extras

_(empty — populated by `/sdd-setup` step 6 if you opt into auth / email / payments / error-tracking / analytics on day one)_

<!-- Example shape:
- **Auth:** Clerk
- **Email:** Resend
- **Payments:** Stripe
- **Error tracking:** Sentry
- **Analytics:** PostHog
- **Other:** —
-->

---

## Why this file exists

Without `stack.md`, the agent forgets across sessions:
- You sign up for Railway → next session it suggests Vercel
- You decide on pgBoss → next session it proposes Trigger.dev
- You set up Clerk → next session it asks "what auth provider?" again

The agent reads this file on every session start, alongside `INDEX.md` / `decisions.md` / `patterns.md` / `data-model.md` — **as documented in CLAUDE.md's "Your first move when you start a session" checklist** (step 2 in v0.10.1+). The mechanical wiring (UserPromptSubmit hook auto-injection) lands in v0.11 (issue #44); until then, the agent's session-start protocol covers it.

**Add a new event in `config.md`** (`stack_changed`) if you want to fire side-effects when stack.md is edited (e.g., update README, refresh deployment docs). Today the file is read-only-as-context — no automated triggers.
