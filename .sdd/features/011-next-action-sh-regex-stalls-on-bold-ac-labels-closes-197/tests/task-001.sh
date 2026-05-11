#!/usr/bin/env bash
# T01: hash-section.sh strips ** around AC/T/C- list-item labels before hashing
# AC1: bold and plain forms produce the same hash within the same section context

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
HASH="$ROOT/templates/.sdd/scripts/hash-section.sh"
ACTION="$ROOT/templates/.sdd/actions/acceptance-criteria.md"

[ -f "$HASH" ] || { echo "FAIL: $HASH missing"; exit 1; }
[ -f "$ACTION" ] || { echo "FAIL: $ACTION missing"; exit 1; }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Fixture A: bold AC labels
cat > "$SCRATCH/spec-bold.md" <<EOF
---
title: bold-vs-plain-test
---

### action: acceptance-criteria

#### §11 ACs
- [ ] **AC1:** form submission works
- [ ] **AC2:** invalid input rejected
EOF

# Fixture B: plain AC labels (semantically identical)
cat > "$SCRATCH/spec-plain.md" <<EOF
---
title: bold-vs-plain-test
---

### action: acceptance-criteria

#### §11 ACs
- [ ] AC1: form submission works
- [ ] AC2: invalid input rejected
EOF

H1=$(bash "$HASH" "$SCRATCH/spec-bold.md" "$ACTION")
H2=$(bash "$HASH" "$SCRATCH/spec-plain.md" "$ACTION")

[ "$H1" = "$H2" ] || { echo "FAIL: bold hash ($H1) != plain hash ($H2) — bold-strip normalisation missing"; exit 1; }
echo "PASS: T01 — hash-section.sh normalises bold AC labels to plain (same hash)"
