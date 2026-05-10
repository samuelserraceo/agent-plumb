#!/usr/bin/env bash
# background-emit-test.sh — T1/T2/T3 test for background-while-waiting.sh.
#
# Covers AC1 (script emits on manual trigger), AC2 (candidates listed),
# AC3 (action_chosen update), AC7 (telemetry schema clean).
#
# Runs against a temp .sdd/.cache directory so it doesn't pollute
# the real cache.

set -uo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/background-while-waiting.sh"

PASS=0
FAIL=0
declare -a FAILURES=()

assert_pass() {
  local label="$1"
  PASS=$((PASS + 1))
  echo "  ✓ $label"
}

assert_fail() {
  local label="$1" detail="${2:-}"
  FAIL=$((FAIL + 1))
  FAILURES+=("$label${detail:+ — $detail}")
  echo "  ✗ $label${detail:+ — $detail}"
}

# Set up a temp cache dir.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export SDD_CACHE_DIR="$tmp/.cache"
mkdir -p "$SDD_CACHE_DIR"
LOG="$SDD_CACHE_DIR/background-emit.log"

echo "=== T1 — emit on manual trigger (AC1) ==="

if [ ! -x "$SCRIPT" ]; then
  assert_fail "T1.0 script exists and is executable" "$SCRIPT not found / not +x"
else
  bash "$SCRIPT" cr-poll >/dev/null 2>&1
  ec=$?
  if [ "$ec" -ne 0 ]; then
    assert_fail "T1.1 script exits 0 on basic call" "exit code $ec"
  else
    assert_pass "T1.1 script exits 0 on basic call"
  fi

  if [ ! -f "$LOG" ]; then
    assert_fail "T1.2 log file created" "$LOG missing"
  else
    last_line=$(tail -1 "$LOG")
    if printf '%s' "$last_line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert set(d.keys()) == {'ts','session_id','wait_type','action_chosen'}, f'wrong keys: {list(d.keys())}'; assert d['wait_type']=='cr-poll', f'wrong wait_type: {d[\"wait_type\"]}'; assert d['action_chosen']=='pending', f'wrong action_chosen: {d[\"action_chosen\"]}'" 2>/dev/null; then
      assert_pass "T1.2 log line has schema {ts,session_id,wait_type,action_chosen} with cr-poll/pending"
    else
      assert_fail "T1.2 log line schema check" "last line: $last_line"
    fi
  fi
fi

echo
echo "=== T2 — list candidates flag (AC2) ==="

if [ -x "$SCRIPT" ]; then
  candidates=$(bash "$SCRIPT" --list-candidates 2>&1 1>/dev/null)
  for cand in re-read-corpus pre-fetch-next-feature draft-pr-description draft-commit-msgs; do
    if printf '%s' "$candidates" | grep -q "$cand"; then
      assert_pass "T2.$cand listed"
    else
      assert_fail "T2.$cand listed" "stderr: $candidates"
    fi
  done
fi

echo
echo "=== T3 — update last action (AC3) ==="

if [ -x "$SCRIPT" ]; then
  bash "$SCRIPT" --update-last-action draft-pr-description >/dev/null 2>&1
  if [ -f "$LOG" ]; then
    last_line=$(tail -1 "$LOG")
    if printf '%s' "$last_line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['action_chosen']=='draft-pr-description', f'still: {d[\"action_chosen\"]}'" 2>/dev/null; then
      assert_pass "T3 action_chosen updated to draft-pr-description"
    else
      assert_fail "T3 action_chosen update" "last line: $last_line"
    fi
  fi
fi

echo
echo "================================================================"
echo "PASS: $PASS  FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo
  echo "Failures:"
  for f in "${FAILURES[@]}"; do echo "  - $f"; done
  exit 1
fi
exit 0
