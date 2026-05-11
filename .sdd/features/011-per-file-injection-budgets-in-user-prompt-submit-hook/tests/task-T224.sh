#!/usr/bin/env bash
# T224 — AC5 — cap_total_chars stays in templates/.sdd/config.md and
# the hook applies it as a defensive safety-net floor on combined
# output (AFTER per-file truncation runs).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CFG="$FRAMEWORK_ROOT/templates/.sdd/config.md"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/user-prompt-submit.sh"

# Part A: cap_total_chars present in framework defaults. Cap was
# raised 16000 → 25000 (CR cycle 1 #13) so per-file truncation
# (defaults summing to 20000) doesn't immediately trip the total
# cap; cap_total_chars is a true safety net for sum-overshoot edges,
# not a common-case truncation path.
if ! python3 -c "
import yaml, re
text = open('$CFG').read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
fm = yaml.safe_load(m.group(1))
cap = fm['parameters']['injection']['cap_total_chars']
assert cap == 25000, f'expected 25000, got {cap}'
" 2>/dev/null; then
  echo "FAIL: T224 — cap_total_chars not 25000 in framework config.md"
  exit 1
fi

# Part B: hook applies the cap as defensive floor. Set per-file
# budgets summing well over the cap and verify total output is bounded.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.sdd"

cat > "$tmp/.sdd/INDEX.md" <<'IDX'
**Active:** features/001-test
**Playbook:** feature
**Active blocker:** §1
IDX

cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    cap_total_chars: 2000        # small cap for the test
    per_file_budget_chars:       # per-file budgets sum to 6000 > cap
      INDEX: 1000
      spec: 1000
      principles: 1000
      stack: 1000
      data-model: 1000
      patterns: 1000
---
CFG

# Each file: 2000 chars. Per-file budgets 1000 each → 6 files = 6000
# chars after per-file truncation. cap_total_chars = 2000 should clip.
for f in stack data-model patterns; do
  python3 -c "print('Q' * 2000, end='')" > "$tmp/.sdd/$f.md"
done

# CR cycle 3 MAJ: fail fast on hook errors + use BYTE count (wc -c)
# not ${#out} (chars under UTF-8 locale, bytes under C locale —
# inconsistent across platforms). The cap is byte-based by contract.
out=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null); rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: T224 — hook exited non-zero (rc=$rc); cannot validate cap floor"
  exit 1
fi
size=$(printf '%s' "$out" | wc -c | tr -d ' ')

# After cap clip, total output should be near cap_total_chars (2000)
# plus the Theme 11 TRUNCATED sentinel + closing markers.
# Allow generous headroom for the sentinel + closers.
if [ "$size" -gt 2800 ]; then
  echo "FAIL: T224 — combined output size ($size bytes) exceeds expected post-cap envelope (~2800 bytes)"
  echo "       cap_total_chars not applied as defensive ceiling"
  exit 1
fi
if [ "$size" -lt 1500 ]; then
  echo "FAIL: T224 — combined output suspiciously small ($size bytes); cap may have clipped too aggressively"
  exit 1
fi

# Theme 11 truncation sentinel should appear.
if ! printf '%s' "$out" | grep -q "TRUNCATED"; then
  echo "FAIL: T224 — Theme 11 TRUNCATED sentinel missing"
  exit 1
fi

echo "PASS: T224 — AC5 cap_total_chars (25000 in framework, 2000 in fixture) applies as defensive ceiling; sum-overshoot ($size bytes) bounded near cap"
