#!/usr/bin/env bash
# AC4 — non-BUILD-task commits pass through silently.
#
# Same staged set (theatre-shaped pair) under two different commit
# messages:
#   - BUILD-task shape `[SDD:006][T04] ...` → hook should BLOCK (theatre)
#   - Spec-edit shape `[SDD:006] spec: ...` → hook should ALLOW silently

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-test-first.sh"
[ -x "$HOOK" ] || { echo "FAIL: hook missing at $HOOK"; exit 1; }

tmpdir=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$tmpdir"' EXIT

cd "$tmpdir" || { echo "FAIL: cd $tmpdir failed"; exit 1; }
git init -q
git config user.email t@t.com; git config user.name T; git config commit.gpgsign false

mkdir -p .sdd src
cat > .sdd/config.md <<'EOF'
---
type: config
parameters:
  test_runner: "bash tests/task-004.sh"
---
EOF
cat > src/foo.sh <<'SRC'
#!/usr/bin/env bash
echo "hello"
SRC
chmod +x src/foo.sh
git add .sdd/config.md src/foo.sh
git commit -q -m scaffold

mkdir -p tests
cat > tests/task-004.sh <<'TST'
#!/usr/bin/env bash
out=$(bash src/foo.sh 2>/dev/null)
[ "$out" = "hello" ] || exit 1
TST
chmod +x tests/task-004.sh
echo "# cosmetic" >> src/foo.sh
git add tests/task-004.sh src/foo.sh

# Sub-test A: BUILD-task shape → expect block
input_a='{"tool_input":{"command":"git commit -m \"[SDD:006][T04] task\""}}'
output_a=$(printf '%s' "$input_a" | bash "$HOOK" 2>&1)
ec_a=$?

# Reset stash if any (block path doesn't pop on the trap until exit)
git stash list 2>/dev/null | head -1 | grep -q . && git stash pop --quiet 2>/dev/null || true

# Sub-test B: spec-edit shape → expect silent allow
input_b='{"tool_input":{"command":"git commit -m \"[SDD:006] spec: §X edit\""}}'
output_b=$(printf '%s' "$input_b" | bash "$HOOK" 2>&1)
ec_b=$?

fails=()
if [ "$ec_a" -eq 0 ]; then
  fails+=("BUILD-task: hook returned 0, expected block (theatre)")
fi
if [ "$ec_b" -ne 0 ]; then
  fails+=("spec-edit: hook returned $ec_b, expected 0 (silent pass)")
fi
if [ -n "$output_b" ]; then
  fails+=("spec-edit: stderr non-empty (should be silent): $output_b")
fi

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC4 — only BUILD-task commits should be gated"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  output_a: $output_a"
  echo "  output_b: $output_b"
  exit 1
fi

echo "PASS: AC4 — non-BUILD commits pass through silently"
exit 0
