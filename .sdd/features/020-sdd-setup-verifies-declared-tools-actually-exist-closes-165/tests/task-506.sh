#!/usr/bin/env bash
# T506 — AC7 — Check 6 test runner deps.
#
# When stack.md declares a test runner (e.g. "Test runner: Vitest" or
# "Test runner: Playwright"), verify-stack.sh runs check 6: greps
# package.json (or pyproject.toml fallback) for the runner dep name.
# Emits ✓ on present, ✗ + install hint otherwise.
#
# When stack.md does not declare a test runner, check 6 must NOT fire.

set -uo pipefail

FRAMEWORK_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
LIVE_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/verify-stack.sh"

fails=()

mkproject() {
  # $1 = stack.md content; $2 = package.json content (optional); $3 = pyproject.toml (optional)
  local d
  d=$(mktemp -d -t sdd-t506-proj.XXXXXX)
  mkdir -p "$d/.sdd"
  cat > "$d/.sdd/config.md" <<EOF
---
type: config
parameters:
  review:
    bot: ""
  mcp:
    tier3:
      enabled: false
---
EOF
  printf '%s\n' "$1" > "$d/.sdd/stack.md"
  [ -n "${2:-}" ] && printf '%s\n' "$2" > "$d/package.json"
  [ -n "${3:-}" ] && printf '%s\n' "$3" > "$d/pyproject.toml"
  echo "$d"
}

# --- A) stack declares Vitest + package.json has it -> ✓ ---
PROJ=$(mkproject "# stack
Test runner: Vitest" '{ "devDependencies": { "vitest": "^1.0.0" } }')
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "vitest|test runner"; then
  fails+=("A: Vitest declared + in package.json but no line. Output: $OUT")
fi

# --- B) stack declares Vitest + package.json does NOT have it -> ✗ ---
PROJ=$(mkproject "# stack
Test runner: Vitest" '{ "devDependencies": { "mocha": "^10.0.0" } }')
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "vitest.*not|missing|npm install"; then
  fails+=("B: Vitest declared but not in package.json: expected ✗ + install hint, got: $OUT")
fi

# --- C) Python project — declared pytest + pyproject.toml has it -> ✓ ---
PROJ=$(mkproject "# stack
Test runner: pytest" "" '[tool.poetry.dependencies]
python = "^3.10"
pytest = "^7.0"')
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "pytest|test runner"; then
  fails+=("C: pytest declared + in pyproject.toml but no line. Output: $OUT")
fi

# --- D) stack does NOT declare a test runner -> check 6 must NOT fire ---
PROJ=$(mkproject "# stack
- nothing about a test runner")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if printf '%s\n' "$OUT" | grep -qi "test runner"; then
  fails+=("D: stack does not declare test runner but script fired. Output: $OUT")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T506 — AC7 violations:"
  for e in "${fails[@]}"; do echo "  - $e"; done
  exit 1
fi

echo "PASS: T506 — check 6 test runner deps fires when stack declares it"
