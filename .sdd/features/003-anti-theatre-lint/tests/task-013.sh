#!/usr/bin/env bash
# AC13 — skip code blocks + inline code spans
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<'F'
The lint catches `enforces` and `1KB` but only outside code spans.

```text
this fenced block has refuses and 80% which should NOT trigger
```

Here `1KB` and `USD` are example tokens in inline code, not claims.
F
out=$(bash "$LINT" "$TMP" 2>&1); ec=$?
if [ "$ec" -ne 0 ]; then
  echo "FAIL: lint flagged tokens inside code spans/blocks. Output: $out" >&2; exit 1
fi
echo "PASS: AC13 — code blocks + inline code spans skipped"
