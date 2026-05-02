#!/usr/bin/env bash
# AC7 — {prod-only: <why>} annotation skips line
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<'F'
Service costs USD 12/month. {prod-only: requires live billing dashboard}
F
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 0 ]; then echo "FAIL: expected exit 0, got $ec. Output: $out" >&2; exit 1; fi
echo "PASS: AC7 — prod-only annotation accepted"
