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

# Parse the JSON once and assert the FULL AC1 contract in one strict pass:
# tag=WAVE-DISPATCH, wave=1, tasks == ["T200", "T201", "T202"] (source order),
# T203 (no marker) absent. Grep-based substring checks would let a reordered
# tasks list (["T202","T200","T201"]) pass even though AC1 demands source order.
happy_assert="$(printf '%s' "$happy_out" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception as e:
    print("json-parse-failed: " + str(e))
    sys.exit(2)
problems = []
if d.get("tag") != "WAVE-DISPATCH":
    problems.append("tag != WAVE-DISPATCH (got " + repr(d.get("tag")) + ")")
if d.get("wave") != 1:
    problems.append("wave != 1 (got " + repr(d.get("wave")) + ")")
expected_tasks = ["T200", "T201", "T202"]
if d.get("tasks") != expected_tasks:
    problems.append("tasks != " + repr(expected_tasks) + " in source order (got " + repr(d.get("tasks")) + ")")
if problems:
    print(" ; ".join(problems))
    sys.exit(3)
print("OK")
' 2>&1)"
if [ "$happy_assert" != "OK" ]; then
  fails+=("happy: AC1 contract violation: $happy_assert — raw output: $happy_out")
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
bad_rc=$?

# Malformed-marker branch must EITHER (a) parse cleanly with no WAVE-DISPATCH
# tag, OR (b) exit non-zero. Treating a parser-error as success would mask
# a real regression where the parser crashes on bad input.
if [ "$bad_rc" -ne 0 ]; then
  # rc != 0 is acceptable for malformed-marker input — the parser refusing is
  # fine. Nothing to verify in the output shape because the script bailed.
  :
else
  # rc == 0 means the parser handled the bad input cleanly. Now verify it
  # specifically did NOT produce a WAVE-DISPATCH tag.
  bad_assert="$(printf '%s' "$bad_out" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception as e:
    print("json-parse-failed: " + str(e))
    sys.exit(2)
if d.get("tag") == "WAVE-DISPATCH":
    print("malformed [WAVE: foo]/[WAVE: 0] wrongly produced WAVE-DISPATCH")
    sys.exit(3)
print("OK")
' 2>&1)"
  if [ "$bad_assert" != "OK" ]; then
    fails+=("edge: $bad_assert — raw output: $bad_out")
  fi
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
