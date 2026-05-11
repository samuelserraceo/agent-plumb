#!/usr/bin/env bash
# T01: promote-legacy-queued.sh flips spec.md PHASE + canonicalises INDEX row
# AC1: happy-path migration on a fixture with one legacy backlog feature

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
SCRIPT="$ROOT/templates/.sdd/scripts/promote-legacy-queued.sh"

[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT missing — T01 RED until script exists"; exit 1; }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Build fixture: a downstream-shaped project with one legacy backlog feature.
mkdir -p "$SCRATCH/.sdd/features/002-legacy-backlog-feat"
cat > "$SCRATCH/.sdd/features/002-legacy-backlog-feat/spec.md" <<'EOF'
---
playbook: feature
---

# Legacy backlog feature

[PHASE: SPEC]

**Active blocker:** §1 problem

## PHASE: SPEC

### action: brief-intake

- [ ] brief: tbd
EOF

cat > "$SCRATCH/.sdd/INDEX.md" <<'EOF'
# Project Index

**Active:** _(none)_

## In flight

(none)

## Backlog

- features/002-legacy-backlog-feat — queued waiting for promote-to-active

## Shipped

(none)
EOF

# Init git so the script's `git add` works.
cd "$SCRATCH" && git init -q && git config user.email "t01@test.local" && git config user.name "T01" && git add -A && git commit -q -m "initial fixture"

# Run the script — must flip spec.md PHASE + canonicalise INDEX row.
OUT=$(bash "$SCRIPT" 2>&1)

# Assert spec.md PHASE flipped to QUEUED.
grep -qE '^\[PHASE: QUEUED\]' "$SCRATCH/.sdd/features/002-legacy-backlog-feat/spec.md" \
  || { echo "FAIL: spec.md PHASE not flipped to QUEUED."; echo "--- spec.md ---"; cat "$SCRATCH/.sdd/features/002-legacy-backlog-feat/spec.md"; exit 1; }

# Assert INDEX row now canonical.
grep -qE '\(scaffolded, PHASE: QUEUED\)' "$SCRATCH/.sdd/INDEX.md" \
  || { echo "FAIL: INDEX.md row not canonicalised."; echo "--- INDEX.md ---"; cat "$SCRATCH/.sdd/INDEX.md"; exit 1; }

# Assert the 5-line summary fired.
echo "$OUT" | grep -qE 'inspected: 1' || { echo "FAIL: summary missing inspected count: $OUT"; exit 1; }
echo "$OUT" | grep -qE 'migrated:  1' || { echo "FAIL: summary missing migrated count: $OUT"; exit 1; }
echo "$OUT" | grep -qE 'INDEX.md:  1' || { echo "FAIL: summary missing INDEX update count: $OUT"; exit 1; }

# Assert script staged the changes (git diff --cached shows the touched files).
cd "$SCRATCH" && git diff --cached --name-only | grep -qE 'spec\.md|INDEX\.md' \
  || { echo "FAIL: script did not stage the touched files"; exit 1; }

echo "PASS: T01 — promote-legacy-queued.sh migrates a legacy backlog feature end-to-end"
