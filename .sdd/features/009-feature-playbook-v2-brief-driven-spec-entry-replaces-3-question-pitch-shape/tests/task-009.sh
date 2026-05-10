#!/usr/bin/env bash
# T09: proposed-approach.md "What it looks like" block uses plain-English-first + <details> foldable
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
ACTION="$ROOT/templates/.sdd/actions/proposed-approach.md"
[ -f "$ACTION" ] || { echo "FAIL: $ACTION missing"; exit 1; }

# Look for the foldable details block in the action's prose
grep -q "<details>" "$ACTION" || { echo "FAIL: no <details> foldable block — plain-English-first default not yet shipped"; exit 1; }
grep -q "Show technical detail" "$ACTION" || { echo "FAIL: 'Show technical detail' summary text missing"; exit 1; }
echo "PASS: T09 — proposed-approach uses <details> foldable for technical content"
