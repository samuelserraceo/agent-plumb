---
description: First-session setup wizard. Walks a non-technical user through 6 plain-English questions, fills in stack.md + reviewer preferences. Run once per project.
argument-hint: ""
---

# /sdd-setup

The first-session setup wizard. **Run this ONCE** when you bootstrap a fresh SDD project, before your first `/start`. Walks you through 6 questions in plain English, fills in `.sdd/stack.md` and adds reviewer preferences to `config.md`. Skips any question that's already answered.

## Why this exists (plain English)

The SDD framework needs to know a few project facts so the agent doesn't keep asking "what database are you using?" every session. This wizard captures those facts once. After it runs:

- `.sdd/stack.md` has your tech stack (services, providers, version pins)
- `.sdd/config.md` has your reviewer preferences (CodeRabbit, manual, none)
- The agent reads both on every session start

If you skip the wizard, the agent will ask each question piecemeal during your first `/start` — which works but is more tedious. The wizard is the polite version.

## Usage

```text
/sdd-setup
```

No arguments. The wizard runs interactively — you answer each question in plain English; the agent fills the files. You can `skip` any question and come back later by re-running `/sdd-setup`.

## What this command does

1. Detects whether the project is already set up. If `stack.md` has content beyond the placeholder, the agent reports "stack.md already has content — re-run to update individual entries, or just type `/start` to begin work" and asks if you want to proceed.

2. Walks the 6 questions below, one at a time. Each question is plain English with **3-5 typical options + a free-form escape**, per the AGENT-LED multi-choice pattern in CLAUDE.md.

3. After each answer, writes the relevant section to `stack.md` or `config.md` and **shows you the diff in plain English** before saving. You confirm or adjust.

4. At the end, prints a one-paragraph summary of what was captured and what to do next (`/start "<your first feature title>"`).

## The 6 questions

The agent asks each in this order. Each block tells the agent (a) the question, (b) typical options to offer, (c) where the answer goes in the framework files.

### Question 1 — Project shape

> "Is this a single feature you want to build, or a multi-feature project (3+ features)?"
>
> Common patterns:
> 1. **Single feature** — one thing, ship it. (Use the `feature` playbook by default.)
> 2. **Multi-feature project** — bigger initiative (a CRM, a dashboard, a whole new app). (Use the `project` playbook with `/start --playbook=project`.)
> 3. **Not sure yet** — I'll let the framework triage when I `/start`.
>
> Reply `1`, `2`, `3`, or describe your own.

If the user picks `2`, the agent suggests they run `/start --playbook=project "<title>"` after the wizard finishes. If `3`, the triage hook handles it on first `/start`.

This answer is informational only — nothing gets written to a file. It's a heads-up to the agent for the rest of the wizard.

### Question 2 — Programming language + framework

> "What language and framework? Pick one or describe your own."
>
> Common stacks:
> 1. **TypeScript + Next.js** (React, server-side rendering)
> 2. **TypeScript + Vite + React** (single-page app)
> 3. **Python + Django** (server-rendered, admin out-of-the-box)
> 4. **Python + FastAPI** (API-first, pair with a frontend)
> 5. **Go + standard library** (small services, no framework)
> 6. **Plain HTML + a tiny JS library** (no build step)
>
> Reply `1`–`6`, or describe your own.

Agent writes the answer to `.sdd/stack.md` under a new `## Languages + frameworks` heading. Format:

```markdown
## Languages + frameworks

- **<language>** — <framework if any>
- Why: <user's reason or "default for this project type">
```

### Question 3 — Test runner

> "What test framework? This is what runs your automated tests."
>
> Common choices:
> 1. **Playwright** — full-browser end-to-end tests (recommended for web apps with UI)
> 2. **Vitest** — fast unit tests for JS/TS projects
> 3. **Jest** — older but widely used JS unit-test framework
> 4. **pytest** — Python's standard test runner
> 5. **Go's built-in `testing`** — no extra install
> 6. **None yet — pick later**
>
> Reply `1`–`6`, or describe your own.

Agent writes to `.sdd/stack.md`:

```markdown
## Testing

- **Test runner:** <choice>
- **Test file pattern:** <derived from runner choice — e.g. `*.spec.ts` for Vitest/Playwright, `test_*.py` for pytest>
- Why: <reason>
```

If user picks `1` (Playwright), agent says: *"There's an opt-in `extensions/playwright/` Lego brick that scaffolds a sample test pattern + mobile viewport config. Run `bash extensions/playwright/enable.sh` after the wizard finishes to install it."*

