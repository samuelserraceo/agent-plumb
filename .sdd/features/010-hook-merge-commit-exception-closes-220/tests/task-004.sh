#!/usr/bin/env bash
# T04: bypass-via-git-commit-tree workaround documented in patterns.md
# AC4: the bypass-via-commit-tree path used for PR #219's merge is documented
#      in patterns.md as the workaround for pre-v1.7 framework versions

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
PATTERNS="$ROOT/.sdd/patterns.md"

[ -f "$PATTERNS" ] || { echo "FAIL: $PATTERNS missing"; exit 1; }

# Pattern entry MUST exist with the workaround heading.
grep -qE '^### Bypass-via-git-commit-tree' "$PATTERNS" || { echo "FAIL: 'Bypass-via-git-commit-tree' pattern heading missing in patterns.md"; exit 1; }

# Body MUST reference the specific failure mode (append_only + cofile-block)
# so a future reader hitting the same shape can grep for it.
grep -qE 'append_only.*cofile-block|cofile-block.*append_only' "$PATTERNS" || { echo "FAIL: pattern body does not mention both rule paths (append_only + cofile-block)"; exit 1; }

# Body MUST reference the documenting commit (dae7758) so the audit trail
# threads from patterns.md → main's git history.
grep -qE 'dae7758' "$PATTERNS" || { echo "FAIL: pattern body does not reference the bypass commit dae7758"; exit 1; }

# Body MUST reference issue #220 so a future reader knows where the fix
# landed (and can read the closure rationale).
grep -qE '#220' "$PATTERNS" || { echo "FAIL: pattern body does not reference issue #220"; exit 1; }

# Body MUST explicitly call out v1.7+ as the version where the workaround
# is unnecessary (per the issue's fix shape).
grep -qE 'v1\.7' "$PATTERNS" || { echo "FAIL: pattern body does not reference v1.7 as the cutover version"; exit 1; }

echo "PASS: T04 — patterns.md documents the bypass-via-git-commit-tree workaround for pre-v1.7"
