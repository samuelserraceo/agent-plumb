#!/usr/bin/env bash
# T02: skip_when[0].log_line is single-line, prefix-checked, recovery-path included
# AC2: the canonical log line shape is locked

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
FILE="$ROOT/templates/.sdd/actions/playwright-explore.md"

FRONTMATTER=$(awk '/^---$/{c++; next} c==1{print}' "$FILE")

python3 - "$FRONTMATTER" <<'PYEOF'
import sys, re

fm_text = sys.argv[1]
lines = fm_text.split("\n")

# Find skip_when[0].log_line. Reuse the same minimal parser as T01.
sw_idx = None
for i, ln in enumerate(lines):
    if re.match(r'^skip_when\s*:', ln):
        sw_idx = i
        break
assert sw_idx is not None, "T02 precondition: skip_when: block must exist (run T01 first to confirm)"

log_line = None
in_first_entry = False
i = sw_idx + 1
while i < len(lines):
    ln = lines[i]
    if re.match(r'^\S', ln):
        break
    if re.match(r'^\s*-\s', ln):
        if in_first_entry:
            break  # second entry — stop
        in_first_entry = True
        m = re.match(r'^\s*-\s+log_line\s*:\s*(.*)$', ln)
        if m:
            log_line = m.group(1).strip().strip('"\'')
    elif in_first_entry:
        m = re.match(r'^\s+log_line\s*:\s*(.*)$', ln)
        if m:
            log_line = m.group(1).strip().strip('"\'')
    i += 1

if log_line is None:
    print("FAIL: T02 — skip_when[0].log_line not found")
    sys.exit(1)

# Single line — no embedded newlines.
if "\n" in log_line:
    print(f"FAIL: T02 — log_line has embedded newlines (must be single-line): {log_line!r}")
    sys.exit(1)

# Prefix check.
if not log_line.startswith("playwright-explore: SKIPPED"):
    print(f"FAIL: T02 — log_line must start with 'playwright-explore: SKIPPED', got: {log_line!r}")
    sys.exit(1)

# Recovery path: contains the enable.sh install command.
if "bash .sdd/extensions/playwright-explorer/enable.sh" not in log_line:
    print(f"FAIL: T02 — log_line must contain the install command 'bash .sdd/extensions/playwright-explorer/enable.sh', got: {log_line!r}")
    sys.exit(1)

print("PASS: T02 — skip_when[0].log_line is single-line, prefix-checked, recovery-path included")
PYEOF
