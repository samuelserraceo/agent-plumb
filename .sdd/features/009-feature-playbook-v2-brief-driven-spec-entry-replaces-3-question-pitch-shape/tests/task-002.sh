#!/usr/bin/env bash
# T02: brief-summarise.md skeleton exists at templates/.sdd/skeletons/brief-summarise.md
# AC2: After brief paste, agent emits brief-summarise turn within same /next cycle
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
SKEL="$ROOT/templates/.sdd/skeletons/brief-summarise.md"
[ -f "$SKEL" ] || { echo "FAIL: $SKEL missing"; exit 1; }
grep -q "brief-summarise" "$SKEL" || { echo "FAIL: brief-summarise reference missing"; exit 1; }
grep -q "Here's what I just heard" "$SKEL" || { echo "FAIL: recap phrase missing"; exit 1; }
grep -q "Confirm or tell me what to fix" "$SKEL" || { echo "FAIL: confirm prompt missing"; exit 1; }
echo "PASS: T02 — brief-summarise skeleton exists with required phrases"
