#!/usr/bin/env bash
# AC7 — commit with 2+ test+code pairs in one commit → hook refuses
# with "split into one commit per task."

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
  test_runner: "echo dummy"
---
EOF
echo "init" > README.md
git add README.md .sdd/config.md
git commit -q -m scaffold

# Stage TWO test files + code in one commit (the multi-pair shape)
mkdir -p tests
cat > tests/task-007.sh <<'TST'
#!/usr/bin/env bash
exit 0
TST
cat > tests/task-008.sh <<'TST'
#!/usr/bin/env bash
exit 0
TST
chmod +x tests/task-007.sh tests/task-008.sh
echo "echo a" > src/foo.sh
echo "echo b" > src/bar.sh
git add tests/task-007.sh tests/task-008.sh src/foo.sh src/bar.sh

input='{"tool_input":{"command":"git commit -m \"[SDD:006][T07] task\""}}'
output=$(printf '%s' "$input" | bash "$HOOK" 2>&1)
ec=$?

fails=()

if [ "$ec" -eq 0 ]; then
  fails+=("hook returned 0 — should have blocked multi-pair commit")
fi

if ! printf '%s' "$output" | grep -qiE 'split into one commit|one commit per task|multiple.*pairs'; then
  fails+=("stderr doesn't mention multi-pair / split-into-one-commit")
fi

# Stash should be empty (multi-pair detected before stash creation)
stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
if [ "$stash_count" -ne 0 ]; then
  fails+=("multi-pair shouldn't create a stash, but $stash_count entries exist")
fi

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC7 — multi-pair commit should be refused"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Hook output:"
  printf '%s\n' "$output" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC7 — multi-pair commit refused"
exit 0
