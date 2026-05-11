#!/usr/bin/env bash
# T03: cold-feature skip — folder with .shipped marker is left alone
# AC3: shipped features are inert; the migrator must NOT touch their PHASE

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
SCRIPT="$ROOT/templates/.sdd/scripts/promote-legacy-queued.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Fixture: a feature with [PHASE: SPEC] (which on its own would migrate),
# INDEX row says queued, BUT a .shipped marker is present.
# Cold-feature rule wins — script must skip and not flip.
mkdir -p "$SCRATCH/.sdd/features/004-shipped-feat"
cat > "$SCRATCH/.sdd/features/004-shipped-feat/spec.md" <<'EOF'
---
playbook: feature
---

# Shipped feature (cold)

[PHASE: SPEC]

(legacy spec content from before .shipped landed)
EOF
touch "$SCRATCH/.sdd/features/004-shipped-feat/.shipped"

cat > "$SCRATCH/.sdd/INDEX.md" <<'EOF'
# Project Index

**Active:** _(none)_

## In flight

(none)

## Backlog

- features/004-shipped-feat — queued (legacy row from before this shipped)

## Shipped

(none)
EOF

cd "$SCRATCH" && git init -q && git config user.email "t03@test.local" && git config user.name "T03" && git add -A && git commit -q -m "initial fixture"

OUT=$(bash "$SCRIPT" 2>&1)

# Assert spec.md PHASE STILL says SPEC (cold feature was not touched).
grep -qE '^\[PHASE: SPEC\]' "$SCRATCH/.sdd/features/004-shipped-feat/spec.md" \
  || { echo "FAIL: cold feature .shipped marker ignored — script flipped its PHASE."; cat "$SCRATCH/.sdd/features/004-shipped-feat/spec.md"; exit 1; }

# Assert migrated count is 0.
echo "$OUT" | grep -qE 'migrated:  0' || { echo "FAIL: migrated count should be 0: $OUT"; exit 1; }

# Assert "1 already SHIPPED" in unchanged summary.
echo "$OUT" | grep -qE '1 already SHIPPED' || { echo "FAIL: unchanged summary missing 'already SHIPPED' breakdown: $OUT"; exit 1; }

echo "PASS: T03 — promote-legacy-queued.sh respects .shipped marker (cold feature skipped)"
