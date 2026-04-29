#!/usr/bin/env bash
# enable.sh — install the playwright-explorer extension into the current project.
#
# Idempotent — safe to re-run. Asks before overwriting any existing config.
# Status: scaffold (v0.13.x). The MCP server registers; the actual agentic
# logic ships in a follow-up SPEC. Running this today gets you the protocol
# surface + the playbook integration point — calling `explore` returns a
# deferred response until the implementation lands.

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
echo "[playwright-explorer] STATUS: scaffold (v0.13.x). Agentic logic deferred — see README."

# 1. Register the MCP server in .mcp.json.
MCP_FILE=".mcp.json"
SERVER_PATH="$EXT_DIR/server.py"
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
- **Status:** scaffold (v0.13.x) — agentic logic deferred to follow-up SPEC
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
    enabled: false                    # flip to true when impl ships
    max_llm_calls_per_run: 50
    max_browser_actions_per_session: 200
    provider: ""                      # "openai" | "anthropic" | "ollama" | "local-gemma" — declared, not assumed
    endpoint: ""
    model: ""
    cost_limit_usd: 1.00              # circuit breaker
EOF
echo ""

cat <<'EOF'

[playwright-explorer] enabled (scaffold).

Next steps:
  1. Verify MCP registration: cat .mcp.json | grep playwright-explorer
  2. The explore queries return {"deferred": ...} today — that's correct.
     The scaffold proves the protocol surface; the implementation fills
     in the agentic loop.
  3. To start the implementation: /start "Playwright-explorer agentic implementation"
     That kicks off a real SPEC for the follow-up work.
  4. Read extensions/playwright-explorer/README.md for the full design.
EOF
