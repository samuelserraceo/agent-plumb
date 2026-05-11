#!/usr/bin/env bash
# T226 — AC7 — partial override: project config.md declares only
# `per_file_budget_chars: {patterns: 2000}`; resolver returns 2000
# for patterns + framework defaults for the other 5 corpus files.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HELPER="$FRAMEWORK_ROOT/templates/.sdd/scripts/get-injection-budget.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.sdd/scripts"
cp "$HELPER" "$tmp/.sdd/scripts/"
chmod +x "$tmp/.sdd/scripts/get-injection-budget.sh"

cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    per_file_budget_chars:
      patterns: 2000        # ONLY override
---
CFG

fails=()

# Override wins for patterns.
got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" patterns)
[ "$got" = "2000" ] || fails+=("patterns: expected 2000, got $got")

# Framework defaults fill in for the other 5 (avoid bash-4 assoc array
# — macOS default bash is 3.2; use parallel arrays).
check_key() {
  local key="$1" expected="$2"
  local got
  got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" "$key")
  [ "$got" = "$expected" ] || fails+=("$key: expected $expected, got $got")
}
check_key INDEX      3000
check_key spec       5000
check_key principles 2000
check_key stack      3000
check_key data-model 3000

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T226 — AC7 partial override violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T226 — AC7 partial override: declared key (patterns=2000) wins + 5 framework defaults fill in"
