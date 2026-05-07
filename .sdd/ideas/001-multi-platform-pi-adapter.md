# Idea: Multi-platform SDD extensibility — pi.dev adapter as second harness

**Captured:** 2026-05-07
**Status:** captured

## What's the idea?

Add a thin pi.dev adapter alongside the existing Claude Code adapter, so SDD's methodology can run in pi.dev too. Pi.dev is itself a multi-model harness supporting 15+ providers (Anthropic, OpenAI, Ollama, Bedrock, Groq, Cerebras, xAI, OpenRouter, etc.), so one adapter unlocks every non-Claude model in one move. The adapter would live at `extensions/sdd-pi-extension/` in this repo and ship as an npm package with a `package.json#pi` manifest, one TypeScript extension file (~300 lines), and 10 thin slash-command templates that include the existing `.sdd/actions/*.md` prose unchanged. Claude Code support stays exactly as it is — the adapter is additive, not replacement.

## What problem might it solve?

Today SDD only runs in Claude Code. Colleagues using GPT-5 via Codex, open-weight models (Kimi K2, Llama), or pi.dev itself can't adopt SDD without switching CLIs — a non-starter. This adapter removes the platform lock and lets SDD reach the wider AI-coding-agent ecosystem without compromising the Claude Code experience.

## Why might it matter?

One pi.dev adapter reaches **15+ models**, instead of building N separate adapters per CLI (Codex, Cursor, Aider, etc.). Discipline test in this session passed 2/2 — GPT-5.5 via Codex and Kimi K2 2.6 via NVIDIA Build both stayed disciplined on the BUILD-TASK atomic-step rule, so the methodology travels off Claude. Maintenance overhead grows by ~10-15%, not 100%, because most SDD lines are in harness-agnostic markdown + bash. Active prior art exists: [fulgidus/pi-gsd](https://github.com/fulgidus/pi-gsd) ports the sibling GSD framework to pi.dev (MIT, 69 releases, last published 3 days ago) — confirms the pattern works. MCP gap is solved out-of-the-box by the community [pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter) package (599 stars, MIT, actively maintained).

## Confidence

Pretty sure. Validated by: (a) discipline test passing for two non-Claude models, (b) pi.dev's lifecycle events (`context`, `session_start`, `tool_call`, `tool_result`) all confirmed to map to SDD's needs, (c) MCP gap externally solved, (d) extension contract is small and well-documented. Long-session discipline test (20+ turns) is the next cheap validation before any build commitment.

## Related features

None yet shipped. Two sibling ideas captured in the same session that interact with this one:
- `002-parallel-wave-execution` — parallel agent waves with fresh contexts (the wave model that GSD uses)
- `003-specialized-subagents` — planner / executor / verifier / debugger sub-roles (GSD has 18; SDD would start with fewer)

Both ideas become much more valuable on top of this one: the actual win for parallel + subagents is mixing models per role (e.g. planner=Opus, executor=Sonnet, verifier=Haiku/open-weight), which only works once SDD reaches multiple models. So this idea is likely the precursor.
