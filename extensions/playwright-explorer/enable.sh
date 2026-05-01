#!/usr/bin/env bash
# enable.sh — install the playwright-explorer extension into the current project.
#
# Idempotent — safe to re-run. Asks before overwriting any existing config.
# Status: v1.0 (full agentic logic). The MCP server registers and the
# `explore` tool runs the cost-bounded agentic exploration loop. Findings
# emit ac:<slug> wiki-link cross-refs into spec.md so the framework's
# graph cache picks them up.

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
echo "[playwright-explorer] STATUS: v1.0 (full agentic logic active) — see README."

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
    enabled: false                    # flip to true to activate; LLM-cost-bounded
    max_llm_calls_per_run: 50
    max_browser_actions_per_session: 200
    provider: ""                      # "openai" | "anthropic" | "ollama" | "local-gemma" — declared, not assumed
    endpoint: ""
    model: ""
    cost_limit_usd: 1.00              # circuit breaker
EOF
echo ""

if [ "$mcp_registered" = "true" ]; then
  cat <<'EOF'

[playwright-explorer] enabled — MCP server registered, stack.md updated, config block printed above.

Next steps:
  1. Verify MCP registration: cat .mcp.json | grep playwright-explorer
  2. Set `enabled: true` in .sdd/config.md's playwright_explorer block once
     you're ready to spend LLM calls on exploration.
  3. The `explore` tool runs the cost-bounded agentic loop; findings emit
     `[[ac:slug]]` cross-refs the framework's graph cache picks up.
  4. Read extensions/playwright-explorer/README.md for the full design.
EOF
else
  cat <<'EOF'

[playwright-explorer] partial install — stack.md updated and config block printed above, BUT the MCP server stanza was NOT auto-registered (your .mcp.json already existed; see manual instructions above). Add the stanza by hand before the explore tool will reach this server.

Next steps:
  1. Paste the playwright-explorer stanza into .mcp.json (see instructions above).
  2. Verify MCP registration: cat .mcp.json | grep playwright-explorer
  3. Set `enabled: true` in .sdd/config.md's playwright_explorer block once
     you're ready to spend LLM calls on exploration.
  4. The `explore` tool runs the cost-bounded agentic loop; findings emit
     `[[ac:slug]]` cross-refs the framework's graph cache picks up.
  5. Read extensions/playwright-explorer/README.md for the full design.
EOF
fi
