#!/usr/bin/env bash
# T01: session-start.sh emits [SDD bootstrap] ready line on first install
# AC1: signal fires on fresh .sdd/ (no .shipped markers); suppresses for returning users

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
HOOK="$ROOT/templates/.claude/hooks/session-start.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# === Case 1: fresh install — no .shipped markers ===
mkdir -p "$SCRATCH/.sdd/features"
cat > "$SCRATCH/.sdd/INDEX.md" <<'EOF'
# Project Index

**Active:** _(none)_

## In flight

(none)

## Shipped

(none)
EOF

OUT_FRESH=$(CLAUDE_PROJECT_DIR="$SCRATCH" bash "$HOOK" 2>&1)
echo "$OUT_FRESH" | grep -qE '\[SDD bootstrap\] ready' \
  || { echo "FAIL: bootstrap-ready signal not emitted on fresh install"; echo "---OUT---"; echo "$OUT_FRESH"; exit 1; }

# === Case 2: returning user — at least one .shipped marker ===
mkdir -p "$SCRATCH/.sdd/features/001-some-feat"
touch "$SCRATCH/.sdd/features/001-some-feat/.shipped"

OUT_RETURN=$(CLAUDE_PROJECT_DIR="$SCRATCH" bash "$HOOK" 2>&1)
echo "$OUT_RETURN" | grep -qE '\[SDD bootstrap\] ready' \
  && { echo "FAIL: bootstrap-ready signal fired on returning user (.shipped marker present)"; echo "---OUT---"; echo "$OUT_RETURN"; exit 1; }

echo "PASS: T01 — session-start.sh emits bootstrap-ready signal on fresh install + suppresses for returning user"
