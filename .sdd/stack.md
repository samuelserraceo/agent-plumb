# SDD framework — stack

> The framework's own runtime stack. Read once on session start so the agent doesn't propose alternatives that contradict what's already in place.

## Project shape

- **Type**: framework / developer-tool
- **Language**: Bash + Python 3
- **Framework**: none (it IS the framework)
- **Distribution**: cloned as a Claude Code plugin via the plugin manifest

## Data store

- **Type**: filesystem (no database)
- **Where**: `.sdd/` (project state) + `templates/.sdd/` (the template that gets shipped to consumers)
- **Schema source**: this file + `data-model.md`

## Testing

- **Test runner**: pure bash + Python 3 stdlib (no pytest / mocha / jest dependency)
- **Where**: `test/run-framework-test.sh`
- **Pattern**: each test is a `note` block + assertion bash; mutation-verified discipline
- **Today's count**: 248 framework tests as of 2026-05-13 (v1.7-v1.9 ship batch + the F027 verify-stack 8-check suite at T280-T287). Count grows as new T-cases land — derive precisely with `bash test/run-framework-test.sh | tail -1`.
- **CI**: `.github/workflows/sdd-ci.yml` — framework-tests + scope-guard jobs

## Running services

- **Hosting**: GitHub (the framework's repo + releases live there)
- **CI provider**: GitHub Actions
- **PR review**: CodeRabbit (configured per `parameters.review.bot: coderabbit`)
- **Release distribution**: git tags + GitHub Releases + Anthropic plugin manifest (when v1.x ships to the marketplace)

## Extras (third-party services the framework reaches for)

- **LLM provider for the framework's MCP server semantic search**: Ollama (configurable). Embedding model: `nomic-embed-text` or `bge-small-en-v1.5`. Endpoint: configured per project — placeholder `<MCP_EMBEDDINGS_ENDPOINT>` (e.g. `http://your-host.example:11434/api/embeddings`). Maintainer's local development uses an SSH-tunnelled Ollama instance — exact host details live in the maintainer's local config, never in this public doc. Read the actual endpoint from the project's `parameters.mcp.semantic_search.endpoint` config block. Lands in v1.0 item 4 / issue #91.
- **Obsidian** (optional, opt-in for users): the framework ships a `.obsidian/` vault config so users can open the project root in Obsidian and see the `.sdd/` tree as a connected graph. Lands in v1.0 item 3 / PR #90.
- **No other external dependencies.** The framework's runtime is `bash + python3 + PyYAML + git + gh`.

## AI-driven exploration

- **Tool**: `extensions/playwright-explorer/` (scaffold today; agentic logic in v1.0 item 11 / issue #84)
- **Status**: scaffold only — `explore` MCP call returns `{"deferred": ...}` until the follow-up SPEC ships
- **Purpose**: end-of-cycle exploratory testing; LLM-driven browser exploration to find edge cases the spec author missed
- **Cost-bounded**: respects `parameters.playwright_explorer.max_llm_calls_per_run` + `cost_limit_usd`

## Why this file is here in the framework's own .sdd/

A consumer project's `stack.md` records what THEY use. The framework's own `stack.md` records what the framework itself uses (bash, python3, gh CLI, GitHub Actions for CI, optional Ollama for the semantic search). Same file shape, different domain. The `/sdd-setup` wizard isn't run on the framework repo — those answers are filled in directly here.
