# agent-plumb-pi

> **Agent Plumb** for **pi.dev** — keeps your AI coding in plumb. A spec-driven workflow (`SPEC → BUILD → SHIP`) with mechanical drift checks + append-only decisions ledger, on any of pi's 20+ AI providers.
>
> **Specs > vibes.**

## Install

```bash
pi install npm:agent-plumb-pi
```

That's it. After install, the slash commands become available inside `pi`:

| Command | What it does |
|---|---|
| `/sdd-setup` | First-session wizard — 8 plain-English questions that fill `stack.md` + `config.md` |
| `/sdd-start "<title>"` | Scaffold a new feature, bug, or idea |
| `/sdd-next` | Advance the active work by one atomic step (= one commit) |
| `/sdd-status` | Show current phase + active blocker |
| `/sdd-idea "<thought>"` | Capture a half-formed thought to backlog |
| `/sdd-bug "<title>"` | Start a bug repro → root-cause → fix loop |
| `/sdd-ship` | Push branch, open PR, watch CI, mark shipped |

> Note: slash commands still use the `/sdd-*` prefix internally; this lets existing scripts + muscle memory keep working through the rename. A future major version may add `/plumb-*` aliases.

## What is Agent Plumb?

Agent Plumb is a spec-driven workflow that forces AI coding agents to write a clear spec, get human approval, then build against it — with pre-commit hooks that mechanically refuse commits that drift from the approved spec. Plain English first, no jargon, atomic commits, append-only audit trail.

Read the [full walkthrough](https://github.com/samuelserraceo/agent-plumb/blob/main/docs/walkthrough.html) or the [5-minute getting-started guide](https://github.com/samuelserraceo/agent-plumb/blob/main/docs/getting-started.html).

## Auth

This adapter relies on whatever provider auth you've set up in pi — OAuth subscription (Claude Pro / ChatGPT Plus / Copilot) or API key (Anthropic, OpenAI, NVIDIA, Mistral, Groq, Ollama, etc.). The Agent Plumb discipline is the same regardless of model.

## Migrating from `sdd-pi-adapter`

This package was previously published as `sdd-pi-adapter`. The old name has been deprecated. To upgrade: `pi uninstall sdd-pi-adapter && pi install npm:agent-plumb-pi`. No state migration needed — the slash commands and underlying behaviour are identical.

## License

MIT
