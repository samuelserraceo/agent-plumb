#!/usr/bin/env bash
# T209 — AC10 — Orchestrator context growth bounded.
#
# Best-effort claim (per §11 AC10): the orchestrator's transcript turn
# count grows by ~10 (5 dispatch + 5 report-back) per 5-wave / 30-task
# BUILD walk, not ~30 (linear).
#
# Mechanically testable here: the structural cost. A fixture with
# 5 waves of 6 tasks → next-action.sh resolves exactly 5 distinct
# WAVE-DISPATCH events when walked through (one per wave). That is
# the orchestrator's per-wave dispatch decision count — ~10 turns
# allows ~5 dispatch + ~5 report-back, the AC10 ceiling.
#
# The actual turn count in a real session depends on how the
# orchestrator phrases each dispatch / report-back — that is the
# best-effort eye-check at SHIP. Here we lock down the structural
# floor: the framework cannot make the orchestrator dispatch more
# than once per wave on this fixture.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
NEXT="$FRAMEWORK_ROOT/.sdd/scripts/next-action.sh"

fails=()

WORK="$(mktemp -d -t sdd-t209.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# --- Build a fixture spec.md with 5 waves of 6 tasks (30 tasks total) ---
{
  echo "---"
  echo "playbook: feature"
  echo "---"
  echo
  echo "# fixture 5-wave 6-task each"
  echo
  echo "[PHASE: BUILD]"
  echo
  echo "## PHASE: SPEC"
  echo
  echo "### action: plan-decompose"
  echo
  t_id=200
  for w in 1 2 3 4 5; do
    for _i in 1 2 3 4 5 6; do
      printf -- "- [ ] T%03d [WAVE: %d]: stub\n" "$t_id" "$w"
      t_id=$((t_id + 1))
    done
  done
  echo
  echo "## PHASE: BUILD"
  echo
  echo "### action: build-task"
  echo
  echo "## PHASE: SHIP"
} > "$WORK/spec.md"

# Count distinct WAVE-DISPATCH events as the walk progresses.
# Simulate: flip every task in wave N to [x], then ask next-action
# what the next blocker is. Each unfinished wave produces ONE
# WAVE-DISPATCH; once flipped, we move to the next wave.
dispatch_count=0
for w in 1 2 3 4 5; do
  out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$NEXT" "$WORK/spec.md" 2>/dev/null)"
  wave_n="$(printf '%s' "$out" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception: sys.exit(2)
if obj.get("tag") != "WAVE-DISPATCH":
    sys.exit(3)
print(obj.get("wave", "?"))
' 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ] || [ "$wave_n" != "$w" ]; then
    fails+=("walk step $w: expected WAVE-DISPATCH for wave=$w, got rc=$rc / wave=$wave_n / out=$out")
    break
  fi
  dispatch_count=$((dispatch_count + 1))
  # Flip every task in wave $w to GREEN to advance.
  python3 -c "
import re
with open('$WORK/spec.md', encoding='utf-8') as f:
    content = f.read()
content = re.sub(
    r'^- \[ \] (T\d+) \[WAVE: $w\]:',
    r'- [x] \1 [WAVE: $w]:',
    content,
    flags=re.M,
)
with open('$WORK/spec.md', 'w', encoding='utf-8') as f:
    f.write(content)
"
done

if [ "$dispatch_count" -ne 5 ]; then
  fails+=("expected exactly 5 WAVE-DISPATCH events to drain a 5-wave fixture; got $dispatch_count")
fi

# Counter-fixture: a 30-task LINEAR plan (no [WAVE:]) would force the
# orchestrator into ~30 turns. We don't simulate the linear walk here
# (would just be 30 individual /next calls); the fixture math is the
# AC10 floor.

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T209 — AC10 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T209 — AC10 5-wave/30-task fixture drains in exactly 5 WAVE-DISPATCH events (structural ceiling on orchestrator turns; real turn count is the named-eye check at SHIP)"
