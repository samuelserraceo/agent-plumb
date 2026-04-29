---
id: where-it-runs
title: "Where will it run when shipped?"
when: start
records_in: ".sdd/stack.md"
records_at: "## Running services"
agent_infers:
  - hosting-target
  - hosting-provider
  - env-var-shape
  - deploy-method
---

# Where will it run when shipped?

When the project is "live" — something other than your laptop — what's it
running on? Your answer shapes the deployment commands the agent recommends and
the environment variables it asks you to set up.

## Pick one (or describe your own)

1. **Just my laptop / not shipping yet** — prototype, exploration, internal
   demo. No public URL needed. (You can answer this again later when you're
   ready to ship.)
2. **A public website with a free / cheap option** — Vercel for the frontend,
   Railway for everything-in-one (frontend + Postgres in one place). Easy to
   set up; pay only when you grow.
3. **AWS / Google Cloud / Azure** — your team uses one of these already, or you
   need fine control over hosting. Higher complexity; more flexibility.
4. **Cloudflare Workers / edge** — you want it fast worldwide, ran close to
   users. Different shape (no long-running servers; everything is a
   short-lived function).
5. **A private server (your own VPS, Docker, or self-hosted)** — you have a
   server you control; the agent generates a Dockerfile + deploy notes.
6. **Not deciding yet** — skip; come back via `/sdd-config` once you've shipped
   the first feature locally.
7. **Something else** — describe it.

Reply with the number, or describe your own.

## What the agent does with your answer

| You said | Agent writes to stack.md `## Running services` |
|---|---|
| "Laptop / not shipping yet" | `Hosting: local only`. The agent skips deploy-related actions until this question is re-answered. |
| "Public website (Vercel / Railway)" | Picks Vercel if the project is mostly frontend, Railway if it's backend-heavy or needs Postgres in the same place. Records env-var examples. |
| "AWS / GCP / Azure" | Notes the cloud, asks a follow-up about which service (Lambda / EC2 / Cloud Run / ...) since they're each shaped differently. |
| "Cloudflare Workers" | Records the edge-functions shape; suggests `wrangler` as the deploy command. Notes that Workers can't run long-lived processes — agent will avoid suggesting them. |
| "Private server" | Adds a Dockerfile target to the project; deploy via `docker push` + ssh restart. |
| "Not deciding yet" | Skip; re-ask via `/sdd-config`. |

## What gets recorded

```markdown
## Running services

- **Hosting:** <choice>
- **Provider:** <if applicable>
- **Why:** <one-line reason in plain English>
- **Env vars:** _(filled in as you add infrastructure)_
- **Console link:** _(filled in once configured)_
- **Deploy command:** `<the actual command the agent will recommend>` (e.g.
  `vercel deploy` / `railway up` / `docker push && ssh ...`)
```
