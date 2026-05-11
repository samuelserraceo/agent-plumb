#!/usr/bin/env bash
# T202 — AC3 — Linear-mode regression.
#
# A spec.md WITHOUT any `[WAVE:]` markers MUST behave exactly as the
# pre-F010 framework did: next-action.sh returns the existing
# {phase, action, step, tag} shape based on the next open `[ ]` row;
# no WAVE-DISPATCH tag leaks in. `/next` walks tasks one at a time
# without invoking dispatch-wave.sh.
#
# This is the contract that lets adopters opt OUT of waves entirely
# just by not adding markers. Without this regression test, a future
# change to the WAVE parser could silently swallow non-marker tasks.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
NEXT="$FRAMEWORK_ROOT/.sdd/scripts/next-action.sh"

fails=()

WORK="$(mktemp -d -t sdd-t202.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# --- A) BUILD-phase fixture with ZERO [WAVE:] markers -----------------
cat > "$WORK/spec.md" <<'SPEC'
---
playbook: feature
---

# fixture linear

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T200: scaffold a thing (sequential)
- [ ] T201: scaffold another thing (sequential)
- [ ] T202: a third sequential task

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: linear (no waves)

### action: build-task

(driven by §plan-decompose)

## PHASE: SHIP
SPEC

out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$NEXT" "$WORK/spec.md" 2>/dev/null)"
rc=$?

if [ "$rc" -ne 0 ]; then
  fails+=("next-action.sh exited $rc on linear-mode fixture (expected 0). out: $out")
fi

# Strict JSON parse + assert NO WAVE-DISPATCH leaks in.
parsed_check="$(printf '%s' "$out" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception as e: print("INVALID_JSON: " + str(e)); sys.exit(2)
tag = obj.get("tag")
if tag == "WAVE-DISPATCH":
    print("WAVE-DISPATCH leaked: tag=" + repr(tag)); sys.exit(3)
# Linear mode should advance to build-task as the action.
if obj.get("phase") != "BUILD":
    print("phase != BUILD (got " + repr(obj.get("phase")) + ")"); sys.exit(4)
print("OK")
' 2>&1)"

if ! printf '%s' "$parsed_check" | grep -q '^OK$'; then
  fails+=("linear-mode JSON shape violation: $parsed_check (raw out: $out)")
fi

# --- B) Mixed fixture: some [WAVE:] markers AND some sequential -------
# The wave-marked tasks should produce WAVE-DISPATCH (T200 contract),
# but the SEQUENTIAL ones MUST NOT be swept into the wave's task list.
# Belt-and-braces with T200's happy-path check.
cat > "$WORK/mixed.md" <<'SPEC'
---
playbook: feature
---

# fixture mixed

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T200 [WAVE: 1]: marked
- [ ] T201: NOT marked (must stay sequential)
- [ ] T202 [WAVE: 1]: marked

## PHASE: BUILD

### action: build-task

## PHASE: SHIP
SPEC

mixed_out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$NEXT" "$WORK/mixed.md" 2>/dev/null)"
mixed_check="$(printf '%s' "$mixed_out" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception as e: print("INVALID_JSON: " + str(e)); sys.exit(2)
if obj.get("tag") != "WAVE-DISPATCH":
    print("expected WAVE-DISPATCH, got " + repr(obj.get("tag"))); sys.exit(3)
tasks = obj.get("tasks") or []
if "T201" in tasks:
    print("T201 (sequential, no marker) leaked into wave: " + repr(tasks)); sys.exit(4)
if tasks != ["T200", "T202"]:
    print("wave-1 tasks != [T200, T202], got " + repr(tasks)); sys.exit(5)
print("OK")
' 2>&1)"

if ! printf '%s' "$mixed_check" | grep -q '^OK$'; then
  fails+=("mixed-mode contract violation: $mixed_check (raw out: $mixed_out)")
fi

# --- Report -----------------------------------------------------------
if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T202 — AC3 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T202 — AC3 linear-mode regression: no [WAVE:] markers = no WAVE-DISPATCH; mixed mode keeps sequential tasks out of waves"
