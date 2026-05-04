#!/usr/bin/env bash
# AC2 — dry-run on a project missing a tracked file → reports it under ADD.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/templates/.sdd/scripts/sdd-migrate.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: sdd-migrate.sh missing"; exit 1; }

tmpdir=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir" || { echo "FAIL: cd $tmpdir failed"; exit 1; }

# Synced project, then DELETE one tracked file to simulate "this file
# was added upstream after I installed."
mkdir -p .sdd .claude
cp -R "$FRAMEWORK_ROOT/templates/.sdd/." .sdd/ 2>/dev/null
cp -R "$FRAMEWORK_ROOT/templates/.claude/." .claude/ 2>/dev/null
rm -f .claude/hooks/pre-commit-test-first.sh

out=$(bash "$SCRIPT" --upstream="$FRAMEWORK_ROOT" 2>&1)
ec=$?

fails=()
[ "$ec" -eq 0 ] || fails+=("expected exit 0, got $ec")
printf '%s' "$out" | grep -qE '^\s*\+ .claude/hooks/pre-commit-test-first.sh' \
  || fails+=("expected pre-commit-test-first.sh in ADD list")

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC2 — missing tracked file should appear under ADD"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Output:"
  printf '%s\n' "$out" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC2 — missing tracked file reported under ADD"
exit 0
