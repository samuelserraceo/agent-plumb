#!/usr/bin/env bash
# SDD PreToolUse hook — soft warning (does NOT block).
# If the staged commit modifies CLAUDE.md AND the modification touches anything
# inside the SDD-MANAGED-START / SDD-MANAGED-END markers, AND .sdd/CLAUDE.version
# was NOT also bumped in the same commit → print a prominent stderr warning.
#
# Rationale: edits inside the MANAGED block will be overwritten by `scripts/update.sh`.
# A version bump signals deliberate customization. Project-specific rules belong
# BELOW the END marker.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# CLAUDE.md staged?
staged=$(git diff --cached --name-only 2>/dev/null || echo "")
echo "$staged" | grep -qx 'CLAUDE.md' || exit 0

# Check the diff for additions inside the managed block.
# We pull the staged diff for CLAUDE.md and look for additions (lines starting with +)
# that fall between SDD-MANAGED-START and SDD-MANAGED-END.
diff=$(git diff --cached -- CLAUDE.md 2>/dev/null || echo "")

managed_change=$(printf '%s\n' "$diff" | awk '
  /^@@/ { hunk=1; in_managed=0; next }
  hunk && /SDD-MANAGED-START/ { in_managed=1; next }
  hunk && /SDD-MANAGED-END/ { in_managed=0; next }
  hunk && in_managed && /^[+-][^+-]/ { count++ }
  END { print count+0 }
')

[ "$managed_change" -eq 0 ] && exit 0

# Was .sdd/CLAUDE.version bumped in the same commit?
if echo "$staged" | grep -qx '.sdd/CLAUDE.version'; then
  # Version explicitly bumped — user signaled intent. Allow silently.
  exit 0
fi

{
  echo ""
  echo "  ⚠  SDD warning — you're editing CLAUDE.md's MANAGED section"
  echo ""
  echo "  Edits inside SDD-MANAGED-START / SDD-MANAGED-END will be overwritten"
  echo "  next time you run \`scripts/update.sh\` to pull SDD updates."
  echo ""
  echo "  If you meant to add PROJECT-specific rules (stack, conventions, domain"
  echo "  knowledge, hard project rules), put them BELOW the SDD-MANAGED-END marker"
  echo "  in the \"Project Rules\" section. Those are yours forever."
  echo ""
  echo "  If you genuinely want to customize SDD's workflow rules for this project:"
  echo "    1. Bump the version: edit .sdd/CLAUDE.version (current: $(cat .sdd/CLAUDE.version 2>/dev/null || echo 'unknown'))"
  echo "    2. Stage it: git add .sdd/CLAUDE.version"
  echo "    3. Re-commit. The bump signals deliberate customization."
  echo ""
  echo "  Commit proceeding — this is a warning, not a block."
  echo ""
} >&2

exit 0
