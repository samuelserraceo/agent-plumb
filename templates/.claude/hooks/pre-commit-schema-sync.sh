#!/usr/bin/env bash
# SDD PreToolUse hook.
# If the staged diff MODIFIES a feature spec's Data contract section (adds/changes entities,
# fields, state transitions, edge cases), require .sdd/data-model.md to be staged in the same
# commit. No duplicate sources of schema truth.
#
# IMPORTANT: this hook is NOT triggered by the bootstrap commit that creates a fresh spec.md
# from the rubric template. Newly-added spec.md files have no real Data contract content yet —
# just the rubric's empty headings — so we skip them and only enforce on subsequent edits.

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

# Only consider spec.md files that are MODIFIED in this commit (status M).
# Newly-added spec.md files (status A) are bootstrap copies of rubric.md — every line is
# technically an "addition" but nothing is real schema content yet. Skip them.
modified_specs=$(git diff --cached --name-only --diff-filter=M 2>/dev/null | grep -E '^\.sdd/features/[^/]+/spec\.md$' || echo "")
[ -z "$modified_specs" ] && exit 0

# Detect substantive additions in the Data contract section of any modified spec.
# Heuristic: look for additions that contain real content beyond the empty rubric scaffold.
# We require BOTH a Data contract heading mention AND non-placeholder content (i.e. additions
# that are not just `[ ]`, `<!-- ... -->`, or empty bullet markers).
touched_schema=0
offending_specs=""

# Helper: extract the Data contract section's substantive lines from a spec.md content stream.
# A "substantive" line is a "- **Label:** value" bullet whose value is NOT an empty [ ] placeholder.
extract_substantive_dc() {
  awk '
    /^### [56]\. Data contract/ { in_dc=1; next }
    /^### / && in_dc { in_dc=0 }
    in_dc && /^\s*-\s*\*\*[^*]+:\*\*\s+/ {
      # Skip if value is empty placeholder
      if (/\[ \]\s*$/) next
      # Skip if value is only whitespace
      sub(/^\s*-\s*\*\*[^*]+:\*\*\s+/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if (length($0) == 0) next
      print
    }
  ' | sort -u
}

while IFS= read -r spec; do
  [ -z "$spec" ] && continue

  # Compare BEFORE (HEAD) vs AFTER (working tree, post-staged) of the Data contract section.
  before=$(git show "HEAD:$spec" 2>/dev/null | extract_substantive_dc 2>/dev/null || echo "")
  after=$(extract_substantive_dc < "$spec" 2>/dev/null || echo "")

  # Substantive change = before != after AND after has some content
  if [ "$before" != "$after" ] && [ -n "$after" ]; then
    touched_schema=1
    offending_specs="$offending_specs $spec"
  fi
done <<< "$modified_specs"

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
