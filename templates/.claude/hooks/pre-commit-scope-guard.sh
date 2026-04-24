#!/usr/bin/env bash
# SDD PreToolUse hook — scope guard.
# Blocks BUILD-phase commits that add user-facing copy strings (≥30 chars) to
# .tsx/.jsx/.ts/.js files that do NOT appear anywhere in:
#   - the active feature's wireframe.html, or
#   - the active feature's spec.md (any section).
#
# Purpose: prevent the "agent invented a feature/counter/copy that was never spec'd"
# class of drift — e.g. a fake "47 founders on the wait list" appearing in production
# UI despite no user story or wireframe ever mentioning it.
#
# Not a perfect scanner — heuristic. Short UI primitives (labels, "Submit", "Loading…")
# are intentionally not checked. Anything 30+ chars is treated as brand copy and must
# be traceable to the spec or wireframe.
#
# Escape hatch (for legitimate cases where the matcher misses a real spec reference):
#   SDD_SCOPE_GUARD_OFF=1 git commit ...
# This is recorded via the commit's environment and auditable after the fact.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Escape hatch — used intentionally, still warn on stderr
if [ "${SDD_SCOPE_GUARD_OFF:-0}" = "1" ]; then
  echo "[SDD] scope-guard bypassed via SDD_SCOPE_GUARD_OFF=1" >&2
  exit 0
fi

[ ! -d .sdd ] || [ ! -f .sdd/INDEX.md ] && exit 0

active=$(grep -m1 -E '^\*\*Active:\*\*' .sdd/INDEX.md | grep -oE 'features/[A-Za-z0-9._-]+' | head -1 || echo "")
[ -z "$active" ] && exit 0

spec=".sdd/$active/spec.md"
[ ! -f "$spec" ] && exit 0

phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" | grep -oE '[A-Z]+' | tail -1 || echo "")
# Only enforce during BUILD and VERIFY (SPEC/PLAN don't have code yet; LEARN shouldn't add new UI)
case "$phase" in
  BUILD|VERIFY) ;;
  *) exit 0 ;;
esac

wireframe=".sdd/$active/wireframe.html"
# If no wireframe exists (skippable for non-UI features), allow.
[ ! -f "$wireframe" ] && exit 0

# Extract candidate strings from staged additions in UI files.
# Matches: quoted strings "..." 30+ chars, JSX text nodes >...< 30+ chars.
added_strings=$(git diff --cached --unified=0 -- '*.tsx' '*.jsx' '*.ts' '*.js' 2>/dev/null \
  | grep -E '^\+' \
  | grep -oE '"[^"]{30,}"|>[^<>]{30,}<' \
  | sed -E 's/^[">]|[<"]$//g' \
  | sort -u \
  || true)

[ -z "$added_strings" ] && exit 0

violations=()
while IFS= read -r str; do
  [ -z "$str" ] && continue
  # Match loosely — try exact, then case-insensitive.
  if grep -qF -- "$str" "$wireframe" 2>/dev/null; then continue; fi
  if grep -qF -- "$str" "$spec" 2>/dev/null; then continue; fi
  if grep -qiF -- "$str" "$wireframe" 2>/dev/null; then continue; fi
  if grep -qiF -- "$str" "$spec" 2>/dev/null; then continue; fi
  violations+=("$str")
done <<< "$added_strings"

if [ ${#violations[@]} -gt 0 ]; then
  {
    echo "[SDD] scope-guard (copy) blocked this commit."
    echo ""
    echo "  Active feature: $active"
    echo "  Phase:          $phase"
    echo "  Wireframe:      $wireframe"
    echo ""
    echo "  The staged .tsx/.jsx changes contain copy strings that are NOT in"
    echo "  the feature's wireframe OR spec.md:"
    for v in "${violations[@]}"; do
      preview=$(echo "$v" | head -c 120)
      echo "    • \"$preview\""
    done
    echo ""
    echo "  This is the \"agent invented a feature\" drift class. Pick one:"
    echo ""
    echo "  1. Legitimate but missed: add the copy/element to wireframe.html,"
    echo "     get it re-approved, then commit again."
    echo "  2. Not requested: remove the unspec'd copy from the source file,"
    echo "     commit again."
    echo "  3. Matcher false positive (rare, usually wrapped/hyphenated text):"
    echo "     SDD_SCOPE_GUARD_OFF=1 git commit ... (audited)."
  } >&2
  exit 2
fi

# ─── Block 2: new UI files must carry a `// spec:` reference ───────────
# Any new .tsx/.jsx/.ts/.js file under app/, components/, pages/ added in this
# commit must include a comment in its first 10 lines like:
#   // spec: features/001-waitlist-signup/spec.md §3 US2 — join form
# If the agent cannot cite the spec line, they cannot commit the file.

new_ui_files=$(git diff --cached --name-only --diff-filter=A 2>/dev/null \
  | grep -E '^(app|components|pages|src/app|src/components|src/pages)/.*\.(tsx|jsx|ts|js)$' \
  | grep -vE '\.test\.|\.spec\.|/tests?/' \
  || true)

[ -z "$new_ui_files" ] && exit 0

missing_ref=()
while IFS= read -r file; do
  [ -z "$file" ] && continue
  # Check first 10 lines for a `spec:` reference pointing at this feature or any spec.md
  if ! head -10 "$file" | grep -qE '(//|/\*|\*).*spec:\s*(features/|\.sdd/|\S+\.md)' ; then
    missing_ref+=("$file")
  fi
done <<< "$new_ui_files"

if [ ${#missing_ref[@]} -gt 0 ]; then
  {
    echo "[SDD] scope-guard (file) blocked this commit."
    echo ""
    echo "  Active feature: $active"
    echo "  Phase:          $phase"
    echo ""
    echo "  The following NEW UI files lack a \`// spec:\` reference in the first 10 lines:"
    for f in "${missing_ref[@]}"; do
      echo "    • $f"
    done
    echo ""
    echo "  Every new component/page/route must trace back to a specific spec line."
    echo "  Add a comment at the top of each file, e.g.:"
    echo ""
    echo "    // spec: $spec §3 US2 — <what this file is for>"
    echo ""
    echo "  If you can't honestly cite a spec line, the file probably shouldn't exist yet."
    echo "  Discuss with the user and add to the spec BEFORE writing the component."
  } >&2
  exit 2
fi

exit 0
