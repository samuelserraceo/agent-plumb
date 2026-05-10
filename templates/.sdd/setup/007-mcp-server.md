---
id: mcp-server
title: "Save tokens (and money) as the project grows?"
when: start
records_in: ".sdd/config.md"
records_at: "parameters.mcp.enabled"
# Tier 3 sub-questions (v1.1) also write to parameters.mcp.tier3.* — see brick body.
# Listed under agent_infers below + documented in body. Single-string
# records_at preserves the existing T111 frontmatter validator's contract.
agent_infers:
  - mcp-enabled
  - mcp-installed
  - tier3-enabled                 # set by Tier 3 sub-question Q1 (records parameters.mcp.tier3.enabled)
  - tier3-ollama-endpoint         # set by Q2 (records parameters.mcp.tier3.endpoint)
  - tier3-gemma-model             # set by Q3 (records parameters.mcp.tier3.model)
  - tier3-cost-caps               # set by Q4 (records parameters.mcp.tier3.{max_calls_per_run,max_input_tokens_per_call,max_total_tokens_per_run})
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
| "Yes — turn it on" | Records `parameters.mcp.enabled: true` in `.sdd/config.md`. |
| "No" | Records `parameters.mcp.enabled: false`. You can re-enable any time via `/sdd-config mcp-server`. |
| "Tell me more" | Agent reads the explanation block below to you in plain English, then re-asks. |

**Then, regardless of which option was picked**, the agent runs
`bash .sdd/scripts/install-mcp-server.sh --quiet`. The script reads
`parameters.mcp.enabled` from `config.md` and:

- If **true**: invokes `extensions/sdd-mcp-server/enable.sh` to write `.mcp.json` with the `sdd` mcpServer entry, verifies the registration landed, and reports the outcome.
- If **false** / unset / deferred: self-skips silently so the wizard prose can call it unconditionally.

Same shape as brick 004's `install-ci-workflow.sh` (#199). Idempotent:
re-runs preserve existing `.mcp.json` registrations unless `--force`.

**Halt on registration failure.** If `install-mcp-server.sh` exits non-zero (e.g., the symlink to `extensions/sdd-mcp-server/` is broken, or `enable.sh` itself failed), the wizard MUST stop here — don't move to the next brick with a half-installed MCP server. The script's stderr names the actual problem in plain English; the typical fix is one of:

- **Symlink missing:** `bash bin/sdd-init.sh` re-runs the framework installer, which re-creates the `extensions/sdd-mcp-server/` symlink to your plugin install.
- **PyYAML missing:** `pip3 install --user PyYAML`, then re-run `/sdd-config 007-mcp-server`.
- **enable.sh wrote a malformed `.mcp.json`:** capture the stderr from the script and report — this is a framework bug, not user error.

Once fixed, re-run `/sdd-config 007-mcp-server` to retry the install.

**Why this matters (closes #209).** Pre-v1.5.4 the wizard ASKED brick 007
and RECORDED `mcp.enabled: true` — but never actually invoked `enable.sh`.
`config.md` carried a `pending_install: true` flag that documented the
gap but no one reconciled it. Users were promised 40-60% token saving
they didn't get; verified against `pipelogic_v2` F01 transcript (zero
`mcp__sdd__*` tool calls in 33,838 lines). v1.5.4 closes the contract:
wizard records → script wires → MCP server is real.

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

---

## Chat-based answers (Tier 3) — only asked if you said yes to MCP server above

> *Scaffolded by T4 of the v1.1 Tier 3 SPEC. The actual wizard wiring that runs these questions and writes the answers into `parameters.mcp.tier3` is T23 (end-to-end test). For now this section is the question content the wizard will read.*

If you turned on the MCP server, the framework can also offer **chat-based answers** about your project — *"why did we pick Postgres?"*, *"what TODOs have piled up?"*. The agent reads the relevant pieces of your project, asks a small AI on your laptop, and returns the answer with clickable citations.

**v1.1 supports Ollama + Gemma running locally only.** Other providers (OpenAI, Anthropic, etc.) are settable manually but not wizard-supported until v1.2+ widens the wizard. v1.1's choice is local-only because: (a) zero operating cost · (b) nothing leaves your laptop (privacy by default) · (c) Gemma is small enough for a typical laptop.

### Q1 — want chat-based answers?

1. **Yes — turn it on** *(recommended if your project will run for months)* — the wizard helps you install Ollama if you don't have it, then pulls a Gemma model. Records `parameters.mcp.tier3.enabled: true` plus the provider / endpoint / model you confirm in Q2-Q4.
2. **No — skip for now** — records `parameters.mcp.tier3.enabled: false`. You can re-enable any time via `/sdd-config tier3`.
3. **Tell me more** — agent explains in plain English (uses the Tier 3 walkthrough at [[001-tier-3-llm-driven-synthesis]] if available).

### Q2 — where is your Ollama running? *(only if Q1 = yes)*

Default: `http://localhost:11434` (the standard Ollama port on your machine). If you've changed it, paste the URL.

### Q3 — which Gemma model? *(only if Q1 = yes)*

Default: `gemma2:2b` (a small model that fits on most laptops). Other options:
- `gemma2:9b` — bigger, slightly better answers, needs more RAM
- `gemma3:12b` — newer, more capable, needs a beefier laptop

The wizard offers to run `ollama pull <model>` on your behalf if the model isn't installed yet.

### Q4 — accept the default cost caps? *(only if Q1 = yes)*

Defaults from the spec: max 10 calls per run · max 8000 input tokens per call · max 100,000 total tokens per run. Plenty for ~20 questions a week. You can adjust later via `/sdd-config tier3`.

1. **Yes, defaults are fine** *(recommended)* — records the defaults.
2. **Adjust** — wizard prompts for each cap.

### What gets recorded

```yaml
# in .sdd/config.md, under parameters.mcp.tier3:
tier3:
  enabled: <true | false>
  provider: "ollama-chat"          # v1.1 wizard always uses this; v1.2+ widens
  endpoint: "<from Q2>"
  model: "<from Q3>"
  max_calls_per_run: <from Q4>
  max_input_tokens_per_call: <from Q4>
  max_total_tokens_per_run: <from Q4>
  auth_header: ""                  # empty for local Ollama; load-bearing for v1.2+ paid providers
```

**No `cost_limit_usd` field.** The framework can't enforce dollar amounts (anti-theatre — see the spec § proposed-approach for the audit). Token caps above are the mechanical enforcement.
