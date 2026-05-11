#!/usr/bin/env bash
# T230 — AC11 — multi-file overflow: every corpus file exceeds its
# budget on disk; hook output contains at least one byte of each
# corpus file plus the sentinel line for each truncated file. No
# corpus file is dropped wholesale from the injection.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/user-prompt-submit.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.sdd"

# Each file gets 1000 chars of distinct sigil; budget 100 each.
cat > "$tmp/.sdd/INDEX.md" <<'IDX'
**Active:** features/001-test
**Playbook:** feature
**Active blocker:** §1
IDX

mkdir -p "$tmp/.sdd/features/001-test"
python3 -c "print('S' * 1000)" > "$tmp/.sdd/features/001-test/spec.md"
python3 -c "print('R' * 1000)" > "$tmp/.sdd/principles.md"
python3 -c "print('T' * 1000)" > "$tmp/.sdd/stack.md"
python3 -c "print('D' * 1000)" > "$tmp/.sdd/data-model.md"
python3 -c "print('P' * 1000)" > "$tmp/.sdd/patterns.md"

cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    cap_total_chars: 100000
    per_file_budget_chars:
      INDEX: 100
      spec: 100
      principles: 100
      stack: 100
      data-model: 100
      patterns: 100
---
CFG

out=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null); rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: T230 — hook exited non-zero (rc=$rc)"
  exit 1
fi

fails=()

# Each corpus file should appear with at least 1 byte of content.
# CR cycle 1 #5: spec.md must be in the header check too — every
# corpus file means EVERY, including the active spec.
for hdr in ".sdd/INDEX.md" "/spec.md" ".sdd/principles.md" ".sdd/stack.md" ".sdd/data-model.md" ".sdd/patterns.md"; do
  if ! printf '%s' "$out" | grep -qF -- "$hdr"; then
    fails+=("missing header for $hdr (file dropped wholesale)")
  fi
done

# Count sentinels — should be one per truncated file.
# Fixture: spec.md, principles.md, stack.md, data-model.md, patterns.md
# are each 1000 chars > 100 budget = 5 truncations. INDEX.md is small
# (tiny fixture) = no sentinel. CR cycle 1 #6: tighten the bound to
# match the fixture (was ≥4 — weaker than the test's own setup).
sentinel_count=$(printf '%s' "$out" | grep -c "per per-file budget" || true)
if [ "$sentinel_count" -lt 5 ]; then
  fails+=("expected ≥5 per-file sentinels (spec + principles + stack + data-model + patterns), got $sentinel_count")
fi

# CR cycle 1 #7: sigil assertions scoped to each file's section, not
# whole-output greps (which could pass on unrelated text containing
# the sigil — e.g. "Resolve" contains R, "Test" contains T, etc).
extract_section() {
  local hdr_pat="$1"
  printf '%s' "$out" | awk -v pat="$hdr_pat" '
    $0 ~ pat        { found=1; next }
    found && /^--- / { exit }
    found && /^\[END PROJECT DATA\]/ { exit }
    found            { print }
  '
}
for sigil_pair in "R:principles" "T:stack" "D:data-model" "P:patterns"; do
  sigil="${sigil_pair%%:*}"
  fname="${sigil_pair##*:}"
  sec=$(extract_section "--- .sdd/$fname.md")
  count=$(printf '%s' "$sec" | tr -cd "$sigil" | wc -c | tr -d ' ')
  if [ "$count" -lt 100 ]; then
    fails+=("$fname section: expected ≥100 '$sigil' chars in its section, got $count")
  fi
done

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T230 — AC11 multi-file overflow violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T230 — AC11 multi-file overflow: every corpus file present + $sentinel_count per-file sentinels"
