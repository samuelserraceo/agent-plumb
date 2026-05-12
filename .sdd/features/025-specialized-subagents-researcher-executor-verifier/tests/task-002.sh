#!/usr/bin/env bash
# T02: /dispatch slash command file exists with the 3 roles named
# AC2: templates/.claude/commands/dispatch.md + .claude/commands/dispatch.md
#      both exist; both name researcher / executor / verifier in their body.

set -uo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"

ROLES="researcher executor verifier"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for prefix in "templates/.claude/commands" ".claude/commands"; do
  file="$ROOT/$prefix/dispatch.md"
  [ -f "$file" ] || fail "missing $prefix/dispatch.md"

  for role in $ROLES; do
    grep -q "$role" "$file" || fail "$prefix/dispatch.md does not name role '$role'"
  done
done

echo "PASS: T02 — /dispatch slash command exists and names all 3 roles (both mirrors)"
