#!/usr/bin/env bash
# T222 — AC3 — sentinel marker emitted on truncation with exact
# byte-count substitution. The literal string is
#   [truncated to <N> bytes per per-file budget — re-read with the
#    Read tool if you need the cut portion]
# where <N> is the count of bytes cut from the file.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/user-prompt-submit.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/.sdd"
cat > "$tmp/.sdd/INDEX.md" <<'IDX'
# Test INDEX
**Active:** features/001-test
**Playbook:** feature
**Active blocker:** §1
IDX

cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    cap_total_chars: 100000
    per_file_budget_chars:
      patterns: 1000
      INDEX: 3000
      spec: 5000
      principles: 2000
      stack: 3000
      data-model: 3000
---
CFG

# patterns.md = 3500 chars. Budget = 1000. Expected cut = 2500.
python3 -c "print('P' * 3500, end='')" > "$tmp/.sdd/patterns.md"

out=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null || true)

fails=()
expected="[truncated to 2500 bytes per per-file budget — re-read with the Read tool if you need the cut portion]"

if ! printf '%s' "$out" | grep -qF -- "$expected"; then
  fails+=("expected sentinel literal: $expected")
fi

# Verify exact kept-byte count
pat_sec=$(printf '%s' "$out" | awk '/--- .sdd\/patterns\.md ---/{f=1;next} f&&/^--- /{exit} f&&/^\[END/{exit} f')
p_count=$(printf '%s' "$pat_sec" | tr -cd 'P' | wc -c | tr -d ' ')
if [ "$p_count" -ne 1000 ]; then
  fails+=("patterns.md kept-bytes: expected 1000 P's, got $p_count")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T222 — AC3 sentinel format violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T222 — AC3 sentinel string + exact byte-count substitution (cut=2500, kept=1000)"
