# Playwright-explorer extension for SDD

> Opt-in Lego brick. AI-driven browser exploration for new edge-case discovery.
> Complements `extensions/playwright/` (regression tests) with EXPLORATION
> (find bugs you didn't think to test).

## What this extension does

The framework's BUILD layer covers **deterministic regression tests** via `extensions/playwright/`. Same inputs → same outputs. Cheap to run on every PR. Catches: "did AC3 still work after this change?"

This extension covers the OTHER side: **agentic exploration**. An MCP server drives a real browser via Playwright API, and the LLM picks weird inputs to try across 8 edge-case categories. Different shape:

| Scripted (the Playwright extension) | AI-driven exploration (this extension) |
|---|---|
| Deterministic. Same inputs → same outputs. | Agent picks weird inputs the spec author didn't think of. |
| Cheap to run repeatedly; lives in CI on every PR. | Expensive (LLM calls); runs end-of-cycle, manually. |
| Catches REGRESSIONS — "did AC3 still work?" | Catches NEW BUGS — "what would a creative attacker / confused user actually do?" |
| Each test ties to one AC. | Output: NEW ACs to add to §11 in the next iteration. |

## How it works

The MCP server exposes three tools:

- **`explore`** — drives a deployed feature URL through 8 edge-case categories (`empty / max / bad-input / network / concurrency / auth / mobile / time-based`) at 3 attempts per category, returning structured findings with reproduction steps.
- **`summarise_findings`** — turns raw findings into the same `add` / `drop` / `later` triage shape that `edge-case-sweep` uses, so the language stays consistent.
- **`report_status`** — reports the last run's stats (LLM calls used, browser actions used, estimated cost, halt reason).

Each `explore` run asks the LLM **one question per probe** ("propose ONE concrete browser action to test this category, plus what the spec implies should happen") and compares the post-action state against the expected outcome. Divergence — fresh console errors, network errors, missing expected text on the page — becomes a finding. Findings whose tokens overlap an existing AC get tagged as "covered by AC<n>"; the rest are flagged as **uncovered**, the ones the user actually needs to triage.

## Cost ceiling

Three independent budgets, all read from `parameters.playwright_explorer` in `.sdd/config.md`:

- `max_llm_calls_per_run` (default 50) — capped per session
- `max_browser_actions_per_session` (default 200)
- `cost_limit_usd` (default 1.00) — circuit breaker

Whichever trips first halts the run cleanly with a `halt_reason` in the response. No runaway. Default budgets are calibrated for ~24 attempts per run = 3 attempts × 8 categories = single-digit-USD cost on most providers.

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

1. **Registers the MCP server in `.mcp.json` IF the file does not already exist.** If `.mcp.json` is already present, it prints the stanza you need to paste in by hand (automated merging is intentionally deferred — too easy to clobber other servers' settings).
2. **Appends a `## AI-driven exploration` section to `.sdd/stack.md`** if that section isn't already there.
3. **Prints the `parameters.playwright_explorer` block** for `.sdd/config.md`. You paste it into the `parameters:` block of your config.md frontmatter yourself.

After running enable.sh, you also need to **install Playwright + Chromium** in your project's Python environment:

```bash
pip install playwright
playwright install chromium
```

(The extension's tests don't need this — they run against a mock browser. Only live `explore` runs touch real Chromium.)

## How it runs per feature

1. **Trigger**: SHIP phase, after `adversarial-review`, before `learn`. The action is `playwright-explore` (see `.sdd/actions/playwright-explore.md`).
2. **Inputs**: deployed feature URL (from `## Running services` in stack.md + the feature's expected slug), `spec.md` §11 ACs (so the explorer can score finding coverage), optional auth cookie.
3. **Run**: agent calls the MCP server's `explore` tool. The configured LLM (per `parameters.playwright_explorer.provider`) navigates a real Chromium instance via Playwright, tries weird interactions across the 8 categories.
4. **Output**: structured findings list `{found: N, uncovered: M, items: [...]}` with reproduction steps for each. Findings get a `[[ac:<slug>]]` wiki-link suggestion the user can lift into spec.md §11.
5. **Triage**: the user replies `add 1,2; drop 3; later 4` for each finding. Each `add` appends a new AC + a new BUG task and reverts SHIP→BUILD so the loop re-fires on the new code.

## LLM provider configuration

The explorer hits any **OpenAI-compatible chat-completions endpoint** — same shape as OpenAI, Ollama, vLLM, llama.cpp's HTTP server, or anything proxying the spec. Configure in `.sdd/config.md`:

```yaml
parameters:
  playwright_explorer:
    enabled: true
    provider:
      endpoint: https://api.openai.com/v1/chat/completions
      model: gpt-4o-mini
      auth_env: OPENAI_API_KEY        # name of an env var holding your token
    max_llm_calls_per_run: 50
    max_browser_actions_per_session: 200
    cost_limit_usd: 1.00
    headless: true
    viewport:
      width: 390
      height: 844                     # iPhone-13 portrait by default
    auth_cookie: null                 # or {name, value, domain, path}
```

For local Ollama (no auth needed):

```yaml
provider:
  endpoint: http://localhost:11434/v1/chat/completions
  model: qwen2.5-coder:7b
  auth_env: ""                        # no token; bearer header is omitted
```

## Compounds with adversarial-review and edge-case-sweep

Three layers of "what did we miss" — each catches a different class of bug:

- **`edge-case-sweep`** (SPEC, before BUILD) — agent imagines edge cases pre-build. Templated.
- **`adversarial-review`** (SHIP, after green) — agent re-reads spec + code in hostile-reviewer hat. Pattern-based.
- **`playwright-explore`** (SHIP, after adversarial-review, before user QA) — agent ACTUALLY DRIVES the deployed app trying to break it. Empirical.

Together: the closest to "least bugs in production" the framework can offer. Foundation 3 (never assume) means we shouldn't trust that the spec author thought of everything — AI exploration is the systematic way to verify.

## Architecture (one screen)

```text
extensions/playwright-explorer/
├── server.py           # MCP server: explore / summarise_findings / report_status
├── explorer.py         # the cost-bounded explore loop (no I/O — orchestration only)
├── drivers/
│   ├── llm.py          # LLMDriver ABC + MockLLMDriver + HttpLLMDriver
│   └── browser.py      # BrowserDriver ABC + MockBrowserDriver + PlaywrightBrowserDriver
└── tests/
    ├── test_drivers.py    # driver contracts
    ├── test_explorer.py   # explore-loop end-to-end with mocks
    └── test_scaffold.py   # MCP-server protocol + dispatch
```

`explorer.py` is pure orchestration — no LLM, no browser, no I/O. It composes any `LLMDriver` + any `BrowserDriver`. `server.py` swaps mocks for real implementations via the module-level `_explore_factory` (the test seam mentioned in #84 AC7). PlaywrightBrowserDriver imports playwright lazily so the test path doesn't drag in the dep.

## Running the tests

```bash
cd extensions/playwright-explorer
python3 -m unittest discover tests/
```

67 tests cover: driver contracts (mock + real construction + error paths), the explore loop (8-category sweep, all 3 budget halts, AC4 finding shape, AC coverage heuristic, the add/drop/later triage), and the MCP server's protocol + dispatch.

## Disable

```bash
bash <path-to-this-repo>/extensions/playwright-explorer/disable.sh
```

(Asks before removing the MCP registration, the config block, or the playbook action.)
