#!/usr/bin/env bash
# AC1 — lint script exists and is executable
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
[ -x "$LINT" ] || { echo "FAIL: $LINT not executable" >&2; exit 1; }
echo "PASS: AC1 — lint executable at $LINT"
