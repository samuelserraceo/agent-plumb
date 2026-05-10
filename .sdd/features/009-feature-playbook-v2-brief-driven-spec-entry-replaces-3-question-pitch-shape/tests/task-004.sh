#!/usr/bin/env bash
# T04: feature.md playbook lists brief-intake as first SPEC action; problem still listed for backward-compat
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
PLAYBOOK="$ROOT/templates/.sdd/playbooks/feature.md"
[ -f "$PLAYBOOK" ] || { echo "FAIL: $PLAYBOOK missing"; exit 1; }

# Scope matches to the SPEC stage's actions block (between "- id: SPEC" and the next "- id:" or "exit_checks:")
spec_start=$(grep -nE '^  - id: SPEC$' "$PLAYBOOK" | head -1 | cut -d: -f1)
[ -n "$spec_start" ] || { echo "FAIL: '- id: SPEC' stage marker missing in $PLAYBOOK"; exit 1; }
spec_end=$(awk -v start="$spec_start" 'NR > start && (/^  - id: / || /^    exit_checks:/) {print NR; exit}' "$PLAYBOOK")
[ -n "$spec_end" ] || { echo "FAIL: cannot locate SPEC stage end (next stage or exit_checks)"; exit 1; }
spec_actions=$(awk -v s="$spec_start" -v e="$spec_end" 'NR > s && NR < e' "$PLAYBOOK")

# brief-intake must be listed in SPEC actions (whitespace-tolerant)
echo "$spec_actions" | grep -qE '^[[:space:]]*-[[:space:]]*brief-intake[[:space:]]*$' || { echo "FAIL: brief-intake not in SPEC actions list"; exit 1; }
# problem must still be listed in SPEC actions (backward-compat)
echo "$spec_actions" | grep -qE '^[[:space:]]*-[[:space:]]*problem[[:space:]]*$' || { echo "FAIL: problem must remain in SPEC actions (backward-compat)"; exit 1; }
# brief-intake must come BEFORE problem within the SPEC block
brief_pos=$(echo "$spec_actions" | grep -nE '^[[:space:]]*-[[:space:]]*brief-intake[[:space:]]*$' | head -1 | cut -d: -f1)
problem_pos=$(echo "$spec_actions" | grep -nE '^[[:space:]]*-[[:space:]]*problem[[:space:]]*$' | head -1 | cut -d: -f1)
if [ "$brief_pos" -ge "$problem_pos" ]; then
  echo "FAIL: brief-intake (SPEC pos $brief_pos) must come before problem (SPEC pos $problem_pos)"
  exit 1
fi
echo "PASS: T04 — brief-intake listed before problem in feature.md SPEC actions"
