#!/usr/bin/env bash
# T01: brief-intake action prose exists at templates/.sdd/actions/brief-intake.md
# AC1: Running /start <title> on a NEW feature shows the brief-paste prompt
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
ACTION="$ROOT/templates/.sdd/actions/brief-intake.md"
[ -f "$ACTION" ] || { echo "FAIL: $ACTION missing"; exit 1; }
grep -q "^slug: brief-intake$" "$ACTION" || { echo "FAIL: brief-intake slug missing"; exit 1; }
grep -q "^tag: USER-LED$" "$ACTION" || { echo "FAIL: USER-LED tag missing"; exit 1; }
grep -q "Paste your brief" "$ACTION" || { echo "FAIL: brief-paste prompt missing from prose"; exit 1; }
grep -q "or use the template" "$ACTION" || { echo "FAIL: template option missing"; exit 1; }
echo "PASS: T01 — brief-intake action prose exists with required fields"
