#!/usr/bin/env bash
# T227 — AC8 — unknown basename: resolver asked for a basename not
# in per_file_budget_chars (and not a known corpus file) returns
# the documented default char count of 2000.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HELPER="$FRAMEWORK_ROOT/templates/.sdd/scripts/get-injection-budget.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.sdd/scripts"
cp "$HELPER" "$tmp/.sdd/scripts/"
chmod +x "$tmp/.sdd/scripts/get-injection-budget.sh"

# Empty parameters block — no overrides, no unknown-key entries.
cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    per_file_budget_chars:
      patterns: 4000
---
CFG

fails=()

# Asking for a fully unknown basename returns 2000.
for key in glossary roadmap CHANGELOG random_file; do
  got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" "$key")
  [ "$got" = "2000" ] || fails+=("$key (unknown): expected 2000, got $got")
done

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T227 — AC8 unknown-key violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T227 — AC8 unknown basenames (glossary, roadmap, CHANGELOG, random_file) → documented default 2000"
