#!/usr/bin/env bash
# enable.sh — register the SDD MCP server with Claude Code.
#
# Claude Code reads MCP server registrations from a few possible places.
# We try them in order of preference:
#
#   1. Per-project: ./.mcp.json   (committable; preferred for SDD projects)
#   2. Per-user:    ~/.claude.json (user-global; fallback if no project file)
#
# In both cases the registration shape is:
#
#   {
#     "mcpServers": {
#       "sdd": {
#         "type": "stdio",
#         "command": "python3",
#         "args": ["/abs/path/to/extensions/sdd-mcp-server/server.py"]
#       }
#     }
#   }
#
# If `jq` is available we mutate the file; otherwise we fall back to
# writing a fresh file when none exists, and printing manual-edit
# instructions when one does.

set -euo pipefail

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVER_PATH="$HERE/server.py"

if [ ! -f "$SERVER_PATH" ]; then
  echo "error: server.py not found at $SERVER_PATH" >&2
  exit 1
fi

# Make server.py executable so `python3 server.py` works regardless of perms.
chmod +x "$SERVER_PATH"

# Decide where to write. Default: per-project (committable).
TARGET="${SDD_MCP_TARGET:-project}"
case "$TARGET" in
  project) CONFIG_PATH="$(pwd)/.mcp.json" ;;
  user)    CONFIG_PATH="$HOME/.claude.json" ;;
  *)
    echo "error: SDD_MCP_TARGET must be 'project' or 'user' (got '$TARGET')" >&2
    exit 1
    ;;
esac

read -r -d '' SDD_BLOCK <<EOF || true
{
  "mcpServers": {
    "sdd": {
      "type": "stdio",
      "command": "python3",
      "args": ["$SERVER_PATH"]
    }
  }
}
EOF

if [ ! -f "$CONFIG_PATH" ]; then
  echo "$SDD_BLOCK" > "$CONFIG_PATH"
  echo "SDD MCP server registered at $CONFIG_PATH."
  echo "Restart Claude Code to activate."
  exit 0
fi

# File exists — try to merge with jq if available.
if command -v jq >/dev/null 2>&1; then
  TMP="$(mktemp)"
  jq --arg path "$SERVER_PATH" '
    .mcpServers = (.mcpServers // {}) |
    .mcpServers.sdd = {
      "type": "stdio",
      "command": "python3",
      "args": [$path]
    }
  ' "$CONFIG_PATH" > "$TMP" && mv "$TMP" "$CONFIG_PATH"
  echo "SDD MCP server registered in $CONFIG_PATH."
  echo "Restart Claude Code to activate."
  exit 0
fi

# No jq — print manual-edit instructions.
cat <<EOF
$CONFIG_PATH already exists and 'jq' is not installed.

Add this to its "mcpServers" object manually, then restart Claude Code:

  "sdd": {
    "type": "stdio",
    "command": "python3",
    "args": ["$SERVER_PATH"]
  }

Or install jq and re-run this script:
  brew install jq    # macOS
  apt-get install jq # Debian/Ubuntu

EOF
exit 0
