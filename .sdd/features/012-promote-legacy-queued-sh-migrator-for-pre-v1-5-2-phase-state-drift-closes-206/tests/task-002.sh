#!/usr/bin/env bash
# T02: false-positive guard — non-canonical INDEX row → no flip
# AC2: a feature whose INDEX row does NOT say queued/Backlog stays at PHASE: SPEC

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
SCRIPT="$ROOT/templates/.sdd/scripts/promote-legacy-queued.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Fixture: a feature with [PHASE: SPEC] but an INDEX row that says it's active
# (in-flight, not queued). The script must leave it alone.
mkdir -p "$SCRATCH/.sdd/features/003-actively-in-flight"
cat > "$SCRATCH/.sdd/features/003-actively-in-flight/spec.md" <<'EOF'
---
playbook: feature
---

# Actively in-flight feature

[PHASE: SPEC]

**Active blocker:** §5 proposed-approach
EOF

cat > "$SCRATCH/.sdd/INDEX.md" <<'EOF'
# Project Index

**Active:** features/003-actively-in-flight

## In flight

- features/003-actively-in-flight — actively in-flight feature (PHASE: SPEC)

## Backlog

(none)

## Shipped

(none)
EOF

cd "$SCRATCH" && git init -q && git config user.email "t02@test.local" && git config user.name "T02" && git add -A && git commit -q -m "initial fixture"

OUT=$(bash "$SCRIPT" 2>&1)

# Assert spec.md PHASE STILL says SPEC (no flip).
grep -qE '^\[PHASE: SPEC\]' "$SCRATCH/.sdd/features/003-actively-in-flight/spec.md" \
  || { echo "FAIL: false positive — script flipped a non-queued feature's PHASE."; cat "$SCRATCH/.sdd/features/003-actively-in-flight/spec.md"; exit 1; }

# Assert INDEX row unchanged.
grep -qE 'features/003-actively-in-flight — actively in-flight feature \(PHASE: SPEC\)$' "$SCRATCH/.sdd/INDEX.md" \
  || { echo "FAIL: INDEX row mutated when it shouldn't be."; cat "$SCRATCH/.sdd/INDEX.md"; exit 1; }

# Assert migrated count is 0.
echo "$OUT" | grep -qE 'migrated:  0' || { echo "FAIL: migrated count should be 0: $OUT"; exit 1; }

echo "PASS: T02 — promote-legacy-queued.sh leaves non-canonical INDEX rows + their specs alone"
