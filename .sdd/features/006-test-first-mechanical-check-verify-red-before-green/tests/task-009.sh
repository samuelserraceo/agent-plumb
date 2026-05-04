#!/usr/bin/env bash
# AC9 — stash-pop conflict (test_runner creates a file that conflicts
# with the stashed code) → trap surfaces stash ref + recovery hint
# instead of silently swallowing the error.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-test-first.sh"
[ -x "$HOOK" ] || { echo "FAIL: hook missing at $HOOK"; exit 1; }

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

cd "$tmpdir"
git init -q
git config user.email t@t.com; git config user.name T; git config commit.gpgsign false

# Pre-existing src/foo.sh at HEAD (so stash captures a MODIFICATION,
# not a new-file add — needed to trigger a real pop conflict).
mkdir -p .sdd src
cat > .sdd/config.md <<'EOF'
---
type: config
parameters:
  test_runner: "printf 'CONFLICTING_MOD\n' > src/foo.sh; exit 1"
---
EOF
echo init > README.md
echo "BASE" > src/foo.sh
git add README.md .sdd/config.md src/foo.sh
git commit -q -m scaffold

mkdir -p tests
cat > tests/task-009.sh <<'TST'
#!/usr/bin/env bash
exit 0
TST
chmod +x tests/task-009.sh

# Stage a modification to src/foo.sh (this is what the stash will capture)
echo "STAGED_MOD" > src/foo.sh
git add tests/task-009.sh src/foo.sh

# Hook flow:
#   1. Stash src/foo.sh (out of working tree)
#   2. test_runner runs → creates src/foo.sh with CONFLICT_CONTENT, exits 1
#   3. test_ec=1 (real RED → allow path)
#   4. Trap pops stash → working tree already has src/foo.sh → CONFLICT
#   5. Trap should surface the stash ref + recovery hint

input='{"tool_input":{"command":"git commit -m \"[SDD:006][T09] task\""}}'
output=$(printf '%s' "$input" | bash "$HOOK" 2>&1)
ec=$?

fails=()

if ! printf '%s' "$output" | grep -qiE 'stash.*pop.*failed|recover.*hand|stash ref|stash@'; then
  fails+=("stderr doesn't surface stash ref or recovery hint")
fi

stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
if [ "$stash_count" -eq 0 ]; then
  fails+=("expected stash to remain after conflict, but list is empty")
fi

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC9 — stash conflict recovery hint missing"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Hook output:"
  printf '%s\n' "$output" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC9 — stash pop conflict surfaces stash ref + recovery hint"
exit 0
