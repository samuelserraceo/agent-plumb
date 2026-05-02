#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC12 — full framework regression
set -euo pipefail
out=$(bash test/run-framework-test.sh 2>&1)
ec=$?
if [ "$ec" -eq 0 ] && echo "$out" | grep -qE "RESULTS: 19[0-9]+/19[0-9]+ passing"; then
  results=$(echo "$out" | grep -E "RESULTS:" | tail -1)
  echo "PASS: AC12 — $results"
else
  echo "FAIL: framework regression ec=$ec" >&2
  echo "$out" | grep -E "FAIL|❌|RESULTS:" | tail -5 >&2
  exit 1
fi
