# Playwright-explorer extension for SDD

> Opt-in Lego brick. AI-driven browser exploration for new edge-case discovery.
> Complements `extensions/playwright/` (regression tests) with EXPLORATION
> (find bugs you didn't think to test).

## ⚠️ Status: scaffold + design (v0.13.x) — agentic logic deferred

This extension ships **the structure, the integration design, and a stub MCP server** — but the actual agentic-exploration logic is deferred to a follow-up SPEC (referenced as a TODO inside `server.py`). Until that lands, calling the MCP server's main `explore` query returns a `{"deferred": ...}` shape pointing at the open work.

Why ship a scaffold: **the design is the load-bearing thing**. With the scaffold in place, the integration point exists in the SHIP playbook, the brick's `enable.sh` works, the README explains the value, and the MCP server's protocol surface is registered. The follow-up that fills in the real Playwright-driving logic doesn't need to wire any new SDD plumbing.

## What this extension WILL do (when the deferred work lands)

The framework's BUILD layer covers **deterministic regression tests** via `extensions/playwright/`. Same inputs → same outputs. Cheap to run on every PR. Catches: "did AC3 still work after this change?"

This extension covers the OTHER side: **agentic exploration**. An MCP server drives a real browser via Playwright API, and the LLM picks weird inputs to try. Different shape:

| Scripted (the Playwright extension — shipped) | AI-driven exploration (this extension — scaffold) |
|---|---|
| Deterministic. Same inputs → same outputs. | Agent picks weird inputs the spec author didn't think of. |
| Cheap to run repeatedly; lives in CI on every PR. | Expensive (LLM calls); runs end-of-cycle, manually. |
| Catches REGRESSIONS — "did AC3 still work?" | Catches NEW BUGS — "what would a creative attacker / confused user actually do?" |
| Each test ties to one AC. | Output: NEW ACs to add to §11 in the next iteration. |

## When to enable

- ✅ Your feature has a UI you can deploy to a stage URL
- ✅ You want a final layer of "did the spec author miss anything?" before user QA
- ✅ You're shipping a feature with novel UX (forms, multi-step flows, auth boundaries)
- ❌ Backend-only project with no UI (regression tests cover this)
- ❌ Tiny features (cost of running may exceed value)

## How to enable

```bash
cd <your-project-root>
bash <path-to-this-repo>/extensions/playwright-explorer/enable.sh
```

The script:
1. Registers the playwright-explorer MCP server in `.mcp.json`
2. Adds a `## AI-driven exploration` section to `.sdd/stack.md` recording the choice
3. Configures `parameters.playwright_explorer` block in `.sdd/config.md` (cost limit, default model, etc.)
4. Adds the `playwright-explore` action to the SHIP phase of `feature.md` playbook (asks before modifying)

## What it will do per feature (when implementation lands)

1. **Trigger**: SHIP phase, after `verify-test-run`, before `learn`. Action = `playwright-explore`.
2. **Inputs**: deployed feature URL (from `## Running services` in stack.md + the feature's expected slug), `spec.md` §11 ACs, optional auth cookie.
3. **Run**: agent (driven by configured LLM) navigates a real Chromium instance via Playwright, tries weird interactions across the same 8 categories edge-case-sweep uses (empty / max / bad input / network / concurrency / auth / mobile / time-based) — but DYNAMICALLY generated, not templated.
4. **Output**: structured findings list `{found: N issues, uncovered: M not in current ACs}` with reproduction steps for each.
5. **Triage**: findings flow into the same `add` / `drop` / `later` shape edge-case-sweep already uses. User picks; "add" lands a new AC + new BUILD task. Loop back through BUILD before final ship.

## Cost bounding

The MCP server config declares `max_llm_calls_per_run` and `max_browser_actions_per_session`. The exploration run respects these — once the budget is exhausted, it summarises what it found and exits cleanly. No runaway costs.

## Compounds with adversarial-review and edge-case-sweep

Three layers of "what did we miss" — each catches a different class of bug:

- **edge-case-sweep** (SPEC, before BUILD) — agent imagines edge cases pre-build. Templated.
- **adversarial-review** (SHIP, after green) — agent re-reads spec + code in hostile-reviewer hat. Pattern-based.
- **playwright-explorer** (SHIP, after green, before user QA) — agent ACTUALLY DRIVES the deployed app trying to break it. Empirical.

Together: the closest to "least bugs in production" the framework can offer. Foundation 3 (never assume) means we shouldn't trust that the spec author thought of everything — AI exploration is the systematic way to verify.

## What's deferred to the follow-up SPEC

- The actual Playwright-driving logic in `server.py`
- LLM provider integration (mirrors the `parameters.mcp.semantic_search` opt-in shape — declared provider, no baked-in default)
- Per-finding reproduction-step capture
- Cost reporting + circuit breaker
- T-NN regression tests for the agentic flow (will need a fixture site to drive against)

The SPEC for this work tracks at: `.sdd/features/<NNN>-playwright-explorer-impl/` (to be opened via `/start "Playwright-explorer agentic implementation"`).

## Disable

```bash
bash <path-to-this-repo>/extensions/playwright-explorer/disable.sh
```

(Asks before removing the MCP registration, the config block, or the playbook action.)
