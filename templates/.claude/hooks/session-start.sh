#!/usr/bin/env bash
# SDD SessionStart hook.
# Prints the current workflow state so the agent (and user) know where we are.
# Silent pass-through if no .sdd/ directory exists.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

if [ ! -d .sdd ]; then
  exit 0
fi

if [ ! -f .sdd/INDEX.md ]; then
  echo "[SDD] .sdd/ directory found but INDEX.md is missing. Run scripts/init.sh." >&2
  exit 0
fi

# Extract active feature from the `**Active:**` pointer line.
active_line=$(grep -m1 -E '^\*\*Active:\*\*' .sdd/INDEX.md || echo "")
active_path=$(echo "$active_line" | grep -oE 'features/[A-Za-z0-9._-]+' | head -1 || echo "")

echo "───── SDD workflow ─────"
if [ -z "$active_path" ]; then
  echo "No active feature. Start one by asking the agent or running /next."
else
  echo "Active: $active_path"
  spec="$PROJECT_DIR/.sdd/$active_path/spec.md"
  if [ -f "$spec" ]; then
    phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" || echo "[PHASE: ?]")
    blocker=$(grep -m1 -E 'Active blocker:' "$spec" | sed -E 's/.*Active blocker:\*{0,2}[[:space:]]*//; s/\*+[[:space:]]*$//' | head -c 120 || echo "")
    echo "Phase:  $phase"
    [ -n "$blocker" ] && echo "Blocker: $blocker"
  else
    echo "  (spec.md not found at $spec — expected for a fresh feature; run /next)"
  fi
fi
echo ""
echo "Commands: /next /status /ship /compress /skip"
echo "────────────────────────"
