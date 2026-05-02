#!/usr/bin/env bash
# AC3 — flag currency theatre
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
echo 'Sets cost_limit_usd: 0.50 as the cap.' > "$TMP"
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 1 ]; then echo "FAIL: expected exit 1, got $ec. Output: $out" >&2; exit 1; fi
echo "$out" | grep -qi "theatre claim" || { echo "FAIL: stderr missing 'theatre claim'" >&2; exit 1; }
echo "PASS: AC3 — currency theatre flagged"
