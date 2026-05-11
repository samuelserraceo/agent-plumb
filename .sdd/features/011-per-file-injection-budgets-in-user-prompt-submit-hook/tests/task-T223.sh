#!/usr/bin/env bash
# T223 — AC4 — templates/.sdd/scripts/get-injection-budget.sh returns
# the project's overriding value when per_file_budget_chars.<key> is
# set in config.md, and returns the documented framework default
# when the key is absent from the project config.
#
# Basic resolver round-trip test. Edge cases (partial override, unknown
# key, missing block, negative clamp) live in T226 / T227 / T228 / T236.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HELPER="$FRAMEWORK_ROOT/templates/.sdd/scripts/get-injection-budget.sh"

if [ ! -x "$HELPER" ]; then
  echo "FAIL: T223 — get-injection-budget.sh missing or not executable at $HELPER"
  exit 1
fi

# Set up a fresh temp project with a config.md declaring a custom
# patterns budget. The helper reads $CLAUDE_PROJECT_DIR/.sdd/config.md
# so we point that at the temp dir.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/.sdd/scripts"
cp "$HELPER" "$tmp/.sdd/scripts/get-injection-budget.sh"
chmod +x "$tmp/.sdd/scripts/get-injection-budget.sh"

cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    cap_total_chars: 16000
    per_file_budget_chars:
      patterns: 7777     # project override — uncommon value to detect leak
      INDEX: 1234        # second override
---
CFG

fails=()

# Project override should win for declared keys.
got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" patterns 2>/dev/null || echo "ERR")
if [ "$got" != "7777" ]; then
  fails+=("override-patterns: expected 7777, got '$got'")
fi

got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" INDEX 2>/dev/null || echo "ERR")
if [ "$got" != "1234" ]; then
  fails+=("override-INDEX: expected 1234, got '$got'")
fi

# Undeclared known key should fall back to framework default.
# (spec is a known key but not overridden in this test config.)
got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" spec 2>/dev/null || echo "ERR")
if [ "$got" != "5000" ]; then
  fails+=("default-spec: expected 5000, got '$got'")
fi

got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" principles 2>/dev/null || echo "ERR")
if [ "$got" != "2000" ]; then
  fails+=("default-principles: expected 2000, got '$got'")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T223 — AC4 resolver returned unexpected values:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T223 — AC4 resolver returns project override for declared keys + framework default for undeclared known keys"
