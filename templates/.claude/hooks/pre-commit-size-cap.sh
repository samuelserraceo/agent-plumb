#!/usr/bin/env bash
# SDD PreToolUse hook — size caps (Theme 7 tightened thresholds).
#
# Watches the three growth-prone files:
#   - .sdd/patterns.md      warn 200 lines · BLOCK 400 lines
#   - .sdd/INDEX.md         warn 200 lines · BLOCK 400 lines
#   - .sdd/data-model.md    warn 200 lines · BLOCK 400 lines
#
# Phase A behavior: warn-only at older thresholds (250/300, 170/220,
# 400/500). v0.8 Theme 7 tightens BOTH the thresholds (uniform 200/400
# per the handoff) AND the discipline (hard cap now BLOCKS the commit).
#
# Soft warning crossed → stderr nudge with `/compress` hint, exit 0.
# Hard cap crossed → stderr error explaining what to do, exit 2 (BLOCK).
#
# The hard block exists because once these files cross 400 lines they
# stop being readable by the agent in one context window — every /next
# loses signal. Manual compression / archiving / data-model split is
# the only fix; the framework can't auto-shrink without erasing intent.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

[ ! -d .sdd ] && exit 0

# Theme 7 — uniform thresholds across the three growth-prone files.
SOFT_CAP=200
HARD_CAP=400

warned=0
blocked=0

check_file() {
  local path="$1"
  local advice="$2"
  [ ! -f "$path" ] && return 0
  local lines
  lines=$(wc -l < "$path" | tr -d ' ')
  if [ "$lines" -ge "$HARD_CAP" ]; then
    {
      echo ""
      echo "  ⛔ SDD size-cap (HARD BLOCK) — $path is $lines lines (cap: $HARD_CAP)"
      echo "     $advice"
      echo "     Reduce below $HARD_CAP lines before committing."
    } >&2
    blocked=1
  elif [ "$lines" -ge "$SOFT_CAP" ]; then
    {
      echo ""
      echo "  ⚠  SDD size-cap (warn) — $path is $lines lines (warn: $SOFT_CAP, block: $HARD_CAP)"
      echo "     $advice"
    } >&2
    warned=1
  fi
}

check_file ".sdd/patterns.md"   "Run /compress patterns to consolidate duplicates and snapshot old entries to .sdd/archive/."
check_file ".sdd/INDEX.md"      "Old shipped entries should move to .sdd/archive/. /ship will offer this once a quarter."
check_file ".sdd/data-model.md" "Consider splitting into a data-model/ directory (one file per entity)."

[ "$warned" -eq 1 ] && echo "" >&2
[ "$blocked" -eq 1 ] && exit 2

exit 0
