#!/usr/bin/env bash
# T05: success removed from feature.md SPEC actions; success.md deprecated:true
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
PLAYBOOK="$ROOT/templates/.sdd/playbooks/feature.md"
SUCCESS="$ROOT/templates/.sdd/actions/success.md"

# success NOT in actions list (deleted)
if grep -qE '^[[:space:]]*-[[:space:]]*success[[:space:]]*$' "$PLAYBOOK"; then
  echo "FAIL: 'success' still in feature.md actions list"
  exit 1
fi
# success.md still exists (file kept for in-flight features) but marked deprecated
[ -f "$SUCCESS" ] || { echo "FAIL: success.md missing entirely (should still ship for backward-compat)"; exit 1; }
grep -qE '^[[:space:]]*deprecated:[[:space:]]*true[[:space:]]*$' "$SUCCESS" || { echo "FAIL: success.md must declare 'deprecated: true' in frontmatter"; exit 1; }
echo "PASS: T05 — success removed from playbook; success.md kept + marked deprecated"
