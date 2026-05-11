#!/usr/bin/env bash
# T01: user-prompt-submit.sh emits MCP-doctrine sentinel when mcp.enabled: true
# AC1: sentinel fires conditionally — gated on parameters.mcp.enabled

set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
HOOK="$ROOT/templates/.claude/hooks/user-prompt-submit.sh"

[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Build a minimal SDD project layout the hook expects.
mkdir -p "$SCRATCH/.sdd"
cat > "$SCRATCH/.sdd/INDEX.md" <<'EOF'
# Project Index

**Active:** _(none)_

## In flight

(none)

## Shipped

(none)
EOF

# === Case 1: mcp.enabled: true → sentinel fires ===
cat > "$SCRATCH/.sdd/config.md" <<'EOF'
# Project config

```yaml
parameters:
  mcp:
    enabled: true
```
EOF

cd "$SCRATCH"
OUT_ENABLED=$(CLAUDE_PROJECT_DIR="$SCRATCH" bash "$HOOK" 2>&1)

echo "$OUT_ENABLED" | grep -qE 'MCP graph queries available' \
  || { echo "FAIL: sentinel not emitted with mcp.enabled: true"; echo "---OUT---"; echo "$OUT_ENABLED" | head -20; exit 1; }

# Sentinel must reference at least 3 named queries.
echo "$OUT_ENABLED" | grep -qE 'get_backlinks' || { echo "FAIL: sentinel missing get_backlinks"; exit 1; }
echo "$OUT_ENABLED" | grep -qE 'get_neighbours' || { echo "FAIL: sentinel missing get_neighbours"; exit 1; }
echo "$OUT_ENABLED" | grep -qE 'get_pattern' || { echo "FAIL: sentinel missing get_pattern"; exit 1; }

# Sentinel must appear INSIDE the FRAMEWORK INSTRUCTIONS block (not after END).
# Find line numbers.
START_LINE=$(echo "$OUT_ENABLED" | grep -nE '^\[FRAMEWORK INSTRUCTIONS' | head -1 | cut -d: -f1)
END_LINE=$(echo "$OUT_ENABLED" | grep -nE '^\[END FRAMEWORK INSTRUCTIONS\]' | head -1 | cut -d: -f1)
SENTINEL_LINE=$(echo "$OUT_ENABLED" | grep -nE 'MCP graph queries available' | head -1 | cut -d: -f1)
[ -n "$START_LINE" ] && [ -n "$END_LINE" ] && [ -n "$SENTINEL_LINE" ] \
  || { echo "FAIL: missing trust-block markers around sentinel"; exit 1; }
[ "$SENTINEL_LINE" -gt "$START_LINE" ] && [ "$SENTINEL_LINE" -lt "$END_LINE" ] \
  || { echo "FAIL: sentinel must be INSIDE [FRAMEWORK INSTRUCTIONS] block (start=$START_LINE sentinel=$SENTINEL_LINE end=$END_LINE)"; exit 1; }

# === Case 2: mcp.enabled missing → legacy line ===
cat > "$SCRATCH/.sdd/config.md" <<'EOF'
# Project config (MCP not configured)

```yaml
parameters: {}
```
EOF

OUT_DISABLED=$(CLAUDE_PROJECT_DIR="$SCRATCH" bash "$HOOK" 2>&1)
echo "$OUT_DISABLED" | grep -qE 'no framework-trusted content injected this turn' \
  || { echo "FAIL: legacy line not emitted with mcp disabled"; echo "---OUT---"; echo "$OUT_DISABLED" | head -10; exit 1; }
echo "$OUT_DISABLED" | grep -qE 'MCP graph queries available' \
  && { echo "FAIL: sentinel fired when mcp was NOT enabled (false positive)"; exit 1; }

echo "PASS: T01 — user-prompt-submit.sh emits MCP-doctrine sentinel when mcp.enabled: true; legacy line otherwise"
