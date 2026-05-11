#!/usr/bin/env bash
# T234 — AC15 — one-byte-over boundary: corpus file at exactly
# <budget> + 1 chars on disk; hook truncates to <budget> chars +
# sentinel with <N> = 1.

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

# patterns.md = exactly 101 bytes (budget will be 100, expect cut=1).
python3 -c "import sys; sys.stdout.buffer.write(b'P' * 101)" > "$tmp/.sdd/patterns.md"
disk_size=$(wc -c < "$tmp/.sdd/patterns.md" | tr -d ' ')
[ "$disk_size" = "101" ] || { echo "FAIL: fixture wrong, expected 101 got $disk_size"; exit 1; }

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
      stack: 3000
      data-model: 3000
      patterns: 100
---
CFG

out=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null); rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: T234 — hook exited non-zero (rc=$rc)"
  exit 1
fi

pat_sec=$(printf '%s' "$out" | awk '/--- .sdd\/patterns\.md ---/{f=1;next} f&&/^--- /{exit} f&&/^\[END/{exit} f')

fails=()

# Sentinel should report exactly 1 byte cut.
if ! printf '%s' "$pat_sec" | grep -qF "truncated to 1 bytes per per-file budget"; then
  fails+=("expected sentinel 'truncated to 1 bytes' (file=101, budget=100, cut=1)")
  echo "Section content:"
  printf '%s\n' "$pat_sec" | head -3
fi

# Kept bytes should be exactly 100 P's.
p_count=$(printf '%s' "$pat_sec" | tr -cd 'P' | wc -c | tr -d ' ')
if [ "$p_count" -ne 100 ]; then
  fails+=("kept P count: expected 100, got $p_count")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T234 — AC15 one-byte-over violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T234 — AC15 1-byte-over boundary: budget=100, file=101 → kept=100 P's + sentinel 'truncated to 1 bytes'"
