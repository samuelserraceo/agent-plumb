#!/usr/bin/env bash
# T05: success removed from feature.md SPEC actions; success.md deprecated:true
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
PLAYBOOK="$ROOT/templates/.sdd/playbooks/feature.md"
SUCCESS="$ROOT/templates/.sdd/actions/success.md"

# success NOT in actions list (deleted)
# Scope success-not-listed check to the SPEC stage actions block (between
# "- id: SPEC" and the next "- id:" or "exit_checks:") to avoid matching
# unrelated `- success` strings elsewhere in the playbook.
spec_start=$(grep -nE '^  - id: SPEC$' "$PLAYBOOK" | head -1 | cut -d: -f1)
[ -n "$spec_start" ] || { echo "FAIL: '- id: SPEC' stage marker missing in $PLAYBOOK"; exit 1; }
spec_end=$(awk -v start="$spec_start" 'NR > start && (/^  - id: / || /^    exit_checks:/) {print NR; exit}' "$PLAYBOOK")
[ -n "$spec_end" ] || { echo "FAIL: cannot locate SPEC stage end (next stage or exit_checks)"; exit 1; }
spec_block=$(awk -v s="$spec_start" -v e="$spec_end" 'NR > s && NR < e' "$PLAYBOOK")

if echo "$spec_block" | grep -qE '^[[:space:]]*-[[:space:]]*success[[:space:]]*$'; then
  echo "FAIL: 'success' still in SPEC actions list"
  exit 1
fi
# success.md still exists (file kept for in-flight features) but marked deprecated
[ -f "$SUCCESS" ] || { echo "FAIL: success.md missing entirely (should still ship for backward-compat)"; exit 1; }
# Scope deprecated-flag check to the YAML frontmatter (between the first two `---` lines)
frontmatter=$(awk '/^---$/{c++; if(c==1){next}; if(c==2){exit}} c==1' "$SUCCESS")
echo "$frontmatter" | grep -qE '^[[:space:]]*deprecated:[[:space:]]*true[[:space:]]*$' || { echo "FAIL: success.md must declare 'deprecated: true' in YAML frontmatter"; exit 1; }
echo "PASS: T05 — success removed from playbook; success.md kept + marked deprecated"
