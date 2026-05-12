#!/usr/bin/env bash
# T504 — AC5 — Check 4 CI workflow files present.
#
# When stack.md prose mentions a "required check" + a job name (e.g.
# "required CI checks: typecheck, test, build"), verify-stack.sh runs
# check 4: greps `.github/workflows/*.yml` for those job names; emits
# ✓ if all present, ✗ + missing list otherwise.
#
# When stack.md does not declare CI checks, check 4 must NOT fire.

set -uo pipefail

FRAMEWORK_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
LIVE_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/verify-stack.sh"

fails=()

mkproject() {
  # $1 = stack.md content; $2 = workflow yaml content (optional)
  local d
  d=$(mktemp -d -t sdd-t504-proj.XXXXXX)
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
  if [ -n "${2:-}" ]; then
    mkdir -p "$d/.github/workflows"
    printf '%s\n' "$2" > "$d/.github/workflows/ci.yml"
  fi
  echo "$d"
}

# --- A) stack declares "required CI checks" + workflow files exist -> ✓ ---
PROJ=$(mkproject "# stack
- required CI checks: typecheck, test, build" "name: CI
on: pull_request
jobs:
  typecheck: { runs-on: ubuntu-latest, steps: [] }
  test:      { runs-on: ubuntu-latest, steps: [] }
  build:     { runs-on: ubuntu-latest, steps: [] }
")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "CI workflow|required check"; then
  fails+=("A: stack declares CI checks + workflow exists but script emitted no CI line. Output: $OUT")
fi

# --- B) stack declares CI checks but workflow file MISSING -> ✗ ---
PROJ=$(mkproject "# stack
- required CI checks: typecheck, test, build" "")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "CI workflow.*not|no workflow|missing"; then
  fails+=("B: stack declares CI but no workflow: expected ✗ message, got: $OUT")
fi

# --- C) stack does NOT declare CI checks -> check 4 must NOT fire ---
PROJ=$(mkproject "# stack
- nothing about CI here" "")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if printf '%s\n' "$OUT" | grep -qiE "CI workflow|required check"; then
  fails+=("C: stack does not declare CI but script fired. Output: $OUT")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T504 — AC5 violations:"
  for e in "${fails[@]}"; do echo "  - $e"; done
  exit 1
fi

echo "PASS: T504 — check 4 CI workflow files fires when stack declares required checks"
