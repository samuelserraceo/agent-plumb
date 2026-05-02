#!/usr/bin/env bash
# AC4 — flag enforcement-language + quality theatre
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
echo 'The framework enforces correct behaviour.' > "$TMP"
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 1 ]; then echo "FAIL: expected exit 1, got $ec. Output: $out" >&2; exit 1; fi
echo "$out" | grep -qi "theatre" || { echo "FAIL: missing theatre" >&2; exit 1; }
echo "PASS: AC4 — enforcement-language + quality theatre flagged"
