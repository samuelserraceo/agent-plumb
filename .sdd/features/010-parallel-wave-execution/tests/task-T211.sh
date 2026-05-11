#!/usr/bin/env bash
# T211 — AC12 — End-to-end wave dispatch in a real session (PROD-ONLY).
#
# The real claim — a real Claude Code session walks a fixture spec.md
# with 3 wave-tasks, dispatches 3 parallel Agent calls, lands 9 atomic
# commits in non-deterministic order, all 3 task rows flip GREEN —
# requires the LIVE Claude Code Agent tool against a real LLM. Mocking
# loses the concurrency + LLM-driven commit shape that is the whole
# point of the AC.
#
# What this BUILD-time test enforces (the structural chain):
#   1. next-action.sh emits a WAVE-DISPATCH tag for the fixture
#      (proven again here against this T211 fixture, belt-and-braces).
#   2. dispatch-wave.sh accepts the same fixture + a mock 3/3-PASS
#      result set and returns rc=0 with the structured per-task
#      report. This is the end-to-end pipeline shape the real session
#      walks through.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
NEXT="$FRAMEWORK_ROOT/.sdd/scripts/next-action.sh"
DISPATCH="$FRAMEWORK_ROOT/.sdd/scripts/dispatch-wave.sh"

fails=()

WORK="$(mktemp -d -t sdd-t211.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/spec.md" <<'SPEC'
---
playbook: feature
---
# fixture end-to-end

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T300 [WAVE: 1]: stub task A
- [ ] T301 [WAVE: 1]: stub task B
- [ ] T302 [WAVE: 1]: stub task C

## PHASE: BUILD

### action: build-task

## PHASE: SHIP
SPEC

# Step 1: next-action.sh resolves WAVE-DISPATCH for wave 1.
na_out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$NEXT" "$WORK/spec.md" 2>/dev/null)"
na_check="$(printf '%s' "$na_out" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception: sys.exit(2)
if obj.get("tag") != "WAVE-DISPATCH":
    print("step1: tag != WAVE-DISPATCH, got " + repr(obj.get("tag"))); sys.exit(3)
if obj.get("wave") != 1:
    print("step1: wave != 1, got " + repr(obj.get("wave"))); sys.exit(4)
tasks = obj.get("tasks") or []
if tasks != ["T300", "T301", "T302"]:
    print("step1: tasks != [T300,T301,T302], got " + repr(tasks)); sys.exit(5)
print("OK")
' 2>&1)"
if ! printf '%s' "$na_check" | grep -q '^OK$'; then
  fails+=("step1 next-action shape: $na_check (raw: $na_out)")
fi

# Step 2: dispatch-wave.sh with mock 3/3-PASS returns rc=0 + results all PASS.
mock_3of3='[{"task":"T300","status":"PASS","diag":""},{"task":"T301","status":"PASS","diag":""},{"task":"T302","status":"PASS","diag":""}]'
dw_out="$(WAVE_MOCK_RESULTS="$mock_3of3" bash "$DISPATCH" 1 "$WORK/spec.md" 2>/dev/null)"
dw_rc=$?
if [ "$dw_rc" -ne 0 ]; then
  fails+=("step2 dispatch-wave 3/3-PASS rc != 0 (got $dw_rc). out: $dw_out")
fi
dw_check="$(printf '%s' "$dw_out" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception: sys.exit(2)
# Verify dispatch-wave.sh wired the REQUESTED wave (a broken dispatcher
# could return mock PASS results with wrong wave/tasks and pass len + status
# checks alone).
if obj.get("wave") != 1:
    print("step2: dispatched wave != 1 (got " + repr(obj.get("wave")) + ")"); sys.exit(5)
expected_tasks = ["T300", "T301", "T302"]
if obj.get("tasks") != expected_tasks:
    print("step2: tasks != " + repr(expected_tasks) + " in source order (got " + repr(obj.get("tasks")) + ")"); sys.exit(6)
results = obj.get("results") or []
if len(results) != 3:
    print("step2: expected 3 results, got " + str(len(results))); sys.exit(3)
if any(r.get("status") != "PASS" for r in results):
    print("step2: not all PASS, got " + repr([r.get("status") for r in results])); sys.exit(4)
print("OK")
' 2>&1)"
if ! printf '%s' "$dw_check" | grep -q '^OK$'; then
  fails+=("step2 dispatch-wave report shape: $dw_check (raw: $dw_out)")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T211 — AC12 structural-chain violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T211 — AC12 structural chain (next-action → dispatch-wave → mock 3/3-PASS) end-to-end wired; real-session live walk is PROD-ONLY at SHIP"
