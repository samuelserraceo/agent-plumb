#!/usr/bin/env bash
# enable-pi-mcp.sh — wire the SDD MCP server into pi.dev via
# pi-mcp-adapter (community MCP bridge).
#
# Pi-mcp-adapter consumes .pi/mcp.json with the same {mcpServers: {...}}
# shape Claude Code uses for .mcp.json. This script writes/merges that
# file so the SDD MCP server is reachable from pi via the adapter's
# proxy, without disturbing any user-managed MCP entries already present.
#
# Run once after `pi install npm:pi-mcp-adapter`. Re-running is safe.
#
# Flags:
#   --project <dir>   project root that owns .pi/ (defaults to git root
#                     or pwd)

set -uo pipefail

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SDD_MCP_SERVER="$( cd "$HERE/../../sdd-mcp-server" 2>/dev/null && pwd )/server.py"

if [ ! -f "$SDD_MCP_SERVER" ]; then
  echo "[sdd-pi] sdd-mcp-server/server.py not found at $SDD_MCP_SERVER" >&2
  exit 1
fi

project=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        echo "[sdd-pi] --project requires a directory argument" >&2
        exit 2
      fi
      project="$2"
      shift 2
      ;;
    *) echo "[sdd-pi] unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$project" ]; then
  project="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

PYBIN="$(command -v python3 || echo python3)"
mkdir -p "$project/.pi"
CONFIG="$project/.pi/mcp.json"

python3 - "$CONFIG" "$PYBIN" "$SDD_MCP_SERVER" <<'PY'
import json, os, sys
cfg_path, pybin, server = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = {}
if os.path.exists(cfg_path):
    with open(cfg_path) as f:
        try:
            cfg = json.load(f)
        except json.JSONDecodeError:
            print(f"[sdd-pi] {cfg_path} is not valid JSON; refusing to clobber", file=sys.stderr)
            sys.exit(1)
if not isinstance(cfg, dict):
    print(f"[sdd-pi] {cfg_path} must contain a JSON object at top level", file=sys.stderr)
    sys.exit(1)
servers = cfg.get("mcpServers")
if servers is None:
    servers = {}
    cfg["mcpServers"] = servers
elif not isinstance(servers, dict):
    print(f"[sdd-pi] {cfg_path} has non-object mcpServers; refusing to clobber", file=sys.stderr)
    sys.exit(1)
servers["sdd"] = {"type": "stdio", "command": pybin, "args": [server]}
with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY

echo "[sdd-pi] SDD MCP server wired into $CONFIG (pi-mcp-adapter will surface its tools)."
