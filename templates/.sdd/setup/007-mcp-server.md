---
id: mcp-server
title: "Save tokens (and money) as the project grows?"
when: start
records_in: ".sdd/config.md"
records_at: "parameters.mcp.enabled"
agent_infers:
  - mcp-enabled
  - mcp-installed
---

# Want the agent to read your project state efficiently?

The framework keeps notes about your project in a few markdown files: a list of features, decisions you've made, patterns the agent has noticed, etc. The agent reads these files at the start of every session so it never forgets what you decided last time.

After 3-6 months of work, those notes can grow large — sometimes hundreds of kilobytes. Reading them all at every session is expensive (it costs tokens, which means real money for paid Claude usage). Most of the time the agent only needs ONE specific note, not the whole file.

The **SDD MCP server** is a small extension that lets the agent fetch one note at a time instead of reading whole files. Think of it as giving the agent an index card system instead of making it re-read the whole binder every morning.

## Pick one (or describe your own)

1. **Yes — turn it on** *(recommended)* — the agent installs the small extension into your project. No external service, no extra subscription. Saves an estimated 40-60% on tokens once the project has been running a few months. Worth it for almost every project.
2. **No — I'll read whole files** — for very small projects (under a month old, under 30 features) the saving is small. The notes file is still tiny; reading it whole is fine.
3. **Tell me more** — agent explains the trade in plain English before you decide.

Reply with the number, or describe your own.

## What the agent does with your answer

| You said | Agent action |
|---|---|
| "Yes — turn it on" | Runs `bash extensions/sdd-mcp-server/enable.sh` automatically. The script registers the server with Claude Code (creates `.mcp.json` in this project, or updates `~/.claude.json` if `SDD_MCP_TARGET=user` is set). Verifies the registration. Records `parameters.mcp.enabled: true` in `.sdd/config.md`. |
| "No" | Records `parameters.mcp.enabled: false`. You can re-enable any time via `/sdd-config mcp-server`. |
| "Tell me more" | Agent reads the explanation block below to you in plain English, then re-asks. |

## Tell me more (the long version)

Without the MCP server: every Claude Code session starts by reading the full `.sdd/INDEX.md`, `.sdd/decisions.md`, `.sdd/patterns.md`, and `.sdd/data-model.md`. Even if the agent only needs ONE recent decision, it reads the whole file. After 6 months of project work, those files can total 400 KB — about 100,000 tokens just to "load" your project context.

With the MCP server: the agent makes targeted queries (six of them ship out of the box). For example:

- *"What's the active step in the active feature?"* → ~200 bytes
- *"Show me the pattern named auth-retry-logic"* → ~500 bytes
- *"List all decisions since 2026-04-25"* → ~1 KB

So instead of reading 100,000 tokens of file every session, the agent reads exactly what it needs — typically 5,000-10,000 tokens. **40-60% saving** on token cost, which translates directly to your Claude bill on a paid plan.

The saving GROWS over time: a 1-month-old project sees small savings; a 6-month project sees big savings; a 12-month project sees huge savings.

The MCP server is local Python code; no external service, no extra subscription. It runs as a sub-process whenever Claude Code is talking to your project.

**Read more:** the full server design, query reference, and how to enable optional semantic search live in the [MCP server README](../../../extensions/sdd-mcp-server/README.md).

## What gets recorded

```yaml
# in .sdd/config.md frontmatter, under parameters:
mcp:
  enabled: <true | false>
```

If enabled, `.mcp.json` (or `~/.claude.json`) also gets a registration entry pointing at `extensions/sdd-mcp-server/server.py`. The wizard verifies this entry exists before declaring success.

## What this enables (if you said yes)

The agent's per-session token cost stops scaling with the SIZE of your project notes. Whatever the project's vintage, the agent reads only what each turn needs — not the whole file. Older projects benefit most.

If install fails (network, permissions, missing Python), the wizard reports the error in plain English and falls back to recording `enabled: false` with a follow-up reminder for `/sdd-config mcp-server` once the issue is resolved.
