#!/usr/bin/env bash
# AC6 — refusal message has 3 elements:
#   (a) which test is theatre (test path)
#   (b) what test-first means (plain-English explanation)
#   (c) how to fix (concrete numbered steps)

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-test-first.sh"
[ -x "$HOOK" ] || { echo "FAIL: hook missing at $HOOK"; exit 1; }

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

cd "$tmpdir"
git init -q
git config user.email t@t.com; git config user.name T; git config commit.gpgsign false

mkdir -p .sdd src
cat > .sdd/config.md <<'EOF'
---
type: config
parameters:
  test_runner: "bash tests/task-006.sh"
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
cat > tests/task-006.sh <<'TST'
#!/usr/bin/env bash
out=$(bash src/foo.sh 2>/dev/null)
[ "$out" = "hello" ] || exit 1
TST
chmod +x tests/task-006.sh
echo "# cosmetic" >> src/foo.sh
git add tests/task-006.sh src/foo.sh

input='{"tool_input":{"command":"git commit -m \"[SDD:006][T06] task\""}}'
output=$(printf '%s' "$input" | bash "$HOOK" 2>&1)
ec=$?

fails=()

# Must block (theatre)
if [ "$ec" -eq 0 ]; then
  fails+=("hook returned 0 — should have blocked theatre")
fi

# Element (a) — test path
if ! printf '%s' "$output" | grep -q 'tests/task-006.sh'; then
  fails+=("(a) test path missing from stderr")
fi

# Element (b) — what test-first means (look for explanation keywords)
if ! printf '%s' "$output" | grep -qiE 'pin behaviour|test-first|fail before'; then
  fails+=("(b) explanation of test-first missing from stderr")
fi

# Element (c) — how to fix (look for numbered fix steps with concrete actions)
if ! printf '%s' "$output" | grep -qiE 'rewrite the test|run it.*fail|How to fix'; then
  fails+=("(c) fix steps missing from stderr")
fi

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC6 — refusal message missing required elements"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Hook output:"
  printf '%s\n' "$output" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC6 — refusal message has all 3 elements (test path + meaning + fix)"
exit 0
