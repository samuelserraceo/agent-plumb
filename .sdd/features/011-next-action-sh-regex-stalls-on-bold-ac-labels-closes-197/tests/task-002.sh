#!/usr/bin/env bash
# T02: prose-emphasis ** stays in the hash input (only LIST-ITEM AC/T/C- labels stripped)
# AC2: scope of the strip is the canonical label pattern only

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
HASH="$ROOT/templates/.sdd/scripts/hash-section.sh"
ACTION="$ROOT/templates/.sdd/actions/acceptance-criteria.md"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Fixture A: prose-emphasis ** around "Note"
cat > "$SCRATCH/spec-prose-bold.md" <<EOF
---
title: prose-emphasis-test
---

### action: acceptance-criteria

#### §11 ACs
- [ ] AC1: form works
**Note:** all ACs must have tests
EOF

# Fixture B: same but with prose ** removed
cat > "$SCRATCH/spec-prose-plain.md" <<EOF
---
title: prose-emphasis-test
---

### action: acceptance-criteria

#### §11 ACs
- [ ] AC1: form works
Note: all ACs must have tests
EOF

H1=$(bash "$HASH" "$SCRATCH/spec-prose-bold.md" "$ACTION")
H2=$(bash "$HASH" "$SCRATCH/spec-prose-plain.md" "$ACTION")

# Prose-emphasis ** is NOT a list-item AC/T/C- label — the strip should leave
# it intact. So changing it WOULD change the hash. Asserting INEQUALITY here.
[ "$H1" != "$H2" ] || { echo "FAIL: prose-emphasis ** got stripped — strip is too aggressive (would break sections with intentional ** emphasis)"; exit 1; }
echo "PASS: T02 — bold-strip is scoped to list-item AC/T/C- labels only; prose ** preserved"
