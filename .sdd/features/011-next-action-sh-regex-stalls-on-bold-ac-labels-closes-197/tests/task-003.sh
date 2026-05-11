#!/usr/bin/env bash
# T03: plain-label sections (no ** anywhere) hash unchanged after the fix
# AC3: regression-lock for existing approved sections that have no ** markers
#
# Mechanical: hash a plain-label section with the current hash-section.sh,
# then assert the hash is a STABLE KNOWN value (the pre-fix value for the
# same content). This pins backward-compat: existing approved sections
# stay approved.

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
HASH="$ROOT/templates/.sdd/scripts/hash-section.sh"
ACTION="$ROOT/templates/.sdd/actions/acceptance-criteria.md"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Fixture: plain-label section, no ** markers anywhere
cat > "$SCRATCH/spec-plain.md" <<EOF
---
title: regression-lock-test
---

### action: acceptance-criteria

#### §11 ACs
- [ ] AC1: form submission works
- [ ] AC2: invalid input rejected
EOF

# Expected hash: stable, computed once before the bold-strip patch landed and
# verified to still match post-fix. (Captured by manually running the script
# against this exact fixture during T01 RED-state.)
EXPECTED="9c148b6b3cb6b7e1ef3ba53c09aed409fa2137f8742228d7976cc0446578700d"

GOT=$(bash "$HASH" "$SCRATCH/spec-plain.md" "$ACTION")
[ "$GOT" = "$EXPECTED" ] || { echo "FAIL: plain-label hash changed after bold-strip patch — regression on existing approved sections. expected=$EXPECTED got=$GOT"; exit 1; }
echo "PASS: T03 — plain-label hash stable post-fix (existing approved sections preserved)"
