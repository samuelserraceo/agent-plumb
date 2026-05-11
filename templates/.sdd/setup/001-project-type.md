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
  - future_saas
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
   spreadsheet replacement, or a dashboard. Stays internal — no plans to sell
   it as a product.
5. **An internal tool today, SaaS later** — same shape as option 4 for now
   (one customer = your team), but the architecture should be ready to grow
   into a multi-customer product later. Scope stays tight to one customer for
   the MVP; the agent flags multi-tenancy implications in the spec but doesn't
   force every feature to be SaaS-ready on day 1.
6. **A command-line tool** — the user runs it in their terminal.
7. **A script that runs on a schedule** — fires once a day / hour / etc., does
   one job, no UI.
8. **Something else** — describe it.

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
| "An internal tool" | Same as a website but with simpler hosting (Railway). Records `future_saas: false` so the agent skips multi-tenancy questions in feature specs. |
| "An internal tool today, SaaS later" | Same MVP shape as "internal tool" (one customer, simple hosting), but records `future_saas: true`. The agent then (a) flags multi-tenancy implications in each feature's spec at the proposed-approach step, (b) reminds you about SaaS-readiness checks at SHIP time, and (c) avoids architectural decisions that would be expensive to undo when externalising (e.g. hard-coded customer IDs, single-tenant URL shape). MVP scope stays tight to one customer — no premature SaaS-ification. |
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
- **future_saas:** <true | false>  <!-- true only if option 5 chosen -->
```

The `future_saas` flag is what downstream actions read when they need to
decide whether to ask about multi-tenancy. Most projects leave it `false`;
projects that picked option 5 ("internal tool today, SaaS later") have it
`true` so the agent remembers to flag SaaS-readiness implications in spec
work even though the MVP only serves one customer. {best-effort: agent}
