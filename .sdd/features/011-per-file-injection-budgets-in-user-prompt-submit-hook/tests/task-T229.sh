#!/usr/bin/env bash
# T229 — AC10 — sum-overshoot: project config.md sets per-file
# budgets summing above 16000; hook applies per-file truncation first,
# then total-cap clip on the tail. Final output length bounded by
# cap_total_chars.

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

# Per-file budgets sum to 30000 (5000 × 6) under a 5000 cap_total.
cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    cap_total_chars: 5000
    per_file_budget_chars:
      INDEX: 5000
      spec: 5000
      principles: 5000
      stack: 5000
      data-model: 5000
      patterns: 5000
---
CFG

# Each corpus file gets 4000 chars on disk — fits its per-file budget
# (no per-file truncation) but the combined output still overshoots
# cap_total_chars (5000) because 3 × 4000 = 12000 > 5000.
for f in stack data-model patterns; do
  python3 -c "print('S' * 4000, end='')" > "$tmp/.sdd/$f.md"
done

out=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null || true)
size=${#out}

# After cap clip + Theme 11 closer markers, total output should be
# near 5000 + closer overhead (~500). Allow generous headroom.
if [ "$size" -gt 5800 ]; then
  echo "FAIL: T229 — sum-overshoot output ($size bytes) exceeds cap envelope (~5800)"
  exit 1
fi

# Theme 11 TRUNCATED sentinel should fire.
if ! printf '%s' "$out" | grep -q "TRUNCATED"; then
  echo "FAIL: T229 — Theme 11 TRUNCATED sentinel missing on sum-overshoot path"
  exit 1
fi

# Per-file budget was NOT exceeded (each file 4000 ≤ 5000) — so no
# per-file sentinel should appear (only the total-cap one).
if printf '%s' "$out" | grep -q "per per-file budget"; then
  echo "FAIL: T229 — unexpected per-file sentinel; only total-cap sentinel expected"
  exit 1
fi

echo "PASS: T229 — AC10 sum-overshoot: per-file passes through (no per-file sentinels), then cap_total_chars=5000 clips combined output ($size bytes)"
