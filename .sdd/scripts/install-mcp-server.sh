#!/usr/bin/env bash
# install-mcp-server.sh — actually register the SDD MCP server at /sdd-setup
# (closes #209 — F01 of pipelogic_v2 had `parameters.mcp.enabled: true` in
# config.md but `.mcp.json` was never written; the 40-60% token saving the
# wizard promised silently never materialised).
#
# Called by /sdd-setup after brick 007 (mcp-server) is answered, and any time
# /sdd-config 007-mcp-server is re-run. Reads `parameters.mcp.enabled` from
# `.sdd/config.md`. If true: invokes the project's
# `extensions/sdd-mcp-server/enable.sh` (which writes `.mcp.json`), then
# verifies the registration landed. If false / deferred / missing: self-skips
# silently so the wizard prose can call it unconditionally.
#
# Same shape as #199's install-ci-workflow.sh — wizard records the answer,
# THIS script actually does the install.
#
# Usage:
#   install-mcp-server.sh [--force] [--quiet]
#
# Flags:
#   --force   re-run even if `.mcp.json` already has an `sdd` mcpServer entry.
#             Default is to preserve existing registrations (idempotent skip).
#   --quiet   suppress the success line on stdout. Used when called from the
#             wizard prose so the agent's own confirmation is the
#             user-facing surface.
#
# Exit:
#   0 — server registered, preserved (already present), or deferred (Q1 = no)
#   1 — error (enable.sh missing, .mcp.json verification failed)
#   2 — usage error

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FORCE=0
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    --quiet) QUIET=1 ;;
    -h|--help)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *)
      echo "install-mcp-server.sh: unrecognised flag '$1'" >&2
      exit 2
      ;;
  esac
  shift
done

say() {
  [ "$QUIET" -eq 1 ] || echo "$1"
}

CONFIG_MD="$PROJECT_DIR/.sdd/config.md"
ENABLE_SH="$PROJECT_DIR/extensions/sdd-mcp-server/enable.sh"
MCP_JSON="$PROJECT_DIR/.mcp.json"

if [ ! -f "$CONFIG_MD" ]; then
  echo "[install-mcp-server] no config.md at $CONFIG_MD" >&2
  echo "[install-mcp-server] run /sdd-setup first to create it." >&2
  exit 1
fi

# Read parameters.mcp.enabled from config.md frontmatter.
# Tolerates: `enabled: true`, `enabled:true`, `enabled : true`, plus comment trail.
mcp_enabled=$(python3 - "$CONFIG_MD" <<'PYEOF'
import sys, re
try:
    import yaml
except ImportError:
    print("MISSING_YAML"); sys.exit(0)
text = open(sys.argv[1], encoding="utf-8").read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
if not m:
    print("UNKNOWN"); sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    print("UNKNOWN"); sys.exit(0)
val = (fm.get("parameters", {}) or {}).get("mcp", {}).get("enabled")
if val is True:
    print("true")
elif val is False:
    print("false")
else:
    print("UNKNOWN")
PYEOF
)

case "$mcp_enabled" in
  true)
    : # proceed
    ;;
  false)
    say "[install-mcp-server] brick 007 answered 'no' — skipping (parameters.mcp.enabled: false)."
    say "[install-mcp-server] re-run /sdd-config 007-mcp-server to change your mind."
    exit 0
    ;;
  MISSING_YAML)
    echo "[install-mcp-server] PyYAML missing — can't read config.md frontmatter." >&2
    echo "[install-mcp-server] run: pip3 install --user PyYAML, then re-run." >&2
    exit 1
    ;;
  UNKNOWN|*)
    say "[install-mcp-server] parameters.mcp.enabled not set yet — skipping."
    say "[install-mcp-server] run /sdd-config 007-mcp-server to answer the question."
    exit 0
    ;;
esac

# Idempotent skip: if `.mcp.json` already has an `sdd` mcpServer entry, no work.
if [ -f "$MCP_JSON" ] && [ "$FORCE" -ne 1 ]; then
  if python3 - "$MCP_JSON" <<'PYEOF' 2>/dev/null
import sys, json
data = json.load(open(sys.argv[1]))
servers = data.get("mcpServers", {}) or {}
sys.exit(0 if "sdd" in servers else 1)
PYEOF
  then
    say "[install-mcp-server] $MCP_JSON already has 'sdd' mcpServer — preserving."
    say "[install-mcp-server] re-run with --force to overwrite, or hand-edit."
    exit 0
  fi
fi

# enable.sh must exist. sdd-init.sh symlinks extensions/sdd-mcp-server/ from
# the plugin install; if the symlink is broken / missing, surface clearly.
if [ ! -f "$ENABLE_SH" ]; then
  echo "[install-mcp-server] expected enable.sh at $ENABLE_SH but it's missing." >&2
  echo "[install-mcp-server] this means the framework's MCP server symlink didn't land." >&2
  echo "[install-mcp-server] re-run bin/sdd-init.sh, or symlink by hand:" >&2
  echo "[install-mcp-server]   ln -sfn \$PLUGIN_ROOT/extensions/sdd-mcp-server $PROJECT_DIR/extensions/sdd-mcp-server" >&2
  exit 1
fi

# Run enable.sh. It handles writing .mcp.json + chmod-ing server.py.
if ! ( cd "$PROJECT_DIR" && CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$ENABLE_SH" ) >/dev/null 2>&1; then
  echo "[install-mcp-server] enable.sh failed — re-running with output:" >&2
  ( cd "$PROJECT_DIR" && CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$ENABLE_SH" ) >&2 || true
  exit 1
fi

# Verify .mcp.json now has the sdd mcpServer entry.
if [ ! -f "$MCP_JSON" ]; then
  echo "[install-mcp-server] enable.sh ran but $MCP_JSON wasn't written." >&2
  echo "[install-mcp-server] check enable.sh's output for the actual error." >&2
  exit 1
fi

if ! python3 - "$MCP_JSON" <<'PYEOF' 2>/dev/null
import sys, json
data = json.load(open(sys.argv[1]))
servers = data.get("mcpServers", {}) or {}
sys.exit(0 if "sdd" in servers else 1)
PYEOF
then
  echo "[install-mcp-server] $MCP_JSON exists but has no 'sdd' mcpServer entry." >&2
  echo "[install-mcp-server] enable.sh wrote a malformed registration — please report." >&2
  exit 1
fi

say "[install-mcp-server] registered — $MCP_JSON now has the 'sdd' mcpServer entry."
say "[install-mcp-server] the 40-60% token saving from brick 007 will fire on your next session."
exit 0
