#!/usr/bin/env bash
# AC2 — flag numerical theatre (1KB)
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
echo 'Reads cap of <1 KB on input.' > "$TMP"
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 1 ]; then echo "FAIL: expected exit 1, got $ec. Output: $out" >&2; exit 1; fi
echo "$out" | grep -qi "theatre claim" || { echo "FAIL: stderr missing 'theatre claim'. Got: $out" >&2; exit 1; }
echo "PASS: AC2 — numerical theatre flagged"
