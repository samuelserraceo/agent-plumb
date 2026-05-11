#!/usr/bin/env bash
# T03: action body has a ## When to skip section BEFORE **What it looks like:**
# AC3: agent-facing prose tells the agent the canonical single-line shape + bans the 12-line wall

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
FILE="$ROOT/templates/.sdd/actions/playwright-explore.md"

# Grab the H2 lines + the **What it looks like:** anchor in order.
SKIP_LINE=$(grep -nE '^## When to skip' "$FILE" | head -1 | cut -d: -f1)
WHAT_LINE=$(grep -nE '^\*\*What it looks like:\*\*' "$FILE" | head -1 | cut -d: -f1)

[ -n "$SKIP_LINE" ] || { echo "FAIL: T03 — '## When to skip' section not found in $FILE"; exit 1; }
[ -n "$WHAT_LINE" ] || { echo "FAIL: T03 — '**What it looks like:**' anchor not found in $FILE (sanity check)"; exit 1; }

[ "$SKIP_LINE" -lt "$WHAT_LINE" ] \
  || { echo "FAIL: T03 — '## When to skip' (line $SKIP_LINE) must appear BEFORE '**What it looks like:**' (line $WHAT_LINE)"; exit 1; }

# Body of the section must reference the canonical single-line shape AND ban the multi-line wall.
SECTION_BODY=$(awk -v start="$SKIP_LINE" -v end="$WHAT_LINE" 'NR>=start && NR<end' "$FILE")
echo "$SECTION_BODY" | grep -qE 'single.line|one.line|skip_when\[0\]\.log_line' \
  || { echo "FAIL: T03 — '## When to skip' body must reference the single-line canonical log"; echo "$SECTION_BODY"; exit 1; }
echo "$SECTION_BODY" | grep -qiE 'do not|not a|never|don.t|no .*multi.line|no .*12.line|no .*justification' \
  || { echo "FAIL: T03 — '## When to skip' body must ban the multi-line justification wall"; echo "$SECTION_BODY"; exit 1; }

echo "PASS: T03 — '## When to skip' section appears before the example block and names canonical shape"
