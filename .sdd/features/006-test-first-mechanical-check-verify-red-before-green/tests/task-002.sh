#!/usr/bin/env bash
# AC2 — fake test-first commit (test passes without code) is blocked.
#
# Sets up a temp git repo where:
#   - src/foo.sh already exists at HEAD with the "right" output
#   - Stages tests/task-002.sh (asserts the right output) PLUS a
#     cosmetic modification to src/foo.sh that doesn't change behavior
#   - Hook stashes the modification → test runs against HEAD content
#     → test PASSES → theatre → hook blocks
# Asserts:
#   - hook returns non-zero (block)
#   - stderr names the test path
#   - stash gets restored after the block

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-test-first.sh"

if [ ! -x "$HOOK" ]; then
  echo "FAIL: hook missing or not executable at $HOOK"
  exit 1
fi

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

cd "$tmpdir"
git init -q
git config user.email t@t.com
git config user.name T
git config commit.gpgsign false

# Scaffold: src/foo.sh exists at HEAD already outputting "hello"
mkdir -p .sdd src
cat > .sdd/config.md <<'EOF'
---
type: config
parameters:
  test_runner: "bash tests/task-002.sh"
---
EOF
cat > src/foo.sh <<'SRC'
#!/usr/bin/env bash
echo "hello"
SRC
chmod +x src/foo.sh
git add .sdd/config.md src/foo.sh
git commit -q -m "scaffold"

# Stage a fake-test-first pair:
#   tests/task-002.sh — asserts src/foo.sh outputs "hello" (already true at HEAD)
#   src/foo.sh — cosmetic modification (adds a comment, doesn't change output)
mkdir -p tests
cat > tests/task-002.sh <<'TEST'
#!/usr/bin/env bash
out=$(bash src/foo.sh 2>/dev/null)
[ "$out" = "hello" ] || exit 1
TEST
chmod +x tests/task-002.sh

cat > src/foo.sh <<'SRC'
#!/usr/bin/env bash
# new comment that doesn't change behavior
echo "hello"
SRC

git add tests/task-002.sh src/foo.sh

output=$(bash "$HOOK" </dev/null 2>&1)
ec=$?

fails=()

if [ "$ec" -eq 0 ]; then
  fails+=("hook returned 0 — should have blocked theatre")
fi

if ! printf '%s' "$output" | grep -q "tests/task-002.sh"; then
  fails+=("stderr doesn't name the test path")
fi

stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
if [ "$stash_count" -ne 0 ]; then
  fails+=("stash not popped — $stash_count entries remain")
fi

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC2 — fake test-first should be blocked"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  echo "  Hook output:"
  printf '%s\n' "$output" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC2 — fake test-first commit blocked with test path in stderr"
exit 0
