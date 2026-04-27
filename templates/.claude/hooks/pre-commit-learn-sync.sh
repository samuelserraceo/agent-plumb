#!/usr/bin/env bash
# SDD PreToolUse hook.
# When the active feature is in LEARN phase and the commit touches substantive LEARN content
# (the "## What shipped" or "## Lessons" sections of spec.md), require BOTH:
#   - .sdd/patterns.md staged   (cross-feature learnings)
#   - .sdd/INDEX.md staged      (live state: shipped list + deviations + environments)
# in the same commit. No duplicate sources of institutional memory.
#
# Skipped when the only change to spec.md is the phase marker flip (BUILD → LEARN) — ship.sh
# does that on its own and pre-populates both files; this hook catches *subsequent* LEARN commits.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

[ ! -d .sdd ] || [ ! -f .sdd/INDEX.md ] && exit 0

active=$(awk '/^\*\*Active:\*\*/{print $2; exit}' .sdd/INDEX.md 2>/dev/null || echo "")
case "$active" in *"(none)"*|"_"*"_"|"") active="" ;; esac
[ -z "$active" ] && exit 0

spec=".sdd/$active/spec.md"
[ ! -f "$spec" ] && exit 0

phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" | grep -oE '[A-Z]+' | tail -1 || echo "")
[ "$phase" != "LEARN" ] && exit 0

# Is this commit adding content to the LEARN section of spec.md?
# We check: does the staged diff of spec.md include additions between "## PHASE: LEARN" and the next "## PHASE:" (or EOF)?
diff_spec=$(git diff --cached -- "$spec" 2>/dev/null || echo "")
learn_additions=$(printf '%s\n' "$diff_spec" | awk '
  /^@@/ { hunk=1; next }
  hunk && /^\+## PHASE: LEARN/ { in_learn=1; next }
  hunk && /^\+## PHASE:/ && !/LEARN/ { in_learn=0 }
  hunk && / ## PHASE: LEARN/ { in_learn=1; next }
  hunk && / ## PHASE:/ && !/LEARN/ { in_learn=0 }
  in_learn && /^\+[^+]/ && !/^\+\s*$/ && !/^\+<!--/ { count++ }
  END { print count+0 }
')

# If no substantive LEARN additions, skip enforcement (lets phase-marker-only commits through).
[ "$learn_additions" -eq 0 ] && exit 0

# LEARN content being added — enforce the sync.
staged=$(git diff --cached --name-only 2>/dev/null || echo "")

missing=()
echo "$staged" | grep -qx '.sdd/patterns.md' || missing+=(".sdd/patterns.md")
echo "$staged" | grep -qx '.sdd/INDEX.md' || missing+=(".sdd/INDEX.md")

if [ ${#missing[@]} -gt 0 ]; then
  {
    echo "[SDD] LEARN commit blocked — institutional memory must be updated in the same commit."
    echo ""
    echo "  Feature: $active"
    echo "  Phase:   LEARN"
    echo ""
    echo "  Missing from this commit:"
    for m in "${missing[@]}"; do
      echo "    - $m"
    done
    echo ""
    echo "  LEARN isn't done until cross-feature memory is updated. Reason:"
    echo "  - patterns.md must capture at least one reusable learning from this feature"
    echo "  - INDEX.md must record what is now live (Shipped list + deviations + environments)"
    echo ""
    echo "  Update both files, then:"
    for m in "${missing[@]}"; do
      echo "    git add $m"
    done
    echo "  git commit ..."
  } >&2
  exit 2
fi

exit 0
