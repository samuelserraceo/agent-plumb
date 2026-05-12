#!/usr/bin/env bash
# T505 — AC6 — Check 5 Tier 3 LLM provider reachable.
#
# When parameters.mcp.tier3.enabled=true:
#  - if provider=ollama → curl localhost:11434/api/tags (✓ if 200, ✗ + install hint)
#  - if provider=openai → [ -n "$OPENAI_API_KEY" ] (✓ if set, ✗ + env-var hint)
#
# When tier3.enabled=false (or unset), check 5 must NOT fire.

set -uo pipefail

FRAMEWORK_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
LIVE_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/verify-stack.sh"

fails=()

mkstub_curl_ok() {
  local d
  d=$(mktemp -d -t sdd-t505-curlok.XXXXXX)
  cat > "$d/curl" <<'EOF'
#!/usr/bin/env bash
echo '{"models":[]}'
exit 0
EOF
  chmod +x "$d/curl"
  echo "$d"
}

mkstub_curl_fail() {
  local d
  d=$(mktemp -d -t sdd-t505-curlfail.XXXXXX)
  cat > "$d/curl" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
  chmod +x "$d/curl"
  echo "$d"
}

mkproject() {
  # $1 = enabled (true/false); $2 = provider (ollama/openai/"")
  local d
  d=$(mktemp -d -t sdd-t505-proj.XXXXXX)
  mkdir -p "$d/.sdd"
  cat > "$d/.sdd/config.md" <<EOF
---
type: config
parameters:
  review:
    bot: ""
  mcp:
    tier3:
      enabled: $1
      provider: "$2"
---
EOF
  cat > "$d/.sdd/stack.md" <<EOF
# stack
EOF
  echo "$d"
}

# --- A) tier3 enabled + ollama + curl ok -> ✓ ---
STUB=$(mkstub_curl_ok)
PROJ=$(mkproject "true" "ollama")
OUT=$(cd "$PROJ" && PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$STUB" "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "ollama|Tier 3"; then
  fails+=("A: tier3+ollama but no Ollama/Tier 3 line. Output: $OUT")
fi

# --- B) tier3 enabled + ollama + curl fails -> ✗ + install hint ---
STUB=$(mkstub_curl_fail)
PROJ=$(mkproject "true" "ollama")
OUT=$(cd "$PROJ" && PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$STUB" "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "ollama.*not|unreachable|install"; then
  fails+=("B: tier3+ollama curl fail: expected ✗ + install hint, got: $OUT")
fi

# --- C) tier3 enabled + openai + OPENAI_API_KEY unset -> ✗ ---
PROJ=$(mkproject "true" "openai")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" env -u OPENAI_API_KEY bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "OPENAI_API_KEY|openai.*not"; then
  fails+=("C: tier3+openai no key: expected env-var hint, got: $OUT")
fi

# --- D) tier3 enabled + openai + key set -> ✓ ---
PROJ=$(mkproject "true" "openai")
OUT=$(cd "$PROJ" && OPENAI_API_KEY=fake-test-key CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "openai|Tier 3"; then
  fails+=("D: tier3+openai with key: expected ✓, got: $OUT")
fi

# --- E) tier3 disabled -> check 5 must NOT fire ---
PROJ=$(mkproject "false" "")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if printf '%s\n' "$OUT" | grep -qiE "ollama|openai|Tier 3"; then
  fails+=("E: tier3 disabled but script fired check 5. Output: $OUT")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T505 — AC6 violations:"
  for e in "${fails[@]}"; do echo "  - $e"; done
  exit 1
fi

echo "PASS: T505 — check 5 Tier 3 provider fires when enabled + skips when disabled"
