#!/usr/bin/env bash
# T228 — AC9 — missing block: project config.md omits
# per_file_budget_chars entirely (or sets it to null); resolver
# returns framework defaults for each of the 6 declared corpus files.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HELPER="$FRAMEWORK_ROOT/templates/.sdd/scripts/get-injection-budget.sh"

run_case() {
  local label="$1"
  local config_body="$2"
  local tmp
  tmp=$(mktemp -d)
  mkdir -p "$tmp/.sdd/scripts"
  cp "$HELPER" "$tmp/.sdd/scripts/"
  chmod +x "$tmp/.sdd/scripts/get-injection-budget.sh"
  printf '%s' "$config_body" > "$tmp/.sdd/config.md"

  # Parallel arrays (bash 3.2 compat — no assoc arrays).
  local fails=()
  local pairs=( INDEX 3000 spec 5000 principles 2000 stack 3000 data-model 3000 patterns 4000 )
  local i=0
  while [ "$i" -lt ${#pairs[@]} ]; do
    local key="${pairs[$i]}"
    local expected="${pairs[$((i+1))]}"
    local got
    got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" "$key")
    if [ "$got" != "$expected" ]; then
      fails+=("[$label] $key: expected $expected, got $got")
    fi
    i=$((i+2))
  done
  rm -rf "$tmp"
  if [ ${#fails[@]} -gt 0 ]; then
    for f in "${fails[@]}"; do echo "  - $f" >&2; done
    return 1
  fi
  return 0
}

ok=0

# Case 1: block entirely omitted.
if run_case "omitted" "---
type: config
parameters:
  injection:
    cap_total_chars: 16000
---
"; then ok=$((ok+1)); fi

# Case 2: block set to null explicitly.
if run_case "null" "---
type: config
parameters:
  injection:
    per_file_budget_chars: null
---
"; then ok=$((ok+1)); fi

# Case 3: parameters block entirely missing.
if run_case "no-parameters" "---
type: config
---
"; then ok=$((ok+1)); fi

if [ "$ok" -ne 3 ]; then
  echo "FAIL: T228 — AC9 missing-block: $ok / 3 cases passed"
  exit 1
fi

echo "PASS: T228 — AC9 missing-block: all 3 cases (omitted / null / no-parameters) return framework defaults"
