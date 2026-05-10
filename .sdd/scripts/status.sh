#!/usr/bin/env bash
# status.sh — emit phase + blocker + suggested next action for /sdd-status.
#
# Single source of truth for the pi.dev /sdd-status instant zero-LLM
# command (registered via pi.registerCommand in the sdd-pi extension).
# Pure shell + python3 — no LLM round-trip — so the command returns
# immediately and is safe to call from any harness that can shell out.
#
# Behaviour:
#   - .sdd/ missing OR resolver missing → emit EC#8 fallback, exit 0.
#   - resolver returns no active feature → fall through to status-banner.sh
#     (which prints the right "ambiguous" / "broken pointer" / "scaffold
#     pending" / "no work item" sub-case in plain English).
#   - active feature present → emit "Phase:", "Blocker:", "Next:" lines.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SDD_DIR="$PROJECT_DIR/.sdd"
RESOLVER="$SDD_DIR/scripts/resolve-active.sh"

if [ ! -d "$SDD_DIR" ] || [ ! -f "$RESOLVER" ]; then
  echo "no SDD project found — run /sdd-start to initialise"
  exit 0
fi

resolve_json=$(bash "$RESOLVER" 2>/dev/null || echo '{}')
active=$(printf '%s' "$resolve_json" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("active") or "")
except Exception:
    print("")
' 2>/dev/null)

if [ -z "$active" ]; then
  banner="$SDD_DIR/scripts/status-banner.sh"
  if [ -f "$banner" ]; then
    bash "$banner" --from-resolver
  else
    echo "no SDD project found — run /sdd-start to initialise"
  fi
  exit 0
fi

spec="$SDD_DIR/$active/spec.md"
if [ ! -f "$spec" ]; then
  echo "no SDD project found — run /sdd-start to initialise"
  exit 0
fi

phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" | grep -oE '[A-Z]+' | tail -1)
echo "Phase: ${phase:-?}"

blocker=$(grep -m1 -E '^\*\*Active blocker:\*\*' "$spec" | sed -E 's/^\*\*Active blocker:\*\*[[:space:]]*//')
echo "Blocker: ${blocker:-(none — first open step in this phase)}"

na_json=$(bash "$SDD_DIR/scripts/next-action.sh" "$spec" 2>/dev/null || echo '{}')
printf '%s' "$na_json" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    d = {}
if not isinstance(d, dict):
    d = {}
phase = d.get("phase") or "?"
action = d.get("action") or ""
step = d.get("step") or ""
tag = d.get("tag") or "?"
if d.get("transition"):
    print(f"Next: phase {phase} — all step rows filled, run /sdd-next to advance")
elif action and step:
    print(f"Next: {action}/{step} ({tag}) — run /sdd-next")
else:
    print("Next: run /sdd-next to start the first step")
'
