#!/usr/bin/env bash
# AC1 — real test-first commit (test fails without code) lands.
#
# Sets up a temp git repo, stages a test+code pair where the test
# legitimately fails without the code, invokes the pre-commit-test-first
# hook, asserts:
#   - hook exits 0 (allow)
#   - stash was popped (count = 0 after hook returns)
#   - staged set unchanged (both files still in index)

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
git config user.email "t@t.com"
git config user.name "T"
git config commit.gpgsign false

# Initial commit + project config (test_runner set)
echo "init" > README.md
mkdir -p .sdd
cat > .sdd/config.md <<'EOF'
---
type: config
parameters:
  test_runner: "bash tests/task-001.sh"
---
EOF
git add README.md .sdd/config.md
git commit -q -m "scaffold"

# Stage a real test-first pair:
#   tests/task-001.sh — checks src/foo.sh outputs "hello"
#   src/foo.sh        — outputs "hello"
mkdir -p tests src
cat > tests/task-001.sh <<'TEST'
#!/usr/bin/env bash
out=$(bash src/foo.sh 2>/dev/null)
[ "$out" = "hello" ] || exit 1
TEST
chmod +x tests/task-001.sh
cat > src/foo.sh <<'SRC'
#!/usr/bin/env bash
echo "hello"
SRC
chmod +x src/foo.sh
git add tests/task-001.sh src/foo.sh

pre_index=$(git diff --cached --name-only | sort)

# Invoke the hook (no stdin = falls through to "git commit" assumption)
output=$(bash "$HOOK" </dev/null 2>&1)
ec=$?

fails=()

if [ "$ec" -ne 0 ]; then
  fails+=("hook returned exit=$ec, expected 0 (allow)")
fi

stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
if [ "$stash_count" -ne 0 ]; then
  fails+=("stash not popped — $stash_count entries remain")
fi

post_index=$(git diff --cached --name-only | sort)
if [ "$pre_index" != "$post_index" ]; then
  fails+=("staged set changed by hook — pre='$pre_index' post='$post_index'")
fi

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC1 — real test-first should land"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  echo "  Hook output:"
  printf '%s\n' "$output" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC1 — real test-first commit lands"
exit 0
