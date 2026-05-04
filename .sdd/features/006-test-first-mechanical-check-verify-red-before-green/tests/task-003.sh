#!/usr/bin/env bash
# AC3 — empty test_runner → Approach B (commit-order check):
#   same-commit test+code pair gets refused with "test must land in its
#   own commit first."

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-test-first.sh"
[ -x "$HOOK" ] || { echo "FAIL: hook missing at $HOOK"; exit 1; }

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

cd "$tmpdir"
git init -q
git config user.email t@t.com
git config user.name T
git config commit.gpgsign false

# Empty test_runner forces Approach B
echo "init" > README.md
mkdir -p .sdd
cat > .sdd/config.md <<'EOF'
---
type: config
parameters:
  test_runner: ""
---
EOF
git add README.md .sdd/config.md
git commit -q -m "scaffold"

# Same-commit pair: test + code both new, both staged together
mkdir -p tests src
cat > tests/task-003.sh <<'TST'
#!/usr/bin/env bash
[ -f src/foo.sh ] || exit 1
TST
chmod +x tests/task-003.sh
echo "echo hi" > src/foo.sh
git add tests/task-003.sh src/foo.sh

output=$(bash "$HOOK" </dev/null 2>&1)
ec=$?

fails=()
if [ "$ec" -eq 0 ]; then
  fails+=("hook returned 0 — Approach B should block same-commit pair")
fi
if ! printf '%s' "$output" | grep -q "test must land in its own commit first"; then
  fails+=("stderr doesn't include the canonical 'test must land in its own commit first' message")
fi

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC3 — same-commit pair (empty test_runner) should be blocked"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Hook output:"
  printf '%s\n' "$output" | sed 's/^/    /'
  exit 1
fi

# Sub-test: test committed in prior commit, then code-only commit with the
# test ALSO modified (so a pair IS detected) → Approach B sees the test
# was committed before → allow.
git reset --hard HEAD >/dev/null 2>&1
git stash drop --quiet 2>/dev/null || true
# Fresh attempt: commit test alone first
mkdir -p tests src
cat > tests/task-003.sh <<'TST'
#!/usr/bin/env bash
[ -f src/foo.sh ] || exit 1
TST
chmod +x tests/task-003.sh
git add tests/task-003.sh
git commit -q -m "test first"

# Now stage code + a tweak to the test (real-world: agent fixes test wording while writing code)
echo "echo hi" > src/foo.sh
echo "# small refinement" >> tests/task-003.sh
git add src/foo.sh tests/task-003.sh

output2=$(bash "$HOOK" </dev/null 2>&1)
ec2=$?

if [ "$ec2" -ne 0 ]; then
  echo "FAIL: AC3 — Approach B should ALLOW when test was committed in a prior commit"
  echo "  ec=$ec2 output:"
  printf '%s\n' "$output2" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC3 — Approach B blocks same-commit, allows prior-commit"
exit 0
