#!/usr/bin/env bash
# T01: pre-commit-rules.sh recognises merge mode for the append_only check
# AC1: legitimate merge with HEAD-bytes-preserved-as-prefix commits cleanly
#
# Mechanical assertion: pre-commit-rules.sh contains the MERGE_HEAD
# detection block + emits the lenient-mode log line. We can't run a full
# end-to-end merge in CI (would require git daemon setup); the prose-contract
# check is that the lenient-mode code path EXISTS in the hook.

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
# Pin to the TEMPLATES copy (the Channel-B shipped artefact). Root
# .claude/hooks/ is gitignored as derived state, so the test-first hook
# can't stash it — pinning to the tracked templates copy ensures the
# test FAILS without the code (real test-first, not theatre).
HOOK="$ROOT/templates/.claude/hooks/pre-commit-rules.sh"

[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }

# Lenient-mode detection: the hook MUST check .git/MERGE_HEAD (and
# REBASE_HEAD / CHERRY_PICK_HEAD per the spec).
grep -q "MERGE_HEAD" "$HOOK" || { echo "FAIL: hook does not detect .git/MERGE_HEAD"; exit 1; }
grep -q "REBASE_HEAD" "$HOOK" || { echo "FAIL: hook does not detect .git/REBASE_HEAD"; exit 1; }
grep -q "CHERRY_PICK_HEAD" "$HOOK" || { echo "FAIL: hook does not detect .git/CHERRY_PICK_HEAD"; exit 1; }

# Lenient mode flag: the hook MUST declare LENIENT_MODE (or equivalent
# named variable) so the downstream logic can branch on it.
grep -qE 'LENIENT_MODE|lenient_mode' "$HOOK" || { echo "FAIL: hook does not declare LENIENT_MODE flag"; exit 1; }

# Audit log: per §3 Story 3 (forensic reviewer), lenient mode MUST emit
# a stderr log line so a post-hoc auditor can see when it fired.
grep -qE '\[moat\].*lenient|merge.*lenient' "$HOOK" || { echo "FAIL: hook does not emit '[moat] ... lenient' stderr line"; exit 1; }

echo "PASS: T01 — pre-commit-rules.sh has MERGE_HEAD / REBASE_HEAD / CHERRY_PICK_HEAD detection + LENIENT_MODE flag + audit log line"
