#!/usr/bin/env bash
# T200 — AC1 — next-action.sh recognises [WAVE: N] markers in
# plan-decompose and returns { tag: WAVE-DISPATCH, wave: N, tasks: [...] }.
#
# Two checks:
#   A) Happy — fixture with three [WAVE: 1] tasks produces a WAVE-DISPATCH
#      JSON carrying wave=1 and tasks=[T200,T201,T202] in source order.
#      Sequential tasks (no [WAVE:] marker) MUST NOT leak into the list.
#   B) Edge (§15 ec-pick #7) — non-positive-integer markers
#      (`[WAVE: foo]`, `[WAVE: 0]`) MUST NOT produce a WAVE-DISPATCH tag;
#      the parser falls through to existing behaviour.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/next-action.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: T200 — next-action.sh not executable at $SCRIPT"
  exit 1
fi

WORK="$(mktemp -d -t sdd-t200.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

fails=()

# --- A) Happy path: three [WAVE: 1] tasks + one sequential ---------------
cat > "$WORK/happy.md" <<'SPEC'
---
playbook: feature
---

# fixture wave dispatch happy

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T200 [WAVE: 1]: scaffold endpoint A — proves AC1
- [ ] T201 [WAVE: 1]: scaffold endpoint B — proves AC2
- [ ] T202 [WAVE: 1]: scaffold endpoint C — proves AC3
- [ ] T203: sequential integration test (no wave marker)

## PHASE: BUILD

### action: build-task

(driven by plan-decompose tasks)

## PHASE: SHIP
SPEC

happy_out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$SCRIPT" "$WORK/happy.md" 2>&1)"
happy_rc=$?

if [ "$happy_rc" -ne 0 ]; then
  fails+=("happy: next-action.sh exited $happy_rc — output: $happy_out")
fi

if ! printf '%s' "$happy_out" | grep -q '"tag": *"WAVE-DISPATCH"'; then
  fails+=("happy: missing tag=WAVE-DISPATCH — output: $happy_out")
fi

if ! printf '%s' "$happy_out" | grep -q '"wave": *1'; then
  fails+=("happy: missing wave=1 — output: $happy_out")
fi

for t in T200 T201 T202; do
  if ! printf '%s' "$happy_out" | grep -q "\"$t\""; then
    fails+=("happy: tasks list missing $t — output: $happy_out")
  fi
done

# T203 has no [WAVE:] marker — it must NOT appear in the wave-1 task list.
# Use python to parse the JSON precisely so substring matches don't false-pass.
if printf '%s' "$happy_out" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception as e:
    print(f"json-parse-failed: {e}")
    sys.exit(2)
tasks = d.get("tasks") or []
sys.exit(1 if "T203" in tasks else 0)
' >/dev/null 2>&1; then
  :
else
  fails+=("happy: T203 (no [WAVE:] marker) leaked into wave-1 tasks — output: $happy_out")
fi

# --- B) Edge: malformed markers must NOT produce WAVE-DISPATCH -----------
cat > "$WORK/bad.md" <<'BAD'
---
playbook: feature
---

# fixture wave bad

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T300 [WAVE: foo]: non-integer marker
- [ ] T301 [WAVE: 0]: non-positive marker

## PHASE: BUILD

### action: build-task

(prose)

## PHASE: SHIP
BAD

bad_out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$SCRIPT" "$WORK/bad.md" 2>&1)"

if printf '%s' "$bad_out" | grep -q '"tag": *"WAVE-DISPATCH"'; then
  fails+=("edge: malformed [WAVE: foo]/[WAVE: 0] wrongly produced WAVE-DISPATCH — output: $bad_out")
fi

# ------------------------------------------------------------------------
if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T200 — AC1 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T200 — AC1 next-action.sh emits WAVE-DISPATCH on [WAVE: N] markers (source-order tasks, sequential excluded, malformed markers rejected)"
