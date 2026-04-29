---
id: data-needs
title: "Does the app need to remember things?"
when: start
records_in: ".sdd/stack.md"
records_at: "## Data store"
agent_infers:
  - data-store-type
  - data-store-provider
  - schema-source
---

# Does the app need to remember things between visits?

Some apps just show information (a static website, a calculator). Some apps
remember stuff for next time (signups, posts, orders, settings). This question
decides whether you need a database.

## Pick one (or describe your own)

1. **No, nothing to remember** — the app shows the same content every visit. No
   user accounts, no saved data. (Marketing site, calculator, doc viewer.)
2. **Yes, a small amount** — just for me / a small team. Something like a
   spreadsheet with maybe a few hundred rows, max.
3. **Yes, accounts and content from many users** — signups, posts, orders. Real
   product data that grows over time.
4. **Files / images / documents** — uploads, photos, attachments. (Different
   shape from a database; the agent will plan accordingly.)
5. **Real-time data** — chat messages, live cursors, presence. (Different shape
   again; the agent will note the requirement.)
6. **Something else** — describe it.

Reply with the number, or describe your own.

## What the agent does with your answer

For every answer the agent writes the same shape (`Type / Provider / Schema source / Why`) so the wizard's output is always parseable. The mapping table below shows the values the agent picks for each common answer:

| You said | Type | Provider | Why (short) |
|---|---|---|---|
| "Nothing to remember" | `none` | — | static / stateless app |
| "A small amount, just me/team" | `SQLite` | local file | zero setup; fine for under ~10k rows |
| "Accounts + content from many users" | `Postgres` | Neon (dev), Supabase or Railway (prod) | relational, scales, supports real apps |
| "Files / images / documents" | `Blob store` | S3 / R2 / Supabase Storage | object storage shape |
| "Real-time data" | `Real-time` | Supabase Realtime / Pusher | live cursor / chat / presence |

For the `Postgres` answer specifically, the agent ALSO seeds starter headings in `.sdd/data-model.md` so feature 1 has a place to land its first entities.

Per foundation 3 (never assume), the agent ALWAYS shows the proposed record
before writing. If the user has a strong preference (e.g. "I want Postgres
specifically"), they can override at draft time.

## What gets recorded

```markdown
## Data store

- **Type:** <store type — none / Postgres / SQLite / blob / real-time / other>
- **Provider:** <provider, if applicable>
- **Schema source:** `.sdd/data-model.md` (the framework's single source of
  truth for entities and fields)
- **Why:** <one-line reason in plain English>
```
