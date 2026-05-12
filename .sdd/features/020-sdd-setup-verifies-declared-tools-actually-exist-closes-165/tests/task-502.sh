#!/usr/bin/env bash
# T502 — AC3 — Check 2 Copilot fires when reviewer is copilot.
#
# When `parameters.review.bot=copilot`, verify-stack.sh runs check 2:
# probes whether Copilot review is configured via gh api; emits ✓ on
# success, ✗ + Settings > Code review URL on missing/unavailable.
#
# When bot is empty or not copilot, check 2 must NOT fire.

set -uo pipefail

FRAMEWORK_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
LIVE_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/verify-stack.sh"

fails=()

mkstub_gh_ok() {
  local d
  d=$(mktemp -d -t sdd-t502-stub.XXXXXX)
  cat > "$d/gh" <<'EOF'
#!/usr/bin/env bash
echo '{"id":1}'
exit 0
EOF
  chmod +x "$d/gh"
  echo "$d"
}

mkstub_gh_fail() {
  local d
  d=$(mktemp -d -t sdd-t502-stubfail.XXXXXX)
  cat > "$d/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$d/gh"
  echo "$d"
}

mkproject() {
  local d
  d=$(mktemp -d -t sdd-t502-proj.XXXXXX)
  mkdir -p "$d/.sdd"
  cat > "$d/.sdd/config.md" <<EOF
---
type: config
parameters:
  review:
    bot: "$1"
  mcp:
    tier3:
      enabled: false
---
EOF
  cat > "$d/.sdd/stack.md" <<EOF
# stack
EOF
  echo "$d"
}

# --- A) bot=copilot + gh stub ok -> check 2 fires with ✓ ---
STUB=$(mkstub_gh_ok)
PROJ=$(mkproject "copilot")
OUT=$(cd "$PROJ" && PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$STUB" "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "copilot"; then
  fails+=("A: bot=copilot but script emitted no Copilot line. Output: $OUT")
fi

# --- B) bot=copilot + gh fails -> check 2 emits ✗ + Settings URL hint ---
STUB=$(mkstub_gh_fail)
PROJ=$(mkproject "copilot")
OUT=$(cd "$PROJ" && PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$STUB" "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "copilot.*not|Code review|settings"; then
  fails+=("B: bot=copilot + gh fail: expected fail message + Settings hint, got: $OUT")
fi

# --- C) bot=coderabbit -> check 2 must NOT fire (only check 1) ---
PROJ=$(mkproject "coderabbit")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if printf '%s\n' "$OUT" | grep -qi "Copilot"; then
  fails+=("C: bot=coderabbit but script mentioned Copilot. Output: $OUT")
fi

# --- D) bot empty -> neither check fires; no-op line printed ---
PROJ=$(mkproject "")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if ! printf '%s\n' "$OUT" | grep -q "no declared tools to verify"; then
  fails+=("D: bot empty: expected 'no declared tools to verify', got: $OUT")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T502 — AC3 violations:"
  for e in "${fails[@]}"; do echo "  - $e"; done
  exit 1
fi

echo "PASS: T502 — check 2 Copilot fires on copilot + skips otherwise"
