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

# CR cycle 1 (#230 #4 Major + #7 Critical): the lenient short-circuit
# MUST close BEFORE the FILE_RULES section so append_only stays enforced
# in lenient mode. Pin the fi to be BEFORE FILE_RULES, not after.
FI_LINE=$(grep -nE '^fi\s+#.*LENIENT_MODE.*cofile-block.*#220' "$HOOK" | head -1 | cut -d: -f1)
FILE_RULES_LINE=$(grep -nE '^# === FILE_RULES enforcement' "$HOOK" | head -1 | cut -d: -f1)
[ -n "$FI_LINE" ] || { echo "FAIL: LENIENT_MODE cofile-block fi missing"; exit 1; }
[ -n "$FILE_RULES_LINE" ] || { echo "FAIL: FILE_RULES section marker missing"; exit 1; }
[ "$FI_LINE" -lt "$FILE_RULES_LINE" ] || { echo "FAIL: LENIENT_MODE fi at L$FI_LINE is AFTER FILE_RULES section at L$FILE_RULES_LINE (would gate append_only — CR #230 #7 regression)"; exit 1; }

# Syntax check — the hook must still be valid bash after the wrapping.
bash -n "$HOOK" 2>&1 || { echo "FAIL: hook has syntax errors after wrapping"; exit 1; }

echo "PASS: T02 — pre-commit-rules.sh skips cofile-block in LENIENT_MODE; syntax valid"
