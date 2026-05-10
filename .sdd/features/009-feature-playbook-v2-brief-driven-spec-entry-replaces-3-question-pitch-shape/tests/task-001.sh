#!/usr/bin/env bash
# T01: brief-intake action prose exists at templates/.sdd/actions/brief-intake.md
# AC1: Running /start <title> on a NEW feature shows the brief-paste prompt
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
ACTION="$ROOT/templates/.sdd/actions/brief-intake.md"
[ -f "$ACTION" ] || { echo "FAIL: $ACTION missing"; exit 1; }
# Scope frontmatter checks to the YAML frontmatter (between the first two `---` lines)
# to avoid false-passing on slug/tag strings appearing in prose or code blocks.
frontmatter=$(awk '/^---$/{c++; if(c==1){next}; if(c==2){exit}} c==1' "$ACTION")
echo "$frontmatter" | grep -qE '^[[:space:]]*slug:[[:space:]]*brief-intake[[:space:]]*$' || { echo "FAIL: brief-intake slug missing in frontmatter"; exit 1; }
echo "$frontmatter" | grep -qE '^[[:space:]]*tag:[[:space:]]*USER-LED[[:space:]]*$' || { echo "FAIL: USER-LED tag missing in frontmatter"; exit 1; }
grep -q "Paste your brief" "$ACTION" || { echo "FAIL: brief-paste prompt missing from prose"; exit 1; }
grep -q "or use the template" "$ACTION" || { echo "FAIL: template option missing"; exit 1; }
echo "PASS: T01 — brief-intake action prose exists with required fields"
