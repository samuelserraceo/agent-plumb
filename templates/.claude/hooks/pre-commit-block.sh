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
if [ ! -d .sdd ]; then
  exit 0
fi

# Read INDEX.md from the STAGED blob (not working tree). Reviewer round 3
# found that an agent could blank out the working-tree INDEX.md to make the
# hook see no active feature, then commit a phase advance unblocked. Reading
# from staged makes the hook see what's actually being committed.
staged_index=$(git show ":.sdd/INDEX.md" 2>/dev/null || echo "")
if [ -z "$staged_index" ]; then
  # Fall back to working tree only if INDEX.md is genuinely absent (very early
  # bootstrap before INDEX.md exists). Allow.
  [ -f .sdd/INDEX.md ] || exit 0
  staged_index=$(cat .sdd/INDEX.md)
fi

# No active feature? Allow. Reads the work-item path generically from
# **Active:** <path> rather than hardcoding `features/` — keeps the hook
# multi-playbook capable (Phase C ships bugs/, ideas/, etc.).
active_path=$(printf '%s\n' "$staged_index" | awk '/^\*\*Active:\*\*/{print $2; exit}')
case "$active_path" in *"(none)"*|"_"*"_"|"") active_path="" ;; esac
[ -z "$active_path" ] && exit 0

spec=".sdd/$active_path/spec.md"

# Read spec.md from the STAGED blob into a TEMP FILE. An agent could rm or
# blank the working-tree spec.md while staging a phase advance from a
# different blob via `git update-index`. Reading staged is necessary; the
# CRITICAL detail is that bash command substitution strips NUL bytes
# silently — `$(git show :spec)` would lose any \0 in the staged content.
# Round 4 caught this: NUL bytes in the staged spec must be detected
# before they break the awk regex below, and the only reliable way is to
# write the staged blob to a file (preserves NULs) and run `od -An -c`
# against the file path.
staged_spec_file=$(mktemp)
trap 'rm -f "$staged_spec_file"' EXIT
if ! git show ":$spec" > "$staged_spec_file" 2>/dev/null || [ ! -s "$staged_spec_file" ]; then
  # spec.md not staged in this commit — bootstrap or unrelated commit.
  # Fall back to working tree only if it exists.
  rm -f "$staged_spec_file"
  [ -f "$spec" ] || exit 0
  staged_spec_file=$(mktemp)
  trap 'rm -f "$staged_spec_file"' EXIT
  cp "$spec" "$staged_spec_file"
fi

# NUL-byte / binary guard. Run od against the FILE (preserves NULs), not
# against a bash-stripped variable. Round 4 fix — variable substitution
# was silently dropping NUL bytes, defeating the guard.
if od -An -c "$staged_spec_file" 2>/dev/null | grep -q '\\0'; then
  cat >&2 <<EOF
[SDD] spec.md contains NUL bytes — refusing to commit.
NUL bytes break the phase-advance regex below; a fabricated phase
advance could otherwise slip past this gate. Remove the binary
content from $spec.
EOF
  exit 2
fi
# Now safe to load into a variable for downstream awk usage.
staged_spec_content=$(cat "$staged_spec_file")

# Bootstrap exception: spec.md being newly ADDED in this commit is the bootstrap.
spec_status=$(git diff --cached --name-status -- "$spec" 2>/dev/null | awk '{print $1}' | head -1)
[ "$spec_status" = "A" ] && exit 0

# Phase-advance detection. The diff signal is the truth: if the staged
# spec.md changes the `[PHASE: X]` line, this is a phase-advance commit.
# A commit-message signal was tried earlier and dropped — patterns like
# `[SDD:<id>] phase: X → Y` mentioned anywhere in the message body
# (including when *describing* a fix to the hook itself, or quoting the
# convention as an example) caused false-triggers that blocked unrelated
# per-section commits. The diff catches the only thing that matters
# semantically: did this commit move the phase pointer.
if ! git diff --cached -- "$spec" 2>/dev/null | grep -Eq '^[+-]\[PHASE:[[:space:]]*[A-Z]+\]'; then
  exit 0
fi

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
