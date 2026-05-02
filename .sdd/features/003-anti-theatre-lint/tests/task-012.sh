#!/usr/bin/env bash
# AC12 — full framework regression
set -uo pipefail
out=$(bash test/run-framework-test.sh 2>&1); ec=$?
if [ "$ec" -eq 0 ] && echo "$out" | grep -qE "RESULTS: [0-9]+/[0-9]+ passing"; then
  echo "PASS: AC12 — $(echo "$out" | grep RESULTS | tail -1)"
else
  echo "FAIL: framework regression ec=$ec" >&2
  echo "$out" | grep -E "FAIL|❌|RESULTS" | tail -5 >&2
  exit 1
fi
