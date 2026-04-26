#!/usr/bin/env bash
# next-action.sh — Resolve the next blocker in a SDD spec.md.
#
# Usage:   next-action.sh <path/to/spec.md>
# Output:  JSON to stdout describing the next sub-action.
#          {"phase":"X","sub_action":"<line>","transition":null}
#          {"phase":"X","sub_action":null,"transition":"X→Y"}
#
# Behavior:
#   1. Read [PHASE: X] line at top to find the active phase.
#   2. Find the body of `## PHASE: X` (until the next `## ` heading).
#   3. Walk the body line-by-line, tracking ``` code-fence state.
#   4. Outside fences: return the first line containing `[ ]`.
#   5. If no `[ ]` in the active phase body: emit a transition signal.
#
# Determinism: pure file walk, no $RANDOM, no timestamps, no unsorted set
# iteration. Two invocations on the same spec produce byte-identical output.

set -uo pipefail

if [ $# -lt 1 ]; then
  echo '{"error":"missing spec path"}' >&2
  exit 1
fi

spec="$1"
if [ ! -f "$spec" ]; then
  echo '{"error":"spec not found"}' >&2
  exit 1
fi

# Phase progression. Aligned with the 3-phase profile-feature.md
# (SPEC → BUILD → SHIP → SHIPPED). PLAN and VERIFY+LEARN were collapsed
# into sub-actions of SPEC and SHIP respectively in the v0.8 spine.
next_phase() {
  case "$1" in
    SPEC)    echo "BUILD" ;;
    BUILD)   echo "SHIP" ;;
    SHIP)    echo "SHIPPED" ;;
    SHIPPED) echo "" ;;
    *)       echo "" ;;
  esac
}

# Extract active phase from the [PHASE: X] line.
phase=$(grep -m1 -E '^\[PHASE:[[:space:]]*[A-Z]+\]' "$spec" 2>/dev/null \
        | sed -E 's/^\[PHASE:[[:space:]]*([A-Z]+)\].*/\1/')

if [ -z "$phase" ]; then
  echo '{"error":"no [PHASE: X] line found"}' >&2
  exit 1
fi

# Walk the spec, scoped to `## PHASE: <phase>` body, with fence tracking.
# Emits the first `[ ]` line found outside code fences. If none, prints empty.
first_open=$(awk -v target="## PHASE: ${phase}" '
  BEGIN { in_phase = 0; in_fence = 0 }
  # Track `## ` headings to scope to our phase.
  /^## / {
    if ($0 == target) {
      in_phase = 1; in_fence = 0; next
    } else if (in_phase) {
      # Left our phase.
      exit
    } else {
      next
    }
  }
  # Only process lines inside the active phase.
  in_phase != 1 { next }
  # Toggle fence state on lines that start with ``` (with optional language tag).
  /^[[:space:]]*```/ { in_fence = !in_fence; next }
  # Inside a code fence: ignore content.
  in_fence == 1 { next }
  # `[ ]` is overloaded across three semantic uses:
  #   1. Rubric question to fill (e.g. `- **Who has it:** [ ]`) — TRUE blocker.
  #   2. Work-item placeholder (e.g. `- [ ] AC1: ...`, `- [ ] T1 ...`) — NOT a
  #      SPEC blocker; turned to [GREEN] in BUILD.
  #   3. Exit-check definition (e.g. `- [ ] C-spec-acs: ...`) — verified by
  #      verify-stage.sh, never filled by hand.
  # Skip patterns 2 + 3 so /next reaches genuine rubric questions.
  /^[[:space:]]*-[[:space:]]*\[ \][[:space:]]+(AC|T|C-)[A-Za-z0-9_-]/ { next }
  # First `[ ]` outside fences and not a work-item placeholder: print and stop.
  /\[ \]/ { print; exit }
' "$spec")

# Helper: emit JSON with a sub_action string (escaped minimally).
json_escape() {
  # Escape backslashes and double quotes for JSON; strip CR.
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g'
}

if [ -n "$first_open" ]; then
  esc=$(json_escape "$first_open")
  printf '{"phase":"%s","sub_action":"%s","transition":null}\n' "$phase" "$esc"
  exit 0
fi

# No `[ ]` found in the active phase body → signal transition.
target_phase=$(next_phase "$phase")
if [ -n "$target_phase" ]; then
  printf '{"phase":"%s","sub_action":null,"transition":"%s→%s"}\n' "$phase" "$phase" "$target_phase"
else
  printf '{"phase":"%s","sub_action":null,"transition":null}\n' "$phase"
fi
exit 0
