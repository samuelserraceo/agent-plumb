#!/usr/bin/env bash
# enable.sh — install the playwright-explorer extension into the current project.
#
# Idempotent — safe to re-run. Asks before overwriting any existing config.
# Status: v1.0 — full agentic logic shipped. The MCP server registers
# the `explore` tool, which runs the cost-bounded agentic exploration
# loop when invoked. Each finding includes an `ac_link` suggestion of
# the form `ac:<slug>` (returned in the findings list for user triage)
# — the user decides whether to lift it into spec.md §11. Nothing is
# auto-written; the explorer reports, the human curates.

set -euo pipefail

EXT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve project root (CLAUDE_PROJECT_DIR > git root > pwd, with warning).
resolve_project_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
    echo "$CLAUDE_PROJECT_DIR"
    return
  fi
  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    echo "$git_root"
    return
  fi
  echo "warning: not inside a git repo and CLAUDE_PROJECT_DIR not set;" \
       "scaffolding into current directory: $(pwd)" >&2
  pwd
}

PROJECT_DIR="$(resolve_project_root)"
cd "$PROJECT_DIR" || {
  echo "[playwright-explorer] cannot cd into $PROJECT_DIR" >&2
  exit 1
}

echo "[playwright-explorer] installing into $PROJECT_DIR"
echo "[playwright-explorer] STATUS: v1.0 install — agentic logic shipped, opt-in via config (see below)."

# 1. Register the MCP server in .mcp.json.
MCP_FILE=".mcp.json"
SERVER_PATH="$EXT_DIR/server.py"
mcp_registered=false
if [ ! -f "$MCP_FILE" ]; then
  cat > "$MCP_FILE" <<EOF
{
  "mcpServers": {
    "playwright-explorer": {
      "command": "python3",
      "args": ["$SERVER_PATH"]
    }
  }
}
EOF
  mcp_registered=true
  echo "[playwright-explorer] created $MCP_FILE with server registration"
else
  echo "[playwright-explorer] $MCP_FILE exists — please add the server stanza by hand:"
  echo ""
  echo '  "playwright-explorer": {'
  echo '    "command": "python3",'
  echo "    \"args\": [\"$SERVER_PATH\"]"
  echo '  }'
  echo ""
  echo "(automated merging of existing .mcp.json deferred — too easy to clobber other servers)"
fi

# 2. Append a `## AI-driven exploration` section to .sdd/stack.md if missing.
if [ -f ".sdd/stack.md" ]; then
  if grep -q "^## AI-driven exploration" .sdd/stack.md; then
    echo "[playwright-explorer] .sdd/stack.md already has AI-driven exploration section; skipping"
  else
    cat >> .sdd/stack.md <<'EOF'

## AI-driven exploration

- **Tool:** playwright-explorer (extensions/playwright-explorer/)
- **Status:** v1.0 — full agentic logic shipped (cost-bounded LLM-driven exploration)
- **Purpose:** end-of-cycle exploratory testing; surfaces edge cases the spec author missed
- **Runs in:** SHIP phase, after verify-test-run, before learn (when impl lands)
- **Cost-bounded:** declares max_llm_calls + max_browser_actions per run
EOF
    echo "[playwright-explorer] appended AI-driven exploration section to .sdd/stack.md"
  fi
fi

# 3. Configure the parameters.playwright_explorer block in .sdd/config.md.
# Today's stub: just print the block the user can paste in. Once the
# implementation lands we'll do this via settings.sh set commands.
echo ""
echo "[playwright-explorer] add this block to .sdd/config.md frontmatter under parameters: (if not already present):"
echo ""
cat <<'EOF'
  playwright_explorer:
    # Required before flipping enabled to true: set `provider`, `endpoint`,
    # `model` below. The `explore` tool refuses to run if any of those is
    # empty (no implicit hosted-service assumption per CLAUDE.md doctrine
    # on external dependencies).
    enabled: false                    # flip to true AFTER setting provider/endpoint/model
    max_llm_calls_per_run: 50
    max_browser_actions_per_session: 200
    provider: ""                      # "openai" | "anthropic" | "ollama" | "local-gemma" — declared, not assumed
    endpoint: ""                      # required if enabled: true (e.g. http://localhost:11434 for ollama)
    model: ""                         # required if enabled: true (e.g. "gemma4:e4b" for local-gemma)
    cost_limit_usd: 1.00              # circuit breaker
EOF
echo ""

if [ "$mcp_registered" = "true" ]; then
  cat <<'EOF'

[playwright-explorer] installed — MCP server registered, stack.md updated, config block printed above. (Not yet active; opt-in below.)

Next steps:
  1. Verify MCP registration: cat .mcp.json | grep playwright-explorer
  2. In .sdd/config.md's playwright_explorer block: set `provider`,
     `endpoint`, and `model` for your LLM (e.g. "ollama" + "http://localhost:11434"
     + "gemma4:e4b" for self-hosted; "openai"/"anthropic" + their respective
     endpoints + a chat model otherwise). The `explore` tool refuses to run
     while any of those is empty.
  3. THEN flip `enabled: true` in the same block.
  4. The `explore` tool returns findings with `ac_link` suggestions
     (`ac:<slug>` wiki-links you can lift into spec.md §11). Nothing is
     auto-written.
  5. Read extensions/playwright-explorer/README.md for the full design.
EOF
else
  cat <<'EOF'

[playwright-explorer] partial install — stack.md updated and config block printed above, BUT the MCP server stanza was NOT auto-registered (your .mcp.json already existed; see manual instructions above). Add the stanza by hand before the explore tool will reach this server. (Not yet active; opt-in below.)

Next steps:
  1. Paste the playwright-explorer stanza into .mcp.json (see instructions above).
  2. Verify MCP registration: cat .mcp.json | grep playwright-explorer
  3. In .sdd/config.md's playwright_explorer block: set `provider`,
     `endpoint`, and `model` for your LLM (e.g. "ollama" + "http://localhost:11434"
     + "gemma4:e4b" for self-hosted; "openai"/"anthropic" + their respective
     endpoints + a chat model otherwise). The `explore` tool refuses to run
     while any of those is empty.
  4. THEN flip `enabled: true` in the same block.
  5. The `explore` tool returns findings with `ac_link` suggestions
     (`ac:<slug>` wiki-links you can lift into spec.md §11). Nothing is
     auto-written.
  6. Read extensions/playwright-explorer/README.md for the full design.
EOF
fi
