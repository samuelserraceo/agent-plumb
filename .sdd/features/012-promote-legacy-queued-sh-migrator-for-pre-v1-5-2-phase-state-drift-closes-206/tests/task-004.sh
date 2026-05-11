#!/usr/bin/env bash
# T04: partial-state guard — INDEX says queued but spec.md PHASE != SPEC
# AC4: don't flip; print a WARNING line so the user knows manual review needed

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
SCRIPT="$ROOT/templates/.sdd/scripts/promote-legacy-queued.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Fixture: INDEX row says "queued" but spec.md PHASE=BUILD (user manually advanced).
# This is a real edge case — the user may have advanced the feature past SPEC
# while the INDEX row didn't get re-edited. Script must NOT flip BUILD back to
# QUEUED; should print a warning + leave alone.
mkdir -p "$SCRATCH/.sdd/features/005-partial-state-feat"
cat > "$SCRATCH/.sdd/features/005-partial-state-feat/spec.md" <<'EOF'
---
playbook: feature
---

# Partial-state feature

[PHASE: BUILD]

(user manually advanced this past SPEC; INDEX row didn't get re-edited)
EOF

cat > "$SCRATCH/.sdd/INDEX.md" <<'EOF'
# Project Index

**Active:** _(none)_

## Backlog

- features/005-partial-state-feat — queued (legacy row)

## Shipped

(none)
EOF

cd "$SCRATCH" && git init -q && git config user.email "t04@test.local" && git config user.name "T04" && git add -A && git commit -q -m "initial fixture"

# Capture both stdout and stderr (warning goes to stderr).
OUT=$(bash "$SCRIPT" 2>&1)

# Assert spec.md PHASE STILL says BUILD (NOT flipped back to QUEUED).
grep -qE '^\[PHASE: BUILD\]' "$SCRATCH/.sdd/features/005-partial-state-feat/spec.md" \
  || { echo "FAIL: partial-state feature's BUILD PHASE got flipped — destructive."; cat "$SCRATCH/.sdd/features/005-partial-state-feat/spec.md"; exit 1; }

# Assert migrated count is 0.
echo "$OUT" | grep -qE 'migrated:  0' || { echo "FAIL: migrated should be 0 in partial-state case: $OUT"; exit 1; }

# Assert WARNING line fired with the item name + actual PHASE.
echo "$OUT" | grep -qE 'WARNING.*005-partial-state-feat.*PHASE=BUILD' \
  || { echo "FAIL: warning line missing item name + PHASE=BUILD: $OUT"; exit 1; }

echo "PASS: T04 — partial-state guard (INDEX queued + spec.md BUILD) leaves it alone with warning"
