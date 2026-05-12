#!/usr/bin/env bash
# T02: /dispatch slash command file exists with the 3 roles named
# AC2: templates/.claude/commands/dispatch.md exists and names
#      researcher / executor / verifier in its body.
#
# Note on mirroring: the SDD framework repo dogfoods its own .sdd/
# (so both templates/.sdd/ AND .sdd/ exist in this repo). It does
# NOT keep a live .claude/ mirror — templates/.claude/ is canonical
# here and gets copied to downstream projects' .claude/ at install
# time (same shape as templates/.claude/hooks/, which has no live
# mirror in the framework repo either — see F019).

set -uo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"

ROLES="researcher executor verifier"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

file="$ROOT/templates/.claude/commands/dispatch.md"
[ -f "$file" ] || fail "missing templates/.claude/commands/dispatch.md"

for role in $ROLES; do
  grep -q "$role" "$file" || fail "templates/.claude/commands/dispatch.md does not name role '$role'"
done

# The slash command body must explicitly tell the agent to DISPATCH
# (not answer in-line). Catches the most common drift mode for
# agent-honoured conventions (per the F011 + F013 precedent).
grep -qi "dispatch" "$file" || fail "templates/.claude/commands/dispatch.md does not mention 'dispatch' in its body"

echo "PASS: T02 — /dispatch slash command exists and names all 3 roles"
