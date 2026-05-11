#!/usr/bin/env bash
# T03: regular (non-merge) commits still get refused for cofile-block + append-only
# AC3: lenient mode is GATED on .git/MERGE_HEAD etc., not unconditionally relaxed
#
# Mechanical assertion: in the templates/ hook, the LENIENT_MODE gate
# MUST default to 0 when no merge/rebase/cherry-pick is in progress.
# The byte-prefix append-only check + the cofile-block path must both
# be reachable when LENIENT_MODE=0.

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
HOOK="$ROOT/templates/.claude/hooks/pre-commit-rules.sh"

[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }

# LENIENT_MODE defaults to 0 (regular commit shape) — the variable is
# initialised to 0 before the MERGE_HEAD detection, NOT initialised to
# 1 (which would be a strict-bypass-by-default regression).
grep -qE '^LENIENT_MODE=0' "$HOOK" || { echo "FAIL: LENIENT_MODE does not default to 0 (regression risk: strict mode bypassed by default)"; exit 1; }

# The cofile-block lenient skip is gated on `LENIENT_MODE -eq 1` (NOT
# `-eq 0` or `-ne 0` etc.) — the gate refuses unless the explicit
# merge-mode condition is met.
grep -qE 'if \[ "\$LENIENT_MODE" -eq 1 \]' "$HOOK" || { echo "FAIL: cofile-block gate is not -eq 1 (regression risk: gate flipped)"; exit 1; }

# The else-branch of the LENIENT_MODE wrapper STILL runs the python
# heredoc that classifies CLAIM × POLICY — verifies the gate is a SKIP
# wrapper, not a replacement. (Look for the heredoc opener inside the
# else block.)
ELSE_PRESENT=$(awk '/if \[ "\$LENIENT_MODE" -eq 1 \]; then/,/^fi.*LENIENT_MODE.*cofile-block.*#220/' "$HOOK" | grep -c "STAGED=\"\$staged\" python3")
[ "$ELSE_PRESENT" -ge 1 ] || { echo "FAIL: regular-mode (non-lenient) cofile-block path missing — strict mode broken"; exit 1; }

# The append_only handler (file_rules section) is NOT gated on LENIENT_MODE
# — the byte-prefix check runs the same way in both modes. A merge that
# rewrote prior entries fails the prefix check just like a regular commit.
# (This is the "tampering merges still refused" guarantee from §10 NFR.)
APPEND_GATE=$(awk '/# append_only handler\./,/REASON: append_only/' "$HOOK" | { grep -cE 'LENIENT_MODE' || true; })
[ "$APPEND_GATE" -eq 0 ] || { echo "FAIL: append_only is gated on LENIENT_MODE (should be UNGATED — same check in both modes)"; exit 1; }

echo "PASS: T03 — LENIENT_MODE defaults to 0; cofile-block gate strict-by-default; append_only ungated (regression-locked)"
