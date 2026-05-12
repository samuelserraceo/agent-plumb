#!/usr/bin/env bash
# F024-corpus-signature-lock-test.sh — T290/T291/T292 task-tests for
# corpus-signature-lock.sh (the mkdir-as-lockdir helper for Tier 3
# synthesise() corpus-signature reads; closes #113).
#
# T290: helper exists in both template + live locations + is executable
# T291: acquire exits 1 when another process holds the lock
# T292: acquire/release happy path (acquire creates lockdir + exits 0,
#       release removes lockdir + exits 0, second release exits 0 idempotently)
#
# Runs against a temp directory so it doesn't pollute the real cache.

set -uo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIVE_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/corpus-signature-lock.sh"
TEMPLATE_SCRIPT="$FRAMEWORK_ROOT/templates/.sdd/scripts/corpus-signature-lock.sh"

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

# Set up a temp dir so we don't touch the real cache.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "=== T290 — helper exists in both locations + is executable (AC1) ==="

if [ ! -f "$LIVE_SCRIPT" ]; then
  assert_fail "T290.1 live helper present" "$LIVE_SCRIPT missing"
elif [ ! -x "$LIVE_SCRIPT" ]; then
  assert_fail "T290.1 live helper executable" "$LIVE_SCRIPT not +x"
else
  assert_pass "T290.1 live helper present + executable"
fi

if [ ! -f "$TEMPLATE_SCRIPT" ]; then
  assert_fail "T290.2 template helper present" "$TEMPLATE_SCRIPT missing"
elif [ ! -x "$TEMPLATE_SCRIPT" ]; then
  assert_fail "T290.2 template helper executable" "$TEMPLATE_SCRIPT not +x"
else
  assert_pass "T290.2 template helper present + executable"
fi

# Byte-for-byte parity between live + template — same script in both
# locations so downstream installs match the framework copy.
if [ -f "$LIVE_SCRIPT" ] && [ -f "$TEMPLATE_SCRIPT" ]; then
  if cmp -s "$LIVE_SCRIPT" "$TEMPLATE_SCRIPT"; then
    assert_pass "T290.3 live + template copies are byte-identical"
  else
    assert_fail "T290.3 live + template copies are byte-identical" "cmp diff"
  fi
fi

echo
echo "=== T291 — acquire exits 1 when held (AC3) ==="

# Hold the lock in a background subshell (using the helper itself so
# we exercise the real acquire path), then try a second acquire in the
# foreground. Cap the foreground retry budget low so the test is fast.

if [ -x "$LIVE_SCRIPT" ]; then
  LOCKDIR="$tmp/test-t291.lock.d"

  # Background: acquire + sleep + release. Holds the lock for ~8s,
  # which is longer than the helper's 5s retry ceiling.
  (
    bash "$LIVE_SCRIPT" acquire "$LOCKDIR" >/dev/null 2>&1
    sleep 8
    bash "$LIVE_SCRIPT" release "$LOCKDIR" >/dev/null 2>&1
  ) &
  bg_pid=$!

  # Wait briefly for the background to mkdir the lockdir before we try.
  i=0
  while [ ! -d "$LOCKDIR" ] && [ "$i" -lt 30 ]; do
    sleep 0.1
    i=$((i + 1))
  done

  if [ ! -d "$LOCKDIR" ]; then
    assert_fail "T291.0 background acquired the lock" "$LOCKDIR never appeared"
    kill "$bg_pid" 2>/dev/null
    wait "$bg_pid" 2>/dev/null
  else
    # Foreground acquire — should retry 50 × 0.1s (~5s) then exit 1.
    bash "$LIVE_SCRIPT" acquire "$LOCKDIR" >/dev/null 2>&1
    ec=$?
    if [ "$ec" -eq 1 ]; then
      assert_pass "T291.1 foreground acquire exits 1 when held by background"
    else
      assert_fail "T291.1 foreground acquire exits 1 when held" "exit code was $ec (expected 1)"
    fi

    # Clean up the background process (it'll release shortly).
    kill "$bg_pid" 2>/dev/null
    wait "$bg_pid" 2>/dev/null
    # If the kill landed before release, clean the lockdir manually.
    rmdir "$LOCKDIR" 2>/dev/null || true
  fi
fi

echo
echo "=== T292 — happy path: acquire + release + release-idempotent (AC2 + AC4) ==="

if [ -x "$LIVE_SCRIPT" ]; then
  LOCKDIR="$tmp/test-t292.lock.d"

  # First acquire — should succeed.
  bash "$LIVE_SCRIPT" acquire "$LOCKDIR"
  ec=$?
  if [ "$ec" -ne 0 ]; then
    assert_fail "T292.1 acquire on free lock exits 0" "exit code $ec"
  elif [ ! -d "$LOCKDIR" ]; then
    assert_fail "T292.1 acquire creates lockdir" "$LOCKDIR not created"
  else
    assert_pass "T292.1 acquire on free lock exits 0 + creates lockdir"
  fi

  # Release — should succeed and remove the lockdir.
  bash "$LIVE_SCRIPT" release "$LOCKDIR"
  ec=$?
  if [ "$ec" -ne 0 ]; then
    assert_fail "T292.2 release exits 0" "exit code $ec"
  elif [ -d "$LOCKDIR" ]; then
    assert_fail "T292.2 release removes lockdir" "$LOCKDIR still exists"
  else
    assert_pass "T292.2 release exits 0 + removes lockdir"
  fi

  # Idempotent second release — should still exit 0 (lockdir already absent).
  bash "$LIVE_SCRIPT" release "$LOCKDIR"
  ec=$?
  if [ "$ec" -eq 0 ]; then
    assert_pass "T292.3 second release is idempotent (exits 0 with lockdir absent)"
  else
    assert_fail "T292.3 second release idempotent" "exit code $ec (expected 0)"
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
