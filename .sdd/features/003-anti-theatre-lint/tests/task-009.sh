#!/usr/bin/env bash
# AC9 — pre-commit hook installed
set -uo pipefail
H="templates/.claude/hooks/pre-commit-no-theatre.sh"
[ -x "$H" ] || { echo "FAIL: $H not executable" >&2; exit 1; }
grep -q "lint-no-theatre.sh" "$H" || { echo "FAIL: hook doesn't reference lint" >&2; exit 1; }
grep -q "git diff --cached" "$H" || { echo "FAIL: hook doesn't read staged content" >&2; exit 1; }
echo "PASS: AC9 — pre-commit hook installed and wired"
