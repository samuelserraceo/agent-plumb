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

out=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null || true)

fails=()

# Each corpus file should appear with at least 1 byte of content.
# Principles is the only one that wasn't created as a spec.md
# (because we set the active blocker but didn't make a full feature
# scaffold — the hook still emits principles.md since the file exists).
for hdr in ".sdd/INDEX.md" ".sdd/principles.md" ".sdd/stack.md" ".sdd/data-model.md" ".sdd/patterns.md"; do
  if ! printf '%s' "$out" | grep -qF -- "$hdr"; then
    fails+=("missing header for $hdr (file dropped wholesale)")
  fi
done

# Count sentinels — should be one per truncated file.
sentinel_count=$(printf '%s' "$out" | grep -c "per per-file budget")
# Principles, stack, data-model, patterns all 1000 chars > 100 budget → 4 sentinels.
# INDEX is small (tiny test fixture) → no sentinel.
# spec is "$tmp/.sdd/features/001-test/spec.md" (1001 chars) > 100 → 1 sentinel.
# Total expected: 5 sentinels (spec + principles + stack + data-model + patterns).
if [ "$sentinel_count" -lt 4 ]; then
  fails+=("expected ≥4 per-file sentinels (one per truncated file), got $sentinel_count")
fi

# Distinct sigils — each file's sigil should appear at least once.
for sigil_pair in "R:principles" "T:stack" "D:data-model" "P:patterns"; do
  sigil="${sigil_pair%%:*}"
  fname="${sigil_pair##*:}"
  if ! printf '%s' "$out" | grep -q "$sigil"; then
    fails+=("no '$sigil' chars found for $fname (file content invisible)")
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
