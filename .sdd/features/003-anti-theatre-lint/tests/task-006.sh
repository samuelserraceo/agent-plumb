#!/usr/bin/env bash
# AC6 — {best-effort: <who>} annotation skips line
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<'F'
Quality stays accurate over time. {best-effort: human reviewer at SHIP}
F
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 0 ]; then echo "FAIL: expected exit 0, got $ec. Output: $out" >&2; exit 1; fi
echo "PASS: AC6 — best-effort annotation accepted"
