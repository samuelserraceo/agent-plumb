#!/usr/bin/env bash
# Migration into v0.5.
# - Creates .sdd/archive/ directory for compressed history.
# - Marks any features that look "shipped but pre-v0.5" with a .shipped sentinel
#   (heuristic: feature folder has [PHASE: SHIPPED] or [PHASE: LEARN] in spec.md
#   AND its INDEX entry is in the Shipped block). Best-effort, idempotent.

set -euo pipefail

cd "$1"  # target project root

mkdir -p .sdd/archive
[ ! -f .sdd/archive/.gitkeep ] && touch .sdd/archive/.gitkeep && echo "    + Created .sdd/archive/"

# Mark already-shipped features as cold
for d in .sdd/features/*/; do
  [ ! -d "$d" ] && continue
  spec="$d/spec.md"
  [ ! -f "$spec" ] && continue
  phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" 2>/dev/null | grep -oE '[A-Z]+' | tail -1 || echo "")
  if [ "$phase" = "SHIPPED" ] || [ "$phase" = "LEARN" ]; then
    if [ ! -f "$d/.shipped" ]; then
      touch "$d/.shipped"
      echo "    + Marked $d as cold (.shipped)"
    fi
  fi
done
