#!/usr/bin/env bash
# SDD PreToolUse hook for Bash.
# Refuses `git commit` if the active feature's current phase has open `[ ]` blockers.
# Silent pass-through for non-commit Bash commands and for projects without .sdd/.
#
# Input: JSON on stdin with fields { tool_name, tool_input: { command: "..." } }
# Output:
#   exit 0 = allow
#   exit 2 = block (stderr shown to agent)

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

# Parse the tool input. We only care about `git commit` invocations.
input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Not a git commit? Allow.
case "$cmd" in
  *"git commit"*) ;;   # fall through to the check
  *) exit 0 ;;
esac

# No SDD setup? Allow.
if [ ! -d .sdd ] || [ ! -f .sdd/INDEX.md ]; then
  exit 0
fi

# No active feature? Allow (initial commits, scaffolding, etc.)
active_path=$(grep -m1 -E '^\*\*Active:\*\*' .sdd/INDEX.md | grep -oE 'features/[A-Za-z0-9._-]+' | head -1 || echo "")
if [ -z "$active_path" ]; then
  exit 0
fi

spec=".sdd/$active_path/spec.md"
if [ ! -f "$spec" ]; then
  exit 0
fi

# Bootstrap exception: if the active feature's spec.md is being newly ADDED in this commit
# (status A — never existed at HEAD), this is the bootstrap commit. The fresh spec is full
# of `[ ]` placeholders by definition. Allow.
spec_status=$(git diff --cached --name-status -- "$spec" 2>/dev/null | awk '{print $1}' | head -1)
if [ "$spec_status" = "A" ]; then
  exit 0
fi

phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" | grep -oE '[A-Z]+' | tail -1 || echo "SPEC")

# Extract the current phase section and search for `[ ]` (open blocker).
phase_section=$(awk -v ph="## PHASE: $phase" '
  $0 ~ ph {found=1}
  found && /^## PHASE:/ && $0 !~ ph {exit}
  found {print}
' "$spec")

# Check for open blockers. We treat `[ ]` at the start of a line or inline as a blocker,
# but ignore commented-out regions (lines starting with `<!--` or inside HTML comments).
# For simplicity we filter out lines that start with `<!--` or `-->`.
open_blockers=$(printf '%s\n' "$phase_section" | grep -n -E '\[ \]' | grep -v -E '^\s*<!--' | head -5 || true)

if [ -n "$open_blockers" ]; then
  {
    echo "[SDD] Commit blocked: the active feature has open \`[ ]\` blockers in the current phase."
    echo ""
    echo "  Feature: $active_path"
    echo "  Phase:   $phase"
    echo ""
    echo "  Open blockers (first 5):"
    printf '%s\n' "$open_blockers" | sed 's/^/    /'
    echo ""
    echo "  Either fill the blockers (preferred), or — if this commit legitimately"
    echo "  shouldn't be gated (e.g. a fix on main, not tied to a feature) — temporarily"
    echo "  clear the \`**Active:**\` line in .sdd/INDEX.md and retry."
  } >&2
  exit 2
fi

exit 0
