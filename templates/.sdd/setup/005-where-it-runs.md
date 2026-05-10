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
2. **Vercel** — best for frontend-heavy projects (Next.js, static sites).
   Pairs well with a separate database service. Free tier; pay only when you
   grow.
3. **Railway** — closest thing to "deploy a server, get a URL". Native cron
   jobs. Postgres + Redis live on the same dashboard, no extra signup.
4. **Fly.io** — global edge with persistent volumes (storage that survives
   restarts). Often the most cost-effective option for stateful apps that
   need to be near users.
5. **Render** — Heroku-shape simple deploys (push code, get a URL). Free tier
   with auto-sleep (the app pauses when idle to save cost).
6. **AWS / Google Cloud / Azure** — your team uses one of these already, or you
   need fine control over hosting. Higher complexity; more flexibility.
7. **Cloudflare Workers / edge** — you want it fast worldwide, run close to
   users. Different shape (no long-running servers; everything is a
   short-lived function).
8. **A private server (your own VPS, Docker, or self-hosted)** — you have a
   server you control; the agent generates a Dockerfile + deploy notes.
9. **Not deciding yet** — skip; come back via `/sdd-config` once you've shipped
   the first feature locally.
10. **Something else** — describe it.

Reply with the number, or describe your own.

## What the agent does with your answer

| You said | Agent writes to stack.md `## Running services` |
|---|---|
| "Laptop / not shipping yet" | `Hosting: local only`. The agent skips deploy-related actions until this question is re-answered. |
| "Vercel" | Records `vercel deploy` as the deploy command; assumes serverless or static shape (depending on framework); suggests pairing with a separate Postgres provider. |
| "Railway" | Records `railway up` as the deploy command; notes Postgres + Redis are available on the same dashboard; native cron supported. |
| "Fly.io" | Records `fly deploy` as the deploy command; flags persistent-volume support so stateful workloads are fine. |
| "Render" | Records the render.yaml deploy shape; notes the auto-sleep behaviour so the agent doesn't promise always-on responses on the free tier. |
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
