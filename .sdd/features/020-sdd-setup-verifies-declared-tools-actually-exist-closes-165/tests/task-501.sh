#!/usr/bin/env bash
# T501 — AC2 — Check 1 CR App fires when reviewer is coderabbit.
#
# When `parameters.review.bot=coderabbit`, verify-stack.sh runs check 1:
# probes `gh api repos/.../installation` and emits ✓ on install present,
# ✗ + GitHub Marketplace URL on missing.
#
# When `parameters.review.bot` is empty or not coderabbit, check 1 must
# NOT fire (no output line referring to CodeRabbit).
#
# Test approach: PATH-shadow a stub `gh` binary that exits 0 (simulating
# install present) or exits 1 (simulating install missing); verify the
# script's output line + exit code.

set -uo pipefail

FRAMEWORK_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
LIVE_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/verify-stack.sh"

fails=()

mkstub() {
  # $1 = stub-dir (returned via stdout); $2 = exit code; $3 = stdout payload
  local d
  d=$(mktemp -d -t sdd-t501-stub.XXXXXX)
  cat > "$d/gh" <<EOF
#!/usr/bin/env bash
echo '$3'
exit $2
EOF
  chmod +x "$d/gh"
  echo "$d"
}

mkproject() {
  # $1 = bot value (e.g. "coderabbit" or "")
  local d
  d=$(mktemp -d -t sdd-t501-proj.XXXXXX)
  mkdir -p "$d/.sdd"
  cat > "$d/.sdd/config.md" <<EOF
---
type: config
sdd_version: 1.0.0
parameters:
  review:
    bot: "$1"
  mcp:
    tier3:
      enabled: false
  test_runner: ""
---

# config
EOF
  cat > "$d/.sdd/stack.md" <<EOF
# stack
EOF
  echo "$d"
}

# --- A) bot=coderabbit + stub gh exits 0 (install present) ---
STUB_OK=$(mkstub _ 0 '{"id":1}')
PROJ=$(mkproject "coderabbit")
OUT=$(cd "$PROJ" && PATH="$STUB_OK:$PATH" CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
RC=$?
rm -rf "$STUB_OK" "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "CodeRabbit"; then
  fails+=("A: bot=coderabbit but script emitted no CodeRabbit line. Output: $OUT")
fi
if [ "$RC" -ne 0 ]; then
  fails+=("A: bot=coderabbit + stub-install-ok: expected exit 0, got $RC. Output: $OUT")
fi

# --- B) bot=coderabbit + stub gh exits 1 (install missing) ---
STUB_FAIL=$(mkstub _ 1 '')
PROJ=$(mkproject "coderabbit")
OUT=$(cd "$PROJ" && PATH="$STUB_FAIL:$PATH" CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
RC=$?
rm -rf "$STUB_FAIL" "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "CodeRabbit.*not installed|coderabbitai|marketplace"; then
  fails+=("B: bot=coderabbit + stub-fail: expected install-missing message, got: $OUT")
fi

# --- C) bot empty (or none) — check 1 must NOT fire ---
PROJ=$(mkproject "")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
RC=$?
rm -rf "$PROJ"
if printf '%s\n' "$OUT" | grep -qi "CodeRabbit"; then
  fails+=("C: bot empty but script mentioned CodeRabbit. Output: $OUT")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T501 — AC2 violations:"
  for e in "${fails[@]}"; do echo "  - $e"; done
  exit 1
fi

echo "PASS: T501 — check 1 CR App fires on coderabbit + skips otherwise"
