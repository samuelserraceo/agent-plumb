#!/usr/bin/env bash
# SDD PreToolUse hook — size caps (warning, not blocker).
#
# Watches three files for runaway growth:
#   - .sdd/patterns.md       soft warn at 250 lines, alarm at 300
#   - .sdd/INDEX.md          soft warn at 200 lines
#   - .sdd/data-model.md     soft warn at 500 lines (suggest split to data-model/ directory)
#
# Prints a stderr nudge on every git commit when a threshold is crossed. Does NOT block
# the commit — pressure, not refusal. Once the user runs /compress (or splits data-model)
# the file shrinks and the warning stops.

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

warned=0

check_file() {
  local path="$1"
  local soft="$2"
  local hard="$3"
  local advice="$4"
  [ ! -f "$path" ] && return 0
  local lines
  lines=$(wc -l < "$path" | tr -d ' ')
  if [ "$lines" -ge "$hard" ]; then
    {
      echo ""
      echo "  ⚠  SDD size-cap (HARD) — $path is $lines lines (cap: $hard)"
      echo "     $advice"
    } >&2
    warned=1
  elif [ "$lines" -ge "$soft" ]; then
    {
      echo ""
      echo "  i  SDD size-cap (soft) — $path is $lines lines (warn: $soft, hard cap: $hard)"
      echo "     $advice"
    } >&2
    warned=1
  fi
}

check_file ".sdd/patterns.md"   250 300 "Run /compress patterns to consolidate duplicates and snapshot old entries to .sdd/archive/."
check_file ".sdd/INDEX.md"      170 220 "Old shipped entries should move to .sdd/archive/. /ship will offer this once a quarter."
check_file ".sdd/data-model.md" 400 500 "Approaching the 500-line threshold for splitting into a data-model/ directory (one file per entity). Announce the migration to the user before doing it."

[ "$warned" -eq 1 ] && echo "" >&2

exit 0
