#!/usr/bin/env bash
# T205 — AC6 — Partial-wave report on a failed wave-task.
#
# When one wave-task's commit fails, dispatch-wave.sh exits non-zero
# AND emits a structured report listing PASS/FAIL per task with the
# failing diagnostic.
#
# Mock-mode test: dispatch-wave.sh reads a `WAVE_MOCK_RESULTS` env
# var (JSON array of {"task":"T200","status":"PASS|FAIL","diag":"..."})
# in lieu of dispatching real subagents. With that, we can drive the
# report-shape code path without spinning up actual Agent calls.
# Real Agent-driven dispatch firing this same code path is verified
# at SHIP via AC12 (PROD-ONLY).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/dispatch-wave.sh"

fails=()

WORK="$(mktemp -d -t sdd-t205.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/spec.md" <<'SPEC'
---
playbook: feature
---
# fixture

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T200 [WAVE: 1]: scaffold A
- [ ] T201 [WAVE: 1]: scaffold B
- [ ] T202 [WAVE: 1]: scaffold C

## PHASE: BUILD
SPEC

# --- A) Mock partial failure: 2 PASS + 1 FAIL ----------------------------
mock_results='[{"task":"T200","status":"PASS","diag":""},{"task":"T201","status":"FAIL","diag":"anti-theatre lint blocked"},{"task":"T202","status":"PASS","diag":""}]'

out="$(WAVE_MOCK_RESULTS="$mock_results" bash "$SCRIPT" 1 "$WORK/spec.md" 2>&1)"
rc=$?

# Exit non-zero on partial failure.
if [ "$rc" -eq 0 ]; then
  fails+=("partial wave with FAIL returned rc=0; expected non-zero. out: $out")
fi

# Output JSON should carry the results array with the right shape.
parsed="$(printf '%s' "$out" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception as e: print("INVALID_JSON: " + str(e)); sys.exit(2)
results = obj.get("results") or []
if not results:
    print("results array empty (expected 3 entries from mock)"); sys.exit(3)
# Find the FAIL entry.
fail_entries = [r for r in results if r.get("status") == "FAIL"]
if not fail_entries:
    print("no FAIL entry in results: " + repr(results)); sys.exit(4)
fe = fail_entries[0]
if not fe.get("diag"):
    print("FAIL entry missing diag: " + repr(fe)); sys.exit(5)
if fe.get("task") != "T201":
    print("FAIL task != T201, got " + repr(fe.get("task"))); sys.exit(6)
# Verify mode flipped to "dispatched" (out of stub mode).
if obj.get("mode") == "stub":
    print("mode still stub on dispatched wave"); sys.exit(7)
print("OK")
' 2>&1)"

if ! printf '%s' "$parsed" | grep -q '^OK$'; then
  fails+=("partial-wave report shape violation: $parsed (raw out: $out)")
fi

# --- B) All-PASS mock: rc=0, results all PASS ---------------------------
all_pass='[{"task":"T200","status":"PASS","diag":""},{"task":"T201","status":"PASS","diag":""},{"task":"T202","status":"PASS","diag":""}]'

out_ok="$(WAVE_MOCK_RESULTS="$all_pass" bash "$SCRIPT" 1 "$WORK/spec.md" 2>&1)"
ok_rc=$?

if [ "$ok_rc" -ne 0 ]; then
  fails+=("all-PASS mock returned rc=$ok_rc; expected 0. out: $out_ok")
fi

parsed_ok="$(printf '%s' "$out_ok" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception: sys.exit(2)
results = obj.get("results") or []
if any(r.get("status") == "FAIL" for r in results):
    print("all-PASS mock got FAIL entries"); sys.exit(3)
if len(results) != 3:
    print("expected 3 results, got " + str(len(results))); sys.exit(4)
print("OK")
' 2>&1)"

if ! printf '%s' "$parsed_ok" | grep -q '^OK$'; then
  fails+=("all-PASS shape violation: $parsed_ok (raw out: $out_ok)")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T205 — AC6 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T205 — AC6 partial-wave report: mock FAIL produces non-zero rc + structured PASS/FAIL/diag list; all-PASS preserves rc=0"
