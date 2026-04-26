#!/usr/bin/env bash
# SDD PreToolUse hook for Bash.
# Refuses `git commit` ONLY when it's a phase-advance commit and the SOURCE
# phase (the one being left) still has open `[ ]` blockers. Per-section
# commits during a phase pass through — that's the documented workflow.
# Silent pass-through for non-commit Bash and for projects without .sdd/.
#
# Phase-advance detection (either signal triggers the check):
#   - Commit message contains `phase:` (convention: `[SDD:<id>] phase: X → Y`)
#   - Staged diff of spec.md changes the `[PHASE: X]` line
#
# Input:  JSON on stdin with fields { tool_name, tool_input: { command: "..." } }
# Output: exit 0 = allow,  exit 2 = block (stderr shown to agent)

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

# Parse the tool input. We only care about `git commit` invocations.
input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Empty-cmd safe default (consistent with the moat hook's catastrophic-#4 fix).
[ -z "$cmd" ] && exit 0

# Not a git commit? Allow.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# No SDD setup? Allow.
if [ ! -d .sdd ] || [ ! -f .sdd/INDEX.md ]; then
  exit 0
fi

# No active feature? Allow.
active_path=$(grep -m1 -E '^\*\*Active:\*\*' .sdd/INDEX.md | grep -oE 'features/[A-Za-z0-9._-]+' | head -1 || echo "")
[ -z "$active_path" ] && exit 0

spec=".sdd/$active_path/spec.md"
[ ! -f "$spec" ] && exit 0

# Bootstrap exception: spec.md being newly ADDED in this commit is the bootstrap.
spec_status=$(git diff --cached --name-status -- "$spec" 2>/dev/null | awk '{print $1}' | head -1)
[ "$spec_status" = "A" ] && exit 0

# Phase-advance detection. Per-section commits skip the open-blocker check.
# The commit-message signal must be ANCHORED to the SDD subject convention
# (`[SDD:<id>] phase: X → Y`) so the word "phase" mentioned anywhere in the
# message body — e.g. when documenting the commit's behaviour — doesn't false-
# trigger the gate. The diff signal catches commits that bypass the convention.
phase_advance=0
if echo "$cmd" | grep -Eq '\[SDD:[^]]+\][[:space:]]*phase:[[:space:]]*[A-Z]+'; then
  phase_advance=1
fi
if git diff --cached -- "$spec" 2>/dev/null | grep -Eq '^[+-]\[PHASE:[[:space:]]*[A-Z]+\]'; then
  phase_advance=1
fi
[ $phase_advance -eq 0 ] && exit 0

# It IS a phase-advance commit. Read the SOURCE phase from HEAD (the phase
# this commit is leaving), then check the STAGED spec for residual `[ ]` in
# that phase's section. The moat (pre-commit-stage-verified.sh) handles
# verification.json honesty separately.
source_phase=$(git show "HEAD:$spec" 2>/dev/null | grep -m1 -oE '\[PHASE:[[:space:]]*[A-Z]+\]' | grep -oE '[A-Z]+' | tail -1 || echo "")
[ -z "$source_phase" ] && exit 0

# Phase body in the staged spec, fence-aware (F3 fix — same as next-action.sh).
phase_section=$(git show ":$spec" 2>/dev/null | awk -v ph="## PHASE: $source_phase" '
  $0 ~ ph {found=1; next}
  found && /^## PHASE:/ {exit}
  found {print}
')

# Skip work-item placeholders (same shape as next-action.sh): `- [ ] AC<N>`,
# `- [ ] T<N>`, `- [ ] C-...` are not rubric blockers — they're intentionally
# RED until BUILD turns them GREEN.
open_blockers=$(printf '%s\n' "$phase_section" | awk '
  /^[[:space:]]*```/ { in_fence = !in_fence; next }
  in_fence == 1 { next }
  /^[[:space:]]*-[[:space:]]*\[ \][[:space:]]+(AC|T|C-)[A-Za-z0-9_-]/ { next }
  /\[ \]/ { print NR ": " $0 }
' | head -5)

if [ -n "$open_blockers" ]; then
  {
    echo "[SDD] Phase-advance blocked: $source_phase still has open \`[ ]\` blockers."
    echo ""
    echo "  Feature: $active_path"
    echo "  Leaving phase: $source_phase"
    echo ""
    echo "  Open blockers (first 5):"
    printf '%s\n' "$open_blockers" | sed 's/^/    /'
    echo ""
    echo "  Fill those blockers (or /skip a [SKIPPABLE] section), then retry."
    echo "  Per-section commits during a phase are allowed — only the phase-advance"
    echo "  commit is gated."
  } >&2
  exit 2
fi

exit 0
