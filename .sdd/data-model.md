# SDD framework — data model

> The framework's own entities, in the same shape `data-model.md` works for any project. Useful for the framework's `/start` flow when proposing approaches that touch existing entities.

## Entities

### Action

A single step prose file. Lives at `templates/.sdd/actions/<slug>.md`. Has frontmatter declaring `slug`, `tag` (USER-LED / AGENT-LED / BUILD-TASK / TRANSITION), `steps` (array of `{id, action, field}`), `touches`, `references`, `trust`, `budget`, `requires_user_approval`. The body is plain-English prose Claude Code reads + executes.

Today: **31 actions** ship across two playbooks (feature: 24 actions; project: 7 actions added in v0.11.0).

### Playbook

A workflow template. Lives at `templates/.sdd/playbooks/<slug>.md`. Frontmatter declares `slug`, `stages` (array of `{id, actions}`), `terminal_state`, `work_item_folder`, `work_item_id_pattern`. Body documents the playbook's purpose.

Today: **2 playbooks** ship — `feature` and `project`. v1.0 adds two more (`bug.md` from issue #87, `refactor.md` from issue #85).

### Hook

A shell script invoked by Claude Code's PreToolUse / Stop / etc. lifecycle. Lives at `templates/.claude/hooks/<name>.sh`. Each hook reads stdin (JSON tool-input) and decides allow/block via exit code.

Today: **6 hooks** ship — `pre-commit-rules.sh` (F1 generic enforcer), `pre-commit-stage-verified.sh` (the moat), `pre-commit-no-assumed-markers.sh` (mechanical never-assume, v0.13.6), `session-start.sh`, `triage-on-first-message.sh`, `user-prompt-submit.sh`.

### Setup brick

A wizard question. Lives at `templates/.sdd/setup/<NNN>-<slug>.md`. Frontmatter declares `id`, `title`, `when` (start | sub-stage), `records_in`, `records_at`, `agent_infers`. Body is the question prose + answer options + recording rules.

Today: **7 bricks** ship — 001 project-type, 002 data-needs, 003 pr-reviewer, 004 browser-tests, 005 where-it-runs, 006 extras, 007 mcp-server (v0.13.6).

### Walkthrough

A tool-specific install guide invoked by a brick. Lives at `templates/.sdd/setup/walkthroughs/<provider>.md`. Frontmatter declares `provider`, `display_name`, `category`, `records_in`, `records_at`. Body walks the user through clicking-and-pasting their way through a vendor install (e.g. CodeRabbit's GitHub App install).

Today: **1 walkthrough** ships — CodeRabbit (v0.13.6 issue #67).

### Extension

An opt-in Lego brick. Lives at `extensions/<slug>/`. Each contains an `enable.sh`, README, and any framework artefacts (test runners, MCP servers, etc.).

Today: **3 extensions** ship — `playwright/` (production), `sdd-mcp-server/` (production), `playwright-explorer/` (scaffold; agentic logic deferred to v1.0 issue #84).

### Pi extension package

A pi.dev distributable form of SDD's adapter layer. Lives at `extensions/sdd-pi-extension/` in this repo, published to npm as `sdd-pi-adapter`. Has a `package.json#pi` manifest declaring `extensions:` (path to the built JavaScript extension entry) and `prompts:` (path to the slash-command template directory). The extension entry registers handlers for pi.dev's lifecycle events — `context` (pre-LLM state injection), `session_start` (one-time install of `.sdd/` brain into `.pi/sdd/`), `tool_call`/`tool_result` (advisory hooks) — plus instant LLM-free slash-commands via `pi.registerCommand`. Auto-discovered by pi when installed via `pi install npm:sdd-pi-adapter`. A specialised type of [[entity:Extension]] — every Pi extension package is an Extension, but not every Extension is a Pi package (the others are Claude-Code-specific or framework-internal).

Today: **0 ships**. Adds in feature 008.

### Slash command

A user-facing command body. Lives at `templates/.claude/commands/<name>.md`. Plain Markdown documenting what the command does + the prompt the agent should follow when invoked.

Today: **9 slash commands** ship — `/start`, `/next`, `/idea`, `/status`, `/settings`, `/sdd-setup`, `/sdd-config`, `/ship`, `/compress`.

### Script

A framework-runtime script. Lives at `templates/.sdd/scripts/<name>.sh`. Each is invoked by hooks or actions to do framework work (resolve cascade, walk INDEX, advance phase, etc.).

Today: **13 scripts** ship — `advance.sh`, `hash-section.sh`, `load-playbook.sh`, `next-action.sh`, `read-events.sh`, `reapprove.sh`, `resolve-parameters.sh`, `revert-phase.sh`, `settings.sh`, `start.sh`, `validate-sdd-path.sh`, `verify-stage.sh`, `check-setup-answer.sh`. v1.0 adds `scope-guard-config.sh` (item 2, PR #89).

### SynthesisCache

A derived index of cached synthesise() answers. Lives at `.sdd/.cache/synthesis.json` (gitignored — same pattern as the v1.0 graph cache). Source of truth is the corpus + the question history; cache exists purely to make repeat questions instant + free.

Shape: JSON dict keyed by `<sha256(question)>:<corpus_signature>` → `{answer, cite_chunks: [{slug, path, line}, ...], format_seen, ambiguity, created_at}`.

Invalidation: any corpus signature flip (any `.sdd/` markdown change) marks all entries from prior signatures stale; new keys use the new signature so old entries can stay readable until eviction. **Eviction policy:** LRU at 1000 entries (hardcoded for v1.1; configurable in v1.2+ if friction surfaces — added by §15 edge-case sweep on 2026-05-01). v1.1 adds this when [[001-tier-3-llm-driven-synthesis]] ships.

### Tier3Config

A config block under `parameters.mcp.tier3` in `templates/.sdd/config.md`. Off by default; opt-in. Required when `enabled: true`: `provider`, `endpoint`, `model`, plus mechanically-enforced cost caps (`max_calls_per_run`, `max_input_tokens_per_call`, `max_total_tokens_per_run`) and optional `auth_header` with `${ENV_VAR}` indirection. **v1.1 wizard configures Ollama+Gemma only**; the schema is provider-agnostic (foundation 3) but other providers require a manual config edit until v1.2+ widens wizard scope. **No `cost_limit_usd` field** — the framework can't price external services (anti-theatre, post-2026-05-01 audit).

Same shape pattern as v1.0 `parameters.mcp.semantic_search` and Playwright-explorer config — foundation 3 ("never assume an external service"). v1.1 adds this when [[001-tier-3-llm-driven-synthesis]] ships.

### InjectionBudget

A config block under `parameters.injection` in `templates/.sdd/config.md`. Two fields:

1. `cap_total_chars` (integer, existing) — defensive safety-net **ceiling** (maximum) applied to combined hook output AFTER per-file truncation runs. Catches sum-overshoot edge cases when the project's per-file budgets total more than the cap. The `SDD_INJECTION_CAP_CHARS` env var still overrides at runtime for backwards compatibility. (CR cycle 1 #1 terminology fix — was incorrectly called "floor"; a cap is a maximum, i.e. a ceiling.)

2. `per_file_budget_chars` (map, new in v1.7+ via feature 011) — keyed by corpus-file basename (`INDEX`, `spec`, `principles`, `stack`, `data-model`, `patterns`) to char-count budgets. The user-prompt-submit hook truncates each corpus file individually to its declared budget and appends a sentinel `[truncated to <N> bytes per per-file budget — re-read with the Read tool if you need the cut portion]` when truncation happens.

Read at runtime by `templates/.claude/hooks/user-prompt-submit.sh` via inline Python (one subprocess per turn). The dedicated helper `templates/.sdd/scripts/get-injection-budget.sh` exposes the same resolution rules for external callers (tests, downstream tooling).

Resolution rules:

- **Project override declared:** project's `config.md` value wins.
- **Negative value:** clamps to 0 + stderr warning naming the key (feature 011 AC17).
- **Project block omitted / null:** falls back to framework defaults (INDEX 3000 / spec 5000 / principles 2000 / stack 3000 / data-model 3000 / patterns 4000, summing to 20000).
- **Unknown basename key:** returns documented default of 2000 chars (so future corpus files added without an explicit budget entry get a sensible allocation).

Same shape pattern as `Tier3Config` (foundation 3 — framework defines the schema; downstream projects override in their own `config.md`).

## Relationships

- **Playbook → Action**: a playbook's `stages` array references action slugs in order.
- **Action → Field**: an action's `steps` array names spec.md fields the step writes (e.g. `§1.who`).
- **Brick → Action**: a brick's `requires_setup:` field names actions that halt if the brick's answer is deferred (v0.13.6 sub-stage triggering).
- **Slash command → Script**: each slash command body invokes one or more scripts (e.g. `/start` runs `start.sh`; `/next` runs `next-action.sh`).
- **Hook → Script**: hooks invoke scripts to validate state at commit time (e.g. `pre-commit-stage-verified.sh` runs `verify-stage.sh`).
- **Tier3Config → SynthesisCache**: config gates when the cache gets read/written; cache obeys the cost ceiling declared in config.
- **InjectionBudget → Hook (user-prompt-submit)**: the hook reads `parameters.injection.per_file_budget_chars` once per turn and applies each file's budget independently when concatenating corpus files for injection. `cap_total_chars` is then applied as a defensive floor on the concatenated output.
- **SynthesisCache → Graph node**: every cached answer's `cite_chunks[*].slug` must resolve to a real graph node (feature / pattern / entity / decision). Cite-check enforces this on every read AND every write.

## How this differs from a downstream user's data-model.md

A downstream user's `data-model.md` lists user-facing entities (e.g. User, Subscription, Order). This file lists the framework's OWN entities — playbook, action, hook, brick, etc. Same shape, different domain.

<!-- F009 (feature-playbook-v2-brief-driven-spec-entry, 2026-05-10) — no entity changes; framework-prose-only redesign. See .sdd/features/009-*/spec.md §6. -->
