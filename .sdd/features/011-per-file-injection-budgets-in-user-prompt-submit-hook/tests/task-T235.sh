#!/usr/bin/env bash
# T235 — AC16 — UTF-8 char boundary backoff: when the budget falls
# inside a multi-byte UTF-8 character, the hook backs the truncation
# point off to the previous clean UTF-8 char boundary (at most 3
# trailing bytes dropped). Output stays valid UTF-8.

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

# Fixture: patterns.md = "AAA" (3 ASCII bytes) + "—" (em-dash, 3 bytes
# UTF-8: e2 80 94) + "BBB" (3 bytes). Total = 9 bytes.
# Set budget = 4: the slice lands at byte 4 = INSIDE the em-dash's
# 3-byte sequence. Without backoff: invalid UTF-8 output (cuts mid-char).
# With backoff: drops the 2 partial em-dash bytes → kept = "AAA" (3 bytes).
python3 -c "
import io
data = b'AAA' + '—'.encode('utf-8') + b'BBB'
open('$tmp/.sdd/patterns.md', 'wb').write(data)
"
size=$(wc -c < "$tmp/.sdd/patterns.md" | tr -d ' ')
[ "$size" = "9" ] || { echo "FAIL: fixture setup wrong, expected 9 bytes got $size"; exit 1; }

cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    cap_total_chars: 100000
    per_file_budget_chars:
      patterns: 4
      INDEX: 3000
      spec: 5000
      principles: 2000
      stack: 3000
      data-model: 3000
---
CFG

out=$(cd "$tmp" && PROJECT_DIR="$tmp" CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null || true)

fails=()

# Extract patterns.md section.
pat_sec=$(printf '%s' "$out" | awk '/--- .sdd\/patterns\.md ---/{f=1;next} f&&/^--- /{exit} f&&/^\[END/{exit} f')

# Verify the output is valid UTF-8 (no half-chars). Pipe to python's
# strict decode — would raise UnicodeDecodeError on bad bytes.
if ! printf '%s' "$pat_sec" | python3 -c "import sys; sys.stdin.buffer.read().decode('utf-8', errors='strict')" 2>/dev/null; then
  fails+=("output is not valid UTF-8 (mid-char cut leaked through)")
fi

# Backoff should have dropped the partial em-dash bytes. Expect kept
# bytes to be "AAA" (3 bytes) — the 4th budget byte was the 1st
# em-dash byte (0xE2 = 11100010, a leading byte) which gets dropped
# by the "if leading byte without continuations, drop it" guard.
# So kept = "AAA" (3 bytes), cut = 9 - 3 = 6.
if ! printf '%s' "$pat_sec" | grep -qF "AAA"; then
  fails+=("kept content 'AAA' missing from patterns.md section")
fi

# Sentinel byte count should reflect actual bytes cut (6), not the
# nominal budget remainder (5).
if ! printf '%s' "$pat_sec" | grep -qF "truncated to 6 bytes per per-file budget"; then
  fails+=("expected sentinel 'truncated to 6 bytes' (file=9, kept=3 after UTF-8 backoff)")
  echo "  section content:"
  printf '%s\n' "$pat_sec" | head -5
fi

# Em-dash should NOT appear in kept content (would mean no backoff
# happened OR a different boundary).
if printf '%s' "$pat_sec" | head -1 | grep -qF "—"; then
  fails+=("em-dash leaked into kept content — backoff didn't happen")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T235 — AC16 UTF-8 boundary backoff violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T235 — AC16 UTF-8 char boundary backoff drops 1 byte of partial em-dash; output stays valid UTF-8; sentinel reflects actual cut (6 bytes)"
