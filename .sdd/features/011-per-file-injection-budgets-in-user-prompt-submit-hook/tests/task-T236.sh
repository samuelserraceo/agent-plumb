#!/usr/bin/env bash
# T236 — AC17 — negative budget clamp: project config.md declares
# a negative value for any per_file_budget_chars.<key>; resolver
# clamps to 0, emits stderr warning naming the key.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HELPER="$FRAMEWORK_ROOT/templates/.sdd/scripts/get-injection-budget.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.sdd/scripts"
cp "$HELPER" "$tmp/.sdd/scripts/"
chmod +x "$tmp/.sdd/scripts/get-injection-budget.sh"

cat > "$tmp/.sdd/config.md" <<'CFG'
---
type: config
parameters:
  injection:
    per_file_budget_chars:
      patterns: -1000
      stack: -42
---
CFG

fails=()

# stdout: clamped to 0.
got_stdout=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" patterns 2>/dev/null)
[ "$got_stdout" = "0" ] || fails+=("patterns stdout: expected 0, got '$got_stdout'")

got_stdout=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" stack 2>/dev/null)
[ "$got_stdout" = "0" ] || fails+=("stack stdout: expected 0, got '$got_stdout'")

# stderr: warning naming the offending key.
got_stderr=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" patterns 2>&1 >/dev/null)
printf '%s' "$got_stderr" | grep -q "patterns" || fails+=("patterns: stderr does not name the key — got: $got_stderr")
printf '%s' "$got_stderr" | grep -q "negative" || fails+=("patterns: stderr does not mention 'negative' — got: $got_stderr")
printf '%s' "$got_stderr" | grep -q "clamping to 0" || fails+=("patterns: stderr does not say 'clamping to 0' — got: $got_stderr")

got_stderr=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" stack 2>&1 >/dev/null)
printf '%s' "$got_stderr" | grep -q "stack" || fails+=("stack: stderr does not name the key")

# Positive values still pass through untouched.
got=$(CLAUDE_PROJECT_DIR="$tmp" bash "$tmp/.sdd/scripts/get-injection-budget.sh" INDEX 2>/dev/null)
[ "$got" = "3000" ] || fails+=("INDEX (positive, framework default): expected 3000, got $got")

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T236 — AC17 negative-clamp violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T236 — AC17 negative budget (patterns=-1000, stack=-42) clamps to 0 + stderr warning names key"
