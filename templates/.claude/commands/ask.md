---
description: Ask a chat-based AI questions about your project's `.sdd/` corpus (Tier 3). Renders answers with clickable wiki-link citations.
argument-hint: "<question about your project>"
---

# /ask — chat-based answers about your project (Tier 3)

Wraps the `synthesise()` MCP query with `format="prose"` for chat-rendered output. Asks a chat AI you've configured (Ollama+Gemma in v1.1; OpenAI/Anthropic via manual config edit) a question about your `.sdd/` corpus and renders the answer with clickable `[[…]]` citations.

## What this command does

When the user types `/ask "<question>"`:

1. Reads `parameters.mcp.tier3` from `.sdd/config.md`. If `enabled: false` (or the block is missing), respond *"Tier 3 not enabled — run `/sdd-config tier3` to set it up."*
2. Resolve the active feature via `.sdd/scripts/resolve-active.sh` to get the `slug` arg.
3. Call the `synthesise` MCP query with:

   ```json
   {
     "slug": "<active-feature-slug>",
     "question": "<user's question>",
     "format": "prose"
   }
   ```

4. The query runs the v1.1 Tier 3 flow: cache lookup → v1.0 retrieval → AI call → cite-check → cache write → prose render. See [[001-tier-3-llm-driven-synthesis]] for the full flow.
5. Render the response to chat:
   - On `ok: true`: print `result.answer` (markdown with inline `[[…]]` cites that the user can click in editors that render Obsidian-style links).
   - On `ok: false` with cite-check failure: print *"Couldn't generate a clean answer — the AI cited references that don't exist in your project. Showing the raw chunks the search found instead:"* + the `cite_chunks` content.
   - On other `ok: false` (provider unreachable, rate-limited, disabled, etc.): print the `reason` field in plain English with a suggested fix.

## Arguments

The user's natural-language question is the only argument. Multi-line questions wrapped in quotes are fine; the framework strips outer whitespace.

## Example

```text
> /ask "why did we pick Postgres for the waitlist?"

Postgres was picked because the v1 schema is small enough to colocate with
the app — you flagged this in [[001-waitlist]] §5 about a month ago. Switching
to a managed database came up later in [[005-pivot]] §3 but you parked it.
```

## Failure-mode messages (anti-theatre — concrete plain-English fixes)

| `reason` | Plain-English message + fix |
|---|---|
| `Tier 3 not enabled` | *"Tier 3 isn't set up yet. Run `/sdd-config tier3` to walk through the setup (Ollama + Gemma)."* |
| `provider unreachable: <detail>` | *"The AI provider isn't reachable. If you're using Ollama, run `ollama serve` in a terminal. Otherwise check your network or the endpoint in `config.md`."* |
| `rate-limited: <detail>` | *"Rate-limited by your provider. Wait a moment and try again — your cached answers from earlier still work."* |
| `cite-check failed: <slugs>` | *"The AI cited links that don't exist in your project: `[[<slug>]]`. Showing the raw chunks instead so you can answer it yourself."* + dump `cite_chunks` |
| `question invalid: <why>` | *"That question can't be processed: `<why>`. Try shorter / valid characters."* |
| `invalid slug: <slug>` | *"The active feature slug looks wrong (`<slug>`). Try `git checkout` to a clean SDD branch or run `/start` first."* |
| `<cap> exceeded` | *"Hit your `<cap>` limit. Adjust in `config.md` `parameters.mcp.tier3` or come back when the run-counter resets."* |

## Counters surfaced via `/status`

`/status` exposes the v1.1 Tier 3 counters from `synthesise.get_counters()`:

```yaml
Tier 3:
  Calls made:     <n>
  Tokens used:    <n>
  Cache hit rate: <pct>%
```

Useful when deciding whether to keep using a paid provider.

## Implementation note

This is a thin wrapper. All the real work happens in `synthesise.py`. If `/ask` ever needs richer behaviour (e.g. routing certain questions through a different format, rate-throttling per session), this file is the right surface; `synthesise.py` should stay agnostic to caller shape.
