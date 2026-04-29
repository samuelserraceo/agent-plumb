# SDD MCP Server

A small Python program that lets Claude Code ask questions about your SDD project (the `.sdd/` folder) instead of opening files one by one.

## What it does

When you're working in a SDD project, the agent constantly needs to know things like *"what's the active feature's current step?"* or *"is there already a pattern for auth retries?"*. Today, answering those questions means the agent reads `INDEX.md` (a few KB), then reads the active spec.md (10–30 KB), then scans for the right line — three file reads, ~15–35 KB into the context window, every time it asks one question.

This server changes that. It runs as a local helper that Claude Code talks to through a small set of named queries (`get_active_step`, `get_pattern`, etc.). Claude makes one short call, the server does the file walking on its own, and Claude gets back a tiny answer (~200 bytes for most queries).

The point isn't speed — it's context. The agent's working memory is finite. Every byte spent re-reading INDEX.md is a byte you don't have for the actual feature work.

## Why it exists (the math)

Old way (per question): three file reads → 15–35 KB of context.

New way (per question): one query → ~200 B of context.

That's ~99% less context per question. Across a working session, the documented saving is 40–60% of the per-session token budget — money + room for longer conversations + faster turns.

The trade is: you have to enable the server once. After that it just runs.

## How to enable it

From this folder, run:

```bash
./enable.sh
```

That registers the server in `.mcp.json` at the current project root. If `.mcp.json` already exists and you have `jq` installed, the script merges the SDD entry into it; otherwise it prints the JSON snippet for you to paste manually. Then **restart Claude Code** and the queries become available as MCP tools.

If you prefer a per-user (not per-project) registration:

```bash
SDD_MCP_TARGET=user ./enable.sh
```

That writes to `~/.claude.json` instead.

### Manual install (if `enable.sh` doesn't fit your setup)

Add this snippet to `.mcp.json` in your project root (or `~/.claude.json` for user-global):

```json
{
  "mcpServers": {
    "sdd": {
      "type": "stdio",
      "command": "python3",
      "args": ["/absolute/path/to/extensions/sdd-mcp-server/server.py"]
    }
  }
}
```

Replace the path with where you cloned this repo. Restart Claude Code.

## The 6 queries

| Query | What it answers |
|---|---|
| `get_active_step` | What's the next open step in the active feature? |
| `get_by_tag` | Which features are in-flight / shipped / backlog / blocked? |
| `get_pattern` | Show me the `<slug>` pattern from patterns.md. |
| `get_references` | Who else mentions this feature/action/playbook? |
| `get_decisions_since` | What was decided after this date? |
| `search` | Semantic search over `.sdd/` (opt-in — see below). |

Detailed shapes, sample requests, and sample responses live in [`docs/query-reference.md`](docs/query-reference.md).

## Opt-in: semantic search

The `search` query is a stub by default — it returns a friendly message explaining what to add to your config. To turn it on, add a block to `.sdd/config.md`'s YAML frontmatter:

```yaml
parameters:
  mcp:
    semantic_search:
      enabled: true
      provider: ollama          # or anthropic / openai / local-gemma / ...
      endpoint: http://localhost:11434
      model: nomic-embed-text
      top_k: 5
```

The framework deliberately doesn't bake in a default provider — per the SDD doctrine in `CLAUDE.md`, every external dependency must be an explicit choice.

The actual embedding call is deferred to a follow-up commit. Today, even with `enabled: true`, the query returns a "configured but not implemented" message that echoes back your provider settings so you can verify the shape.

## Protocol

The server speaks two flavours of JSON over stdio on the same socket:

1. **Minimal MCP** (JSON-RPC 2.0): `initialize`, `tools/list`, `tools/call`. This is what Claude Code uses.
2. **Simplified SDD**: `{"query": "<name>", "args": {...}}` per line. Useful for shell scripting and testing.

Both share the same query layer. See `docs/query-reference.md` for examples of both.

## Testing

```bash
python3 -m unittest discover
```

27 tests, all stdlib (no PyPI deps beyond PyYAML, which the framework already uses).

## What's NOT in this server

- No SaaS / hosted component. Everything runs locally.
- No baked-in semantic search provider — explicit per `config.md`.
- No PyPI deps beyond `PyYAML`.
- Not in the framework manifest. Extensions are opt-in user installs by design.

## Layout

```text
extensions/sdd-mcp-server/
├── README.md            ← this file
├── enable.sh            ← one-shot registration
├── server.py            ← JSON-RPC over stdio shim
├── queries/             ← one file per query (pure functions)
├── tests/               ← stdlib unittest suite
└── docs/
    └── query-reference.md
```
