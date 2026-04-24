#!/usr/bin/env bash
# SDD PreToolUse hook.
# If the staged diff modifies a feature spec's Data contract section (adds/changes entities,
# fields, state transitions, edge cases), require .sdd/data-model.md to be staged in the same
# commit. No duplicate sources of schema truth.

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

staged_specs=$(git diff --cached --name-only 2>/dev/null | grep -E '^\.sdd/features/[^/]+/spec\.md$' || echo "")
[ -z "$staged_specs" ] && exit 0

# Detect substantive additions in the Data contract section of any staged spec.
# Heuristic: look for "+" lines referencing the Data contract sub-bullets the rubric defines.
touched_schema=0
offending_specs=""
while IFS= read -r spec; do
  [ -z "$spec" ] && continue
  diff=$(git diff --cached -- "$spec" 2>/dev/null || echo "")
  if echo "$diff" | grep -qE '^\+.*(Entities used from|New entities|State transitions|Edge cases \(nulls|## 5\. Data contract|## 6\. Data contract)'; then
    touched_schema=1
    offending_specs="$offending_specs $spec"
  fi
done <<< "$staged_specs"

[ $touched_schema -eq 0 ] && exit 0

if ! git diff --cached --name-only | grep -qx '.sdd/data-model.md'; then
  {
    echo "[SDD] Data-contract commit blocked — schema is a single source of truth."
    echo ""
    echo "  Feature spec(s) with Data contract changes staged:"
    for s in $offending_specs; do echo "    - $s"; done
    echo ""
    echo "  But .sdd/data-model.md is not staged. Schema lives ONE place."
    echo ""
    echo "  What to do:"
    echo "    1. Open .sdd/data-model.md"
    echo "    2. Apply the entity/field/transition changes from the spec's Data contract section"
    echo "    3. git add .sdd/data-model.md"
    echo "    4. Commit again"
    echo ""
    echo "  If this commit genuinely didn't change schema (e.g. you're just reformatting or"
    echo "  fixing a typo in the Data contract section), stage data-model.md with no changes"
    echo "  to satisfy the hook — it'll be a no-op but the audit trail stays clean."
  } >&2
  exit 2
fi

exit 0
