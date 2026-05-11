#!/usr/bin/env bash
# T221 — AC2 — user-prompt-submit.sh reads the per-file budget map
# via the helper resolver and applies each file's budget independently
# when concatenating corpus files for injection.
#
# Test: build a fresh fixture project with 3 of 6 corpus files
# exceeding their budgets. Run the hook. Assert output shows EACH
# corpus file present up to its budget — no file dropped wholesale,
# no file truncated based on accumulated upstream size.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/user-prompt-submit.sh"
HELPER="$FRAMEWORK_ROOT/templates/.sdd/scripts/get-injection-budget.sh"

if [ ! -f "$HOOK" ]; then
  echo "FAIL: T221 — hook missing at $HOOK"
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/.sdd/scripts"
cp "$HELPER" "$tmp/.sdd/scripts/" 2>/dev/null || true

cat > "$tmp/.sdd/INDEX.md" <<'IDX'
# Test INDEX

**Active:** features/001-test
**Playbook:** feature
**Active blocker:** § (SPEC action: brief-intake)

## In flight
- features/001-test — test (PHASE: SPEC)
IDX

mkdir -p "$tmp/.sdd/features/001-test"
cat > "$tmp/.sdd/features/001-test/spec.md" <<'SPEC'
---
playbook: feature
---

# Test feature

[PHASE: SPEC]

**Active blocker:** §1

## PHASE: SPEC

### action: brief-intake
- [ ] brief: small content under spec budget
SPEC

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
      stack: 100
      data-model: 100
      patterns: 100
---
CFG

# stack/data-model/patterns deliberately given tiny 100-char budgets;
# create files much bigger than that so each must truncate.
python3 -c "print('X' * 500, end='')" > "$tmp/.sdd/stack.md"
python3 -c "print('Y' * 500, end='')" > "$tmp/.sdd/data-model.md"
python3 -c "print('Z' * 500, end='')" > "$tmp/.sdd/patterns.md"

# Run the hook with PROJECT_DIR pointed at the fixture.
out=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null || true)

fails=()

# Assertion 1: every corpus file header appears in output (none dropped).
# Use `grep -- ...` to stop option parsing on the leading dashes.
for hdr in "--- .sdd/INDEX.md" "/spec.md" "--- .sdd/stack.md" "--- .sdd/data-model.md" "--- .sdd/patterns.md"; do
  if ! printf '%s' "$out" | grep -qF -- "$hdr"; then
    fails+=("missing header: $hdr")
  fi
done

# Assertion 2/3/4: budget independence — extract each corpus file's
# section from the hook output (everything between its `--- FILE ---`
# header and the next `---` or `[END PROJECT DATA]`). Count the X/Y/Z
# sigil chars WITHIN that section, not across the whole output (the
# word "INDEX" elsewhere in the output also contains an X, otherwise
# leaking into a global tr -cd 'X' count).
extract_section() {
  local hdr_pat="$1"
  printf '%s' "$out" | awk -v pat="$hdr_pat" '
    $0 ~ pat        { found=1; next }
    found && /^--- / { exit }
    found && /^\[END PROJECT DATA\]/ { exit }
    found            { print }
  '
}

# stack.md section — expect 100 X's plus sentinel line.
stack_sec=$(extract_section "--- .sdd/stack.md")
x_count=$(printf '%s' "$stack_sec" | tr -cd 'X' | wc -c | tr -d ' ')
if [ "$x_count" -ne 100 ]; then
  fails+=("stack.md kept-bytes count: expected 100 X's in stack section, got $x_count")
fi
if ! printf '%s' "$stack_sec" | grep -q "truncated to 400 bytes per per-file budget"; then
  fails+=("stack.md sentinel missing or wrong byte count (expected 'truncated to 400')")
fi

# data-model.md section — expect 100 Y's plus sentinel.
dm_sec=$(extract_section "--- .sdd/data-model.md")
y_count=$(printf '%s' "$dm_sec" | tr -cd 'Y' | wc -c | tr -d ' ')
if [ "$y_count" -ne 100 ]; then
  fails+=("data-model.md kept-bytes count: expected 100 Y's in section, got $y_count")
fi
# CR cycle 1 #3: also assert the sentinel fired for data-model.md.
if ! printf '%s' "$dm_sec" | grep -q "truncated to 400 bytes per per-file budget"; then
  fails+=("data-model.md sentinel missing or wrong byte count (expected 'truncated to 400')")
fi

# patterns.md section — expect 100 Z's plus sentinel. This is the
# decisive AC2 assertion: patterns.md is 5th in injection order;
# even though stack.md + data-model.md each truncated upstream,
# patterns.md still gets its own 100-char allocation.
pat_sec=$(extract_section "--- .sdd/patterns.md")
z_count=$(printf '%s' "$pat_sec" | tr -cd 'Z' | wc -c | tr -d ' ')
if [ "$z_count" -ne 100 ]; then
  fails+=("patterns.md kept-bytes count: expected 100 Z's in section, got $z_count")
fi
# CR cycle 1 #3: also assert the sentinel fired for patterns.md.
if ! printf '%s' "$pat_sec" | grep -q "truncated to 400 bytes per per-file budget"; then
  fails+=("patterns.md sentinel missing or wrong byte count (expected 'truncated to 400')")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T221 — AC2 per-file budget independence violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  echo "---"
  echo "Hook output (first 60 lines):"
  printf '%s' "$out" | head -60
  exit 1
fi

echo "PASS: T221 — AC2 each corpus file truncated to its own budget independently (X/Y/Z counts each = 100, sentinels emitted on truncation)"
