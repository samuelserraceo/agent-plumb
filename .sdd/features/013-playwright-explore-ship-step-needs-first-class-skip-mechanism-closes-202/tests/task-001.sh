#!/usr/bin/env bash
# T01: playwright-explore.md frontmatter has a skip_when: list with entry(condition, detect, log_line)
# AC1: the canonical skip-condition is declared, machine-readable, with the 3 required keys

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
FILE="$ROOT/templates/.sdd/actions/playwright-explore.md"

[ -f "$FILE" ] || { echo "FAIL: $FILE missing"; exit 1; }

# Extract the YAML frontmatter (between first two --- lines).
FRONTMATTER=$(awk '/^---$/{c++; next} c==1{print}' "$FILE")

python3 - "$FRONTMATTER" <<'PYEOF'
import sys, re

fm_text = sys.argv[1]
# Manual YAML parse — find the skip_when: line + its list entries.
# Don't rely on PyYAML here (kept minimal; the framework's manifest already declares PyYAML
# as a framework dep but the tests should be self-contained where possible).
lines = fm_text.split("\n")

# Locate 'skip_when:' line.
sw_idx = None
for i, ln in enumerate(lines):
    if re.match(r'^skip_when\s*:', ln):
        sw_idx = i
        break
if sw_idx is None:
    print("FAIL: T01 — no 'skip_when:' field in frontmatter")
    sys.exit(1)

# Collect indented list items below skip_when.
entries = []
i = sw_idx + 1
current = None
while i < len(lines):
    ln = lines[i]
    if re.match(r'^\S', ln):
        break  # de-indented, end of skip_when block
    if re.match(r'^\s*-\s', ln):
        if current:
            entries.append(current)
        current = {}
        # First key may be on the - line itself.
        m = re.match(r'^\s*-\s+(\w+)\s*:\s*(.*)$', ln)
        if m:
            current[m.group(1)] = m.group(2).strip().strip('"\'')
    elif current is not None:
        m = re.match(r'^\s+(\w+)\s*:\s*(.*)$', ln)
        if m:
            current[m.group(1)] = m.group(2).strip().strip('"\'')
    i += 1
if current:
    entries.append(current)

if not entries:
    print("FAIL: T01 — skip_when: block exists but has no list entries")
    sys.exit(1)

entry = entries[0]
for key in ("condition", "detect", "log_line"):
    if key not in entry or not entry[key]:
        print(f"FAIL: T01 — skip_when[0] missing required key '{key}' (got keys: {sorted(entry.keys())})")
        sys.exit(1)

print("PASS: T01 — playwright-explore.md frontmatter has skip_when[0] with condition/detect/log_line")
PYEOF
