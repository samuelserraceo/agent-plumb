#!/usr/bin/env bash
# background-metric.sh — Compute the §2 metric for feature 008.
#
# Reads .sdd/.cache/background-emit.log (or $SDD_CACHE_DIR/background-emit.log)
# and prints the count of "did real work" emits — total emit lines minus
# lines where action_chosen == "none-skipped" or "pending".
#
# Usage:
#   background-metric.sh
#       Prints: "<background-actions>/<total-waits>" — e.g. "12/15"
#
#   background-metric.sh --raw
#       Prints just the background-action count.
#
#   background-metric.sh --total
#       Prints just the total wait count.
#
# Exits 0 always. Empty log = "0/0".

set -uo pipefail

if [ -n "${SDD_CACHE_DIR:-}" ]; then
  CACHE_DIR="$SDD_CACHE_DIR"
else
  REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
  CACHE_DIR="$REPO_ROOT/.sdd/.cache"
fi
LOG="$CACHE_DIR/background-emit.log"

if [ ! -f "$LOG" ]; then
  case "${1:-}" in
    --raw|--total) echo "0" ;;
    *) echo "0/0" ;;
  esac
  exit 0
fi

total=$(wc -l < "$LOG" | tr -d ' ')
# Count lines that claim a real action — anything that isn't pending or
# none-skipped.
real=$(python3 -c "
import json, sys
real = 0
for line in open('$LOG'):
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    ac = d.get('action_chosen', '')
    if ac and ac not in ('pending', 'none-skipped'):
        real += 1
print(real)
")

case "${1:-}" in
  --raw) echo "$real" ;;
  --total) echo "$total" ;;
  *) echo "${real}/${total}" ;;
esac
exit 0
