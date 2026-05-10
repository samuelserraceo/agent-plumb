#!/usr/bin/env bash
# T04: feature.md playbook lists brief-intake as first SPEC action; problem still listed for backward-compat
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
PLAYBOOK="$ROOT/templates/.sdd/playbooks/feature.md"
[ -f "$PLAYBOOK" ] || { echo "FAIL: $PLAYBOOK missing"; exit 1; }

# brief-intake must be listed in actions
grep -qE '^      - brief-intake$' "$PLAYBOOK" || { echo "FAIL: brief-intake not in actions list"; exit 1; }
# problem must still be listed (backward-compat)
grep -qE '^      - problem$' "$PLAYBOOK" || { echo "FAIL: problem must remain (backward-compat)"; exit 1; }
# brief-intake must come BEFORE problem
brief_line=$(grep -nE '^      - brief-intake$' "$PLAYBOOK" | head -1 | cut -d: -f1)
problem_line=$(grep -nE '^      - problem$' "$PLAYBOOK" | head -1 | cut -d: -f1)
if [ "$brief_line" -ge "$problem_line" ]; then
  echo "FAIL: brief-intake (line $brief_line) must come before problem (line $problem_line)"
  exit 1
fi
echo "PASS: T04 — brief-intake listed before problem in feature.md SPEC actions"
