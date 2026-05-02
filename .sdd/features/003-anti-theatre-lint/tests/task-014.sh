#!/usr/bin/env bash
# AC14 — multi-token line emits at least one error
# (current implementation: one error per line — first matched token reported)
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
echo 'refuses past 1KB and never fails' > "$TMP"
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 1 ]; then
  echo "FAIL: expected exit 1 on multi-token line, got $ec. Output: $out" >&2; exit 1
fi
# At minimum the line is flagged
echo "$out" | grep -q "$TMP:1" || { echo "FAIL: line 1 not flagged" >&2; exit 1; }
echo "PASS: AC14 — multi-token line flagged"
