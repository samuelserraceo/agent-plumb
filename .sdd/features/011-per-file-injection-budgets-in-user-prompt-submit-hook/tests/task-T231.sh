#!/usr/bin/env bash
# T231 — AC12 — determinism: running the hook twice on the same
# corpus + same config produces byte-identical output.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/user-prompt-submit.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.sdd"

cat > "$tmp/.sdd/INDEX.md" <<'IDX'
**Active:** features/001-test
**Playbook:** feature
**Active blocker:** §1
IDX

python3 -c "print('content', 'A' * 5000)" > "$tmp/.sdd/patterns.md"
python3 -c "print('content', 'B' * 1500)" > "$tmp/.sdd/stack.md"

cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    cap_total_chars: 100000
    per_file_budget_chars:
      INDEX: 3000
      spec: 5000
      principles: 2000
      stack: 1000
      data-model: 3000
      patterns: 2000
---
CFG

# Two consecutive runs. CR cycle 1 #8: fail fast if either run errors
# — a hook crash with empty stdout could spuriously "pass" the
# byte-identical check below (both empty). Capture exit codes and
# require both to be 0.
out1=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null); rc1=$?
out2=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null); rc2=$?
if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ]; then
  echo "FAIL: T231 — hook exited non-zero (rc1=$rc1, rc2=$rc2); cannot validate determinism on a broken run"
  exit 1
fi
if [ -z "$out1" ] || [ -z "$out2" ]; then
  echo "FAIL: T231 — hook produced empty output; cannot validate determinism"
  exit 1
fi

if [ "$out1" != "$out2" ]; then
  echo "FAIL: T231 — AC12 determinism violation: two consecutive runs produced different output"
  diff <(printf '%s' "$out1") <(printf '%s' "$out2") | head -20
  exit 1
fi

# A third run for good measure.
out3=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null)
if [ "$out1" != "$out3" ]; then
  echo "FAIL: T231 — AC12 determinism: run #3 differs from run #1"
  exit 1
fi

# Verify the sentinel is byte-count-substituted, not time-based.
if printf '%s' "$out1" | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{2}:[0-9]{2}:[0-9]{2}"; then
  # OK if it's from spec.md content (timestamps in approvals etc).
  # We only care that the SENTINEL line itself has no time-based field.
  if printf '%s' "$out1" | grep "per per-file budget" | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{2}:[0-9]{2}:[0-9]{2}"; then
    echo "FAIL: T231 — sentinel contains time-based field (would break determinism across days)"
    exit 1
  fi
fi

echo "PASS: T231 — AC12 determinism: 3 consecutive runs produced byte-identical output; sentinel has no time-based field"