### Question 4 — Deployment target

> "Where will this run when shipped?"
>
> Common targets:
> 1. **Vercel** — frontend / Next.js app
> 2. **Railway** — backend + Postgres on one platform
> 3. **AWS** (Lambda / EC2 / S3 / etc.)
> 4. **Cloudflare Workers** — edge functions
> 5. **Self-hosted** (your own VPS / Docker)
> 6. **Not deciding yet**
>
> Reply `1`–`6`, or describe your own.

Agent writes to `.sdd/stack.md`:

```markdown
## Running services

- **Hosting:** <choice>
- **Why:** <reason>
- **Env vars:** _(empty — fill in as you add infrastructure)_
- **Console link:** _(empty)_
```

### Question 5 — Data store

> "Where does the app's data live?"
>
> Common stores:
> 1. **Postgres** — relational, full-featured (Neon, Supabase, Railway Postgres, RDS)
> 2. **SQLite** — file-based, zero-setup, fine for small projects
> 3. **No database yet** — the app is read-only / static
> 4. **Something else** (Mongo, DynamoDB, a JSON file, …)
>
> Reply `1`–`4`, or describe your own.

Agent writes to `.sdd/stack.md`:

```markdown
## Data store

- **Type:** <choice>
- **Provider:** <if applicable, e.g. Neon, Supabase>
- **Schema source:** `.sdd/data-model.md` (the framework's single source of truth)
```

### Question 6 — Reviewer / CI bot

> "Do you want automated code review on every PR? CodeRabbit reads the diff and posts findings; you decide which to fix. Or pick another tool."
>
> Common choices:
> 1. **CodeRabbit** (recommended — works with the convergence pattern documented in CLAUDE.md)
> 2. **GitHub Copilot review** (built-in to PRs)
> 3. **Manual review only** (human reviewer, no bot)
> 4. **None yet** (solo project, defer)
>
> Reply `1`–`4`, or describe your own.

Agent writes to `.sdd/config.md` under `parameters:`:

```yaml
review:
  bot: <choice>
  poll_interval: 60       # seconds between polls when waiting for review
  max_polls: 30           # ~30 min max wait before nudging
```

If user picks `1` (CodeRabbit), agent reminds them: *"CodeRabbit needs a one-line setup in your repo's settings — add the CodeRabbit GitHub app + grant it read/write on the repo. Once that's done, every PR gets reviewed automatically."*

If user picks `2` or `3`, agent skips the polling defaults (they're CodeRabbit-specific).

## After the 6 questions

The agent prints a summary box:

```text
✅ Setup complete.

  Stack:    <language + framework>
  Tests:    <runner>
  Hosting:  <target>
  Data:     <store>
  Reviewer: <bot or none>

Files written:
  - .sdd/stack.md
  - .sdd/config.md (review block)

Next: type
  /start "<one-line title for what you want to build first>"

If you said "multi-feature project" in question 1, run:
  /start --playbook=project "<your project title>"
```

## Re-running the wizard

You can run `/sdd-setup` any time. It detects existing entries in `stack.md` and `config.md` and asks: *"Question N already has an answer (`<existing>`). Skip / overwrite / merge?"*

- **Skip** — leave the existing answer alone.
- **Overwrite** — replace with the new answer.
- **Merge** — append the new info as a sub-bullet (useful for multi-stack projects).

## Plain-English principle (CLAUDE.md doctrine rule 8)

Every option above translates jargon on first use. "Vercel" gets a one-line description ("frontend / Next.js app hosting"). "Playwright" gets one ("full-browser end-to-end tests"). The wizard never assumes the user knows what an "ORM" or a "CDN" is. If the user picks an option, the agent fills the file with the user-friendly label, and adds the technical name in parentheses for future-agent reference.

## What this command does NOT do

- It does NOT install dependencies (`npm install`, `pip install`, etc.). The agent suggests the install command at the end of the wizard but does not run it — you control when and where dependencies install.
- It does NOT create a git repo or push anywhere. The bootstrap script (`sdd-init.sh`) handled the repo setup; this wizard is purely about preferences.
- It does NOT scaffold the first feature. After the wizard, you type `/start "<title>"` to begin actual work.
- It does NOT touch the manifest. Nothing in `templates/.sdd/` is modified — the wizard writes to project-level files (`.sdd/stack.md`, `.sdd/config.md`) which are the user's, not framework-shipped.

---

**End the turn with:** `Reply 1, 2, 3 (etc.) to question 1, or describe your own.`
