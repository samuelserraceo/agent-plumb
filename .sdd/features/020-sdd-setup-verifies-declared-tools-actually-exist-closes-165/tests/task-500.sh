#!/usr/bin/env bash
# T500 — AC1 walking-skeleton — verify-stack.sh exists at templates path,
# is manifest-pinned in both live + template manifests, and with empty
# parameters.review.bot + parameters.mcp.tier3.* + no declared test
# runner, the script exits 0 and prints exactly one line:
# "no declared tools to verify".
#
# AC1 — Default behaviour when no parameters declared.
# Backwards-compat: no-op when nothing is declared.

set -uo pipefail

FRAMEWORK_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
TEMPLATE_SCRIPT="$FRAMEWORK_ROOT/templates/.sdd/scripts/verify-stack.sh"
LIVE_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/verify-stack.sh"
LIVE_MANIFEST="$FRAMEWORK_ROOT/.sdd/.cache/manifest.json"
TPL_MANIFEST="$FRAMEWORK_ROOT/templates/.sdd/.cache/manifest.json"

fails=()

# --- 1. Template script exists ---------------------------------------
[ -f "$TEMPLATE_SCRIPT" ] \
  || fails+=("templates/.sdd/scripts/verify-stack.sh missing")

# --- 2. Live script exists (mirrored) --------------------------------
[ -f "$LIVE_SCRIPT" ] \
  || fails+=(".sdd/scripts/verify-stack.sh missing (template not mirrored to live)")

# --- 3. Manifest entries pin verify-stack.sh in BOTH manifests -------
for m in "$LIVE_MANIFEST" "$TPL_MANIFEST"; do
  [ -f "$m" ] || { fails+=("manifest missing: $m"); continue; }
  python3 - "$m" <<'PYEOF' || fails+=("verify-stack.sh not pinned in $(basename "$m")")
import json, sys
with open(sys.argv[1]) as f:
    m = json.load(f)
entry = m.get("scripts", {}).get("verify-stack.sh")
if not entry:
    sys.exit(1)
if "expected_sha256" not in entry or not entry["expected_sha256"]:
    sys.exit(1)
if entry.get("path") != ".sdd/scripts/verify-stack.sh":
    sys.exit(1)
PYEOF
done

# --- 4. Empty-params fixture: exits 0 + prints exact line ------------
if [ -f "$TEMPLATE_SCRIPT" ]; then
  WORK="$(mktemp -d -t sdd-t500.XXXXXX)"
  trap 'rm -rf "$WORK"' EXIT

  mkdir -p "$WORK/.sdd"
  # Minimal config.md with all relevant parameters EMPTY.
  cat > "$WORK/.sdd/config.md" <<'EOF'
---
type: config
sdd_version: 1.0.0
parameters:
  review:
    bot: ""
  mcp:
    tier3:
      enabled: false
  test_runner: ""
---

# config
EOF
  # Empty stack.md — no declared required-checks, no declared test runner.
  cat > "$WORK/.sdd/stack.md" <<'EOF'
# stack
EOF

  OUT="$( cd "$WORK" && CLAUDE_PROJECT_DIR="$WORK" bash "$TEMPLATE_SCRIPT" 2>&1 )"
  RC=$?

  [ "$RC" -eq 0 ] || fails+=("empty-params: expected exit 0, got $RC (output: $OUT)")
  [ "$OUT" = "no declared tools to verify" ] \
    || fails+=("empty-params: expected exact line 'no declared tools to verify', got: '$OUT'")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T500 — walking-skeleton violations:"
  for e in "${fails[@]}"; do echo "  - $e"; done
  exit 1
fi

echo "PASS: T500 — verify-stack.sh walking-skeleton + manifest pin + empty-params no-op"
