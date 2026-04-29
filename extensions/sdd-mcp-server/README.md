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

The `search` query is **off by default**. When enabled, it embeds your `.sdd/` notebooks (decisions, patterns, data-model, stack, every shipped feature spec) once into a local cache, then ranks the chunks closest to your query by cosine similarity. The agent uses this so it doesn't have to scan-grep the whole repo every turn.

To turn it on, add a block to `.sdd/config.md`'s YAML frontmatter:

```yaml
parameters:
  mcp:
    semantic_search:
      enabled: true
      provider: openai             # or "ollama-native"
      endpoint: http://localhost:11434
      model: nomic-embed-text
      top_k: 5
      max_chunks_per_run: 1000     # cost ceiling — refuses to embed more in one call
```

### Picking the right `provider`

- **`openai`** (default) — the OpenAI-compatible HTTP shape. Hits `<endpoint>/v1/embeddings` with body `{model, input}`. Works with: OpenAI itself, Ollama in OpenAI-compatible mode (the default for `ollama serve`), vLLM, most cloud providers, LiteLLM, etc.
- **`ollama-native`** — older Ollama versions (or anyone who wants the native shape). Hits `<endpoint>/api/embeddings` with body `{model, prompt}`.

If you're running Ollama locally with `ollama serve`, `openai` is what you want — it accepts both shapes but the OpenAI one is the canonical default in current Ollama releases.

### What goes in `endpoint`

The base URL of the embedding service. The path (`/v1/embeddings` or `/api/embeddings`) is appended automatically based on provider. Both of these work:

- `http://localhost:11434` → resolves to `http://localhost:11434/v1/embeddings` for `openai`
- `http://localhost:11434/v1/embeddings` → used as-is

If your endpoint sits behind an auth gate, add `auth_header: "Bearer <token>"` to the block — it goes onto each request as the `Authorization` header.

### What it does the first time you run it

- Walks `.sdd/` and chunks every searchable file (~500-character paragraph-aware blocks).
- POSTs each chunk to your configured endpoint.
- Caches every (chunk, vector) pair at `.sdd/.cache/embeddings.json`, keyed by content SHA so unchanged chunks skip re-embedding next run.
- Re-embeds automatically if you swap models, providers, or endpoints (different models produce incomparable vectors).

### What it does on every subsequent run

- Embeds only the changed chunks.
- Reads everything else from the cache.
- Returns the top-k results plus a `stats` block telling you how many chunks were re-embedded vs read from cache. The agent doesn't have to scan-grep your repo to remember what you decided three weeks ago.

### When the endpoint is unreachable

The query never raises a Python exception at the user. It returns a plain-English `error` field with a `fallback: "agent should read files directly"` hint. The agent reads that, falls back to per-file reads, and tells you what's wrong — typically your endpoint URL, your tunnel state, or an auth problem.

The framework deliberately doesn't bake in a default provider — per the SDD doctrine in `CLAUDE.md`, every external dependency must be an explicit choice.

## Protocol

The server speaks two flavours of JSON over stdio on the same socket:

1. **Minimal MCP** (JSON-RPC 2.0): `initialize`, `tools/list`, `tools/call`. This is what Claude Code uses.
2. **Simplified SDD**: `{"query": "<name>", "args": {...}}` per line. Useful for shell scripting and testing.

Both share the same query layer. See `docs/query-reference.md` for examples of both.

## Testing

```bash
python3 -m unittest discover
```

29 tests, all stdlib (no PyPI deps beyond PyYAML, which the framework already uses). The semantic-search tests verify error paths against an unreachable endpoint (`127.0.0.1:1`) — full mock-server tests that exercise the cache and embedding code paths are tracked separately.

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
