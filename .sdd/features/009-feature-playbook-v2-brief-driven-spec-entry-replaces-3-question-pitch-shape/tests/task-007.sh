#!/usr/bin/env bash
# T07: CLAUDE.md gains a "One question per turn" doctrine subsection
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
CLAUDE_MD="$ROOT/templates/CLAUDE.md"
[ -f "$CLAUDE_MD" ] || { echo "FAIL: $CLAUDE_MD missing"; exit 1; }

# Check for the subsection heading + the doctrine line
grep -q "One question per turn" "$CLAUDE_MD" || { echo "FAIL: 'One question per turn' subsection missing"; exit 1; }
grep -q "AT MOST ONE question" "$CLAUDE_MD" || { echo "FAIL: 'AT MOST ONE question' doctrine line missing"; exit 1; }
echo "PASS: T07 — CLAUDE.md has 'One question per turn' doctrine"
