#!/usr/bin/env bash
# AC15 — annotation regex tolerates whitespace
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<'F'
The framework enforces 1KB cap. { verify-by : T05 }
The framework refuses past 80%.{verify-by:T05}
F
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 0 ]; then
  echo "FAIL: whitespace-tolerant annotation rejected. Output: $out" >&2; exit 1
fi
echo "PASS: AC15 — annotation tolerates whitespace inside braces"
