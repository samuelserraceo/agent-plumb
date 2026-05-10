#!/usr/bin/env bash
# T209 — AC10 — pi-mcp-adapter integration: when pi-mcp-adapter is
# installed and .pi/mcp.json references the SDD MCP server, the SDD
# MCP tools become reachable via pi's mcp proxy.
#
# Why a structural test, not an end-to-end one: pi-mcp-adapter is a
# community npm package and the actual proxy hop (pi.dev <-> adapter
# <-> stdio MCP server) requires a live pi.dev runtime. The framework
# proves AC10 by owning the only piece in its scope — the wiring
# script that produces a .pi/mcp.json with the shape pi-mcp-adapter
# consumes (the same shape Claude Code's .mcp.json uses, which the
# sibling SDD MCP server's enable.sh already produces).
#
# T209 verifies four things:
#
#   A) extensions/sdd-pi-extension/scripts/enable-pi-mcp.sh exists.
#      This is the user-facing entry point — colleagues run it once
#      after `pi install npm:pi-mcp-adapter` to wire SDD's MCP server
#      into .pi/mcp.json.
#
#   B) On a fresh project, running enable-pi-mcp.sh produces a valid
#      JSON file at .pi/mcp.json with the MCP-standard shape:
#      {"mcpServers": {"sdd": {"type": "stdio", "command": <python>,
#                              "args": [<abs path to server.py>]}}}.
#      That's exactly what pi-mcp-adapter reads to spawn the server,
#      mirroring the .mcp.json shape Claude Code already consumes.
#
#   C) The args[0] path resolves to a real file — the SDD MCP server
#      at extensions/sdd-mcp-server/server.py. Without this, pi would
#      try to spawn a non-existent process and the proxy would fail.
#
#   D) Idempotence — re-running the script on an existing .pi/mcp.json
#      that already contains a non-sdd entry preserves that entry
#      (merge, not overwrite). User-managed MCP servers must survive
#      the second run unchanged.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
EXT_ROOT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension"
SCRIPT="$EXT_ROOT/scripts/enable-pi-mcp.sh"
SDD_MCP_SERVER="$FRAMEWORK_ROOT/extensions/sdd-mcp-server/server.py"

fails=()

# --- A) Script exists -----------------------------------------------
if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: T209 — scripts/enable-pi-mcp.sh missing at $SCRIPT"
  exit 1
fi

# --- B) Fresh-project run produces .pi/mcp.json with correct shape --
WORK="$(mktemp -d -t sdd-t209.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PROJECT="$WORK/project"
mkdir -p "$PROJECT"

(
  cd "$PROJECT" && \
  bash "$SCRIPT" --project "$PROJECT" >/dev/null 2>&1
)
rc=$?
[ "$rc" -eq 0 ] || fails+=("fresh-project run exited non-zero ($rc)")

CONFIG="$PROJECT/.pi/mcp.json"
if [ ! -f "$CONFIG" ]; then
  fails+=("fresh-project run did not create .pi/mcp.json at $CONFIG")
else
  # Validate JSON + shape with python (no jq dep).
  python3 - "$CONFIG" "$SDD_MCP_SERVER" <<'PY' || fails+=("shape check failed (see python errors above)")
import json, os, sys
cfg_path, expected_server = sys.argv[1], sys.argv[2]
with open(cfg_path) as f:
    cfg = json.load(f)
servers = cfg.get("mcpServers") or {}
sdd = servers.get("sdd")
if not sdd:
    print(f"missing mcpServers.sdd in {cfg_path}", file=sys.stderr); sys.exit(1)
if sdd.get("type") != "stdio":
    print(f"mcpServers.sdd.type must be 'stdio' (got {sdd.get('type')!r})", file=sys.stderr); sys.exit(1)
cmd = sdd.get("command")
if not cmd or "python" not in os.path.basename(cmd):
    print(f"mcpServers.sdd.command must be a python interpreter (got {cmd!r})", file=sys.stderr); sys.exit(1)
args = sdd.get("args") or []
if not args:
    print("mcpServers.sdd.args must include the SDD MCP server path", file=sys.stderr); sys.exit(1)
# --- C) args[0] resolves to the real SDD MCP server -----------------
if os.path.realpath(args[0]) != os.path.realpath(expected_server):
    print(f"mcpServers.sdd.args[0]={args[0]!r} does not resolve to {expected_server!r}", file=sys.stderr); sys.exit(1)
PY
fi

# --- D) Idempotence: pre-existing non-sdd entry survives merge ------
PROJECT2="$WORK/project2"
mkdir -p "$PROJECT2/.pi"
cat > "$PROJECT2/.pi/mcp.json" <<'EOF'
{
  "mcpServers": {
    "user-other": {
      "type": "stdio",
      "command": "node",
      "args": ["/path/to/user-other-server.js"]
    }
  }
}
EOF

(
  cd "$PROJECT2" && \
  bash "$SCRIPT" --project "$PROJECT2" >/dev/null 2>&1
)
rc=$?
[ "$rc" -eq 0 ] || fails+=("merge run exited non-zero ($rc)")

python3 - "$PROJECT2/.pi/mcp.json" <<'PY' || fails+=("merge preserved-entry check failed")
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
servers = cfg.get("mcpServers") or {}
if "user-other" not in servers:
    print("merge run dropped the pre-existing 'user-other' MCP entry", file=sys.stderr); sys.exit(1)
if "sdd" not in servers:
    print("merge run did not add the 'sdd' MCP entry", file=sys.stderr); sys.exit(1)
if servers["user-other"].get("command") != "node":
    print("merge run mutated the pre-existing 'user-other' entry", file=sys.stderr); sys.exit(1)
PY

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T209 — AC10 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T209 — AC10 enable-pi-mcp.sh wires .pi/mcp.json with stdio shape pi-mcp-adapter consumes; merge preserves user entries"
