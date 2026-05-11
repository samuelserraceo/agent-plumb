#!/usr/bin/env bash
# T02: pre-commit-rules.sh skips cofile-block in lenient mode (merge / rebase / cherry-pick)
# AC2: merge commit mixing CLAIM (verification.json) + POLICY (manifest.json) files
#      commits cleanly without bypass
#
# Mechanical assertion: pre-commit-rules.sh wraps the cofile-block path
# in a `if [ "$LENIENT_MODE" -eq 1 ]; then class_block_result="ALLOW"`
# else-branch, with a closing `fi` after the case statement. Pins the
# Channel-B templates/ copy (root .claude/hooks/ is gitignored as
# derived state, so the test-first hook can't stash it).

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
HOOK="$ROOT/templates/.claude/hooks/pre-commit-rules.sh"

[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }

# The cofile-block path MUST be gated by LENIENT_MODE — the gate sets
# class_block_result to "ALLOW" without running the python heredoc that
# computes the CLAIM x POLICY classification.
grep -qE 'if \[ "\$LENIENT_MODE" -eq 1 \]; then' "$HOOK" || { echo "FAIL: hook does not gate cofile-block on LENIENT_MODE"; exit 1; }
grep -qE 'class_block_result="ALLOW"' "$HOOK" || { echo "FAIL: hook does not short-circuit class_block_result to ALLOW under lenient mode"; exit 1; }

# Closing fi for the lenient-mode skip wrapper (with a comment trail
# explaining what it closes — helps future readers debug shell flow).
grep -qE '^fi\s+#.*LENIENT_MODE.*cofile-block.*#220' "$HOOK" || { echo "FAIL: hook does not close LENIENT_MODE cofile-block skip with a labelled fi"; exit 1; }

# Syntax check — the hook must still be valid bash after the wrapping.
bash -n "$HOOK" 2>&1 || { echo "FAIL: hook has syntax errors after wrapping"; exit 1; }

echo "PASS: T02 — pre-commit-rules.sh skips cofile-block in LENIENT_MODE; syntax valid"
