#!/usr/bin/env bash
# T210 — AC11 — Multi-harness parity (PROD-ONLY at SHIP).
#
# The real claim — that the same `dispatch-wave.sh` invoked from Claude
# Code's Agent tool AND pi.dev's equivalent subagent-spawn API both
# produce equivalent partial-wave reports — requires LIVE harness runs.
# Mocking the dispatch loses the actual concurrency + harness API
# behaviours that are the whole point.
#
# What this BUILD-time test enforces (the structural floor):
#   A) dispatch-wave.sh contains NO harness-specific code paths.
#      No `claude_code` / `pi_dev` / harness-detect conditionals — the
#      script must be harness-agnostic by construction.
#   B) The SHIP signoff (§12) has a manual step for the live walk on
#      both Claude Code AND pi.dev (catches the case where someone
#      ships without doing the PROD-ONLY confirmation).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/dispatch-wave.sh"
SPEC="$FRAMEWORK_ROOT/.sdd/features/010-parallel-wave-execution/spec.md"

fails=()

# Fail fast: a missing/unreadable dispatch-wave.sh would let the
# harness-token scan silently no-op (no findings + AC11 PASS = false green).
if [ ! -r "$SCRIPT" ]; then
  fails+=("missing or unreadable dispatch script for AC11 scan: $SCRIPT")
fi

# --- A) Harness-agnostic by construction --------------------------------
# Reject explicit conditionals on specific harnesses. The script should
# stay model-agnostic — if it grows a `if claude_code` branch, that
# breaks the AC11 parity claim. Regex-based detection handles spacing,
# quoting, and case variants beyond the literal forms.
if [ -r "$SCRIPT" ]; then
  # Patterns:
  #   * `claude_code` / `pi_dev` anywhere (lowercase via -i)
  #   * `(if|case)` followed by HARNESS-style identifier comparison
  #   * `[ "$HARNESS" ... ]` test-bracket comparisons
  hits="$(grep -nEi 'claude_code|pi_dev|\bharness[[:space:]]*(=|==|!=)|\[[[:space:]]*"\$harness"[[:space:]]*(=|==|!=)' "$SCRIPT" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && fails+=("dispatch-wave.sh contains harness-specific construct at $line — breaks AC11 parity")
    done <<<"$hits"
  fi
fi

# --- B) SHIP signoff has a multi-harness manual step --------------------
# §12 signoff-steps must reference both Claude Code AND pi.dev so the
# live walk gets done before mark-shipped.
if [ ! -f "$SPEC" ]; then
  fails+=("missing spec file for §12 signoff-steps verification: $SPEC — cannot prove AC11 multi-harness signoff exists")
else
  # Extract from `### action: signoff-steps` to the NEXT `### action:`
  # header (skip the first match against signoff-steps itself).
  signoff_block="$(awk '
    /^### action: signoff-steps/ {in_block=1; next}
    in_block && /^### action: / {exit}
    in_block {print}
  ' "$SPEC")"
  if ! printf '%s' "$signoff_block" | grep -qi "claude code"; then
    fails+=("§12 signoff-steps missing Claude Code reference — multi-harness manual step at risk")
  fi
  if ! printf '%s' "$signoff_block" | grep -qi "pi\.dev\|pi-dev\|pi/dev"; then
    fails+=("§12 signoff-steps missing pi.dev reference — multi-harness manual step at risk")
  fi
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T210 — AC11 structural-floor violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T210 — AC11 dispatch-wave.sh is harness-agnostic; §12 signoff references both harnesses (live walk = PROD-ONLY at SHIP)"
