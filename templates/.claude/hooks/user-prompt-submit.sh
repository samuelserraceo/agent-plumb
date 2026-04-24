#!/usr/bin/env bash
# SDD UserPromptSubmit hook.
# Injects the current workflow state at the top of the agent's context
# on EVERY turn, so the agent cannot forget where we are.
#
# Output strategy:
#   - Emit INDEX.md (entire file; it's tiny by design)
#   - Emit a compact summary of the active feature's spec.md:
#       * header (feature name + phase + blocker)
#       * the current phase section verbatim
#   - Emit patterns.md (tiny, always relevant)

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

# Silent pass-through if SDD is not set up.
if [ ! -d .sdd ] || [ ! -f .sdd/INDEX.md ]; then
  exit 0
fi

echo "=== SDD STATE (injected by hook — do not ignore) ==="
echo ""
echo "--- .sdd/INDEX.md ---"
cat .sdd/INDEX.md
echo ""

# Active feature?
active_path=$(grep -m1 -E '^\*\*Active:\*\*' .sdd/INDEX.md | grep -oE 'features/[A-Za-z0-9._-]+' | head -1 || echo "")

if [ -n "$active_path" ] && [ -f ".sdd/$active_path/spec.md" ]; then
  spec=".sdd/$active_path/spec.md"
  phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" | grep -oE '[A-Z]+' | tail -1 || echo "SPEC")

  echo "--- $spec (header + PHASE: $phase section) ---"
  # Header: everything up to the first `## PHASE:` line
  awk '/^## PHASE:/ {exit} {print}' "$spec"

  # Current phase section: from `## PHASE: <phase>` until the next `## PHASE:` or EOF
  awk -v ph="## PHASE: $phase" '
    $0 ~ ph {found=1}
    found && /^## PHASE:/ && $0 !~ ph {exit}
    found {print}
  ' "$spec"
  echo ""
fi

if [ -f .sdd/patterns.md ]; then
  echo "--- .sdd/patterns.md ---"
  cat .sdd/patterns.md
  echo ""
fi

echo "=== END SDD STATE ==="
