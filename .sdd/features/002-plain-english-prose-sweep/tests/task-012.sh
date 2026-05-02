#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC12 — full framework regression
# CR feedback 2026-05-02: drop -e — `set -e` aborts the subshell command
# assignment on any non-zero exit BEFORE we capture ec; the failure-
# reporting branch never runs. Also generalise the RESULTS regex away
# from "19[0-9]+/19[0-9]+" so total-count growth doesn't break the test.
# `set -uo pipefail` (no -e) lets the subshell capture survive a non-zero
# exit AND lets `ec=$?` reflect the real exit code. CR cycle 2 caught
# that the earlier `|| true` was masking real failures by always forcing
# ec=0 — we want the genuine non-zero so the failure path runs.
set -uo pipefail
out=$(bash test/run-framework-test.sh 2>&1)
ec=$?
if [ "$ec" -eq 0 ] && echo "$out" | grep -qE "RESULTS: [0-9]+/[0-9]+ passing"; then
  results=$(echo "$out" | grep -E "RESULTS:" | tail -1)
  echo "PASS: AC12 — $results"
else
  echo "FAIL: framework regression ec=$ec" >&2
  echo "$out" | grep -E "FAIL|❌|RESULTS:" | tail -5 >&2
  exit 1
fi
