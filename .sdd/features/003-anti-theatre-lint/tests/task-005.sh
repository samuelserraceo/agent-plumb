#!/usr/bin/env bash
# AC5 — {verify-by: T-NNN} annotation skips line
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<'F'
The framework enforces 1KB cap.
{verify-by: T05}
F
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 0 ]; then echo "FAIL: expected exit 0 (annotation present), got $ec. Output: $out" >&2; exit 1; fi
echo "PASS: AC5 — verify-by annotation accepted"
