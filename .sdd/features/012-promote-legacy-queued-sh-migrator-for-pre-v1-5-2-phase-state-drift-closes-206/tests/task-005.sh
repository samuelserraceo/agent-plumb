#!/usr/bin/env bash
# T05: idempotence — running twice in a row is a no-op on the second run
# AC5: migrator is safe to re-run; second run reports 0 migrated, all canonical

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
SCRIPT="$ROOT/templates/.sdd/scripts/promote-legacy-queued.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Fixture: one legacy backlog feature (same shape as T01).
mkdir -p "$SCRATCH/.sdd/features/006-idempotent-feat"
cat > "$SCRATCH/.sdd/features/006-idempotent-feat/spec.md" <<'EOF'
---
playbook: feature
---

# Idempotent feature

[PHASE: SPEC]
EOF

cat > "$SCRATCH/.sdd/INDEX.md" <<'EOF'
# Project Index

**Active:** _(none)_

## Backlog

- features/006-idempotent-feat — queued
EOF

cd "$SCRATCH" && git init -q && git config user.email "t05@test.local" && git config user.name "T05" && git add -A && git commit -q -m "initial fixture"

# First run: migrates 1 item.
OUT1=$(bash "$SCRIPT" 2>&1)
echo "$OUT1" | grep -qE 'migrated:  1' || { echo "FAIL: first run should have migrated 1: $OUT1"; exit 1; }

# Snapshot the state after first run.
SPEC_AFTER_FIRST=$(cat "$SCRATCH/.sdd/features/006-idempotent-feat/spec.md")
INDEX_AFTER_FIRST=$(cat "$SCRATCH/.sdd/INDEX.md")

# Commit first run's changes so the second run sees a clean working tree.
cd "$SCRATCH" && git add -A && git commit -q -m "first migration"

# Second run: should be a no-op.
OUT2=$(bash "$SCRIPT" 2>&1)
echo "$OUT2" | grep -qE 'migrated:  0' || { echo "FAIL: second run should be a no-op (migrated 0): $OUT2"; exit 1; }
echo "$OUT2" | grep -qE 'INDEX.md:  0' || { echo "FAIL: second run should have 0 INDEX updates: $OUT2"; exit 1; }

# Assert nothing changed on disk between first and second runs.
SPEC_AFTER_SECOND=$(cat "$SCRATCH/.sdd/features/006-idempotent-feat/spec.md")
INDEX_AFTER_SECOND=$(cat "$SCRATCH/.sdd/INDEX.md")
[ "$SPEC_AFTER_FIRST" = "$SPEC_AFTER_SECOND" ] || { echo "FAIL: spec.md mutated on second run (not idempotent)"; exit 1; }
[ "$INDEX_AFTER_FIRST" = "$INDEX_AFTER_SECOND" ] || { echo "FAIL: INDEX.md mutated on second run (not idempotent)"; exit 1; }

echo "PASS: T05 — promote-legacy-queued.sh is idempotent (second run is a no-op)"
