#!/usr/bin/env bash
# AC1 — dry-run on a synced project reports 0 changes; exit 0.
#
# Sets up a temp "user" project that's a bit-for-bit copy of the
# framework's own templates/, then runs sdd-migrate.sh against the
# framework root as upstream. Since user == upstream, every category
# (ADD / UPDATE-CLEAN / UPDATE-CONFLICT / REMOVED) should be empty.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/templates/.sdd/scripts/sdd-migrate.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: sdd-migrate.sh missing or not executable at $SCRIPT"
  exit 1
fi

tmpdir=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$tmpdir"' EXIT

cd "$tmpdir" || { echo "FAIL: cd $tmpdir failed"; exit 1; }

# Synced state: user .sdd/ + .claude/ are exact copies of upstream's templates/
mkdir -p .sdd .claude
cp -R "$FRAMEWORK_ROOT/templates/.sdd/." .sdd/ 2>/dev/null
cp -R "$FRAMEWORK_ROOT/templates/.claude/." .claude/ 2>/dev/null

# Dry-run (no --apply)
out=$(bash "$SCRIPT" --upstream="$FRAMEWORK_ROOT" 2>&1)
ec=$?

fails=()
if [ "$ec" -ne 0 ]; then
  fails+=("expected exit 0 (dry-run on synced project), got $ec")
fi
if ! printf '%s' "$out" | grep -qiE 'in sync|no changes|0 changes'; then
  fails+=("expected 'in sync' / 'no changes' message in stdout")
fi
# No file should appear under ADD/CLEAN/CONFLICT — all 'none'.
if printf '%s' "$out" | grep -qE '^\s*[+~!]'; then
  fails+=("output contains drift markers (+/~/!) on a synced project")
fi

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC1 — synced project should report 0 changes"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Output:"
  printf '%s\n' "$out" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC1 — synced project = 0 changes"
exit 0
