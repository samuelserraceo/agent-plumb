#!/usr/bin/env bash
# AC8 — runner-crashed (exit 127, command not found) is distinguished
# from real test-fail (exit 1):
#   - exit 127 → block with "test_runner config is wrong" message
#   - exit 1 → allow (real test-first; the legacy T01 path)

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-test-first.sh"
[ -x "$HOOK" ] || { echo "FAIL: hook missing at $HOOK"; exit 1; }

# ── Sub-test A: test_runner = nonexistent command → exit 127 → block ──
d_a=$(mktemp -d)
(
  cd "$d_a" || exit 1
  git init -q
  git config user.email t@t.com; git config user.name T; git config commit.gpgsign false
  mkdir -p .sdd src
  cat > .sdd/config.md <<'CFG'
---
type: config
parameters:
  test_runner: "absolutely_nonexistent_xyz_runner_42"
---
CFG
  echo init > README.md
  git add README.md .sdd/config.md
  git commit -q -m scaffold
  mkdir -p tests
  echo '#!/usr/bin/env bash' > tests/task-008.sh
  echo 'exit 0' >> tests/task-008.sh
  chmod +x tests/task-008.sh
  echo "echo a" > src/foo.sh
  git add tests/task-008.sh src/foo.sh
  out=$(printf '%s' '{"tool_input":{"command":"git commit -m \"[SDD:006][T08] task\""}}' | bash "$HOOK" 2>&1)
  ec=$?
  if [ "$ec" -ne 0 ] && printf '%s' "$out" | grep -qiE 'test_runner.*wrong|config.*wrong|command not found'; then
    echo "PASS_A"
  else
    echo "FAIL_A ec=$ec out=$out"
  fi
) > /tmp/sdd_t08_a.out 2>&1
result_a=$(grep -E '^PASS|^FAIL' /tmp/sdd_t08_a.out | tail -1)
rm -rf "$d_a" /tmp/sdd_t08_a.out

# ── Sub-test B: test_runner exits 1 (real test failure) → allow ───────
d_b=$(mktemp -d)
(
  cd "$d_b" || exit 1
  git init -q
  git config user.email t@t.com; git config user.name T; git config commit.gpgsign false
  mkdir -p .sdd src
  cat > .sdd/config.md <<'CFG'
---
type: config
parameters:
  test_runner: "bash -c 'exit 1'"
---
CFG
  echo init > README.md
  git add README.md .sdd/config.md
  git commit -q -m scaffold
  mkdir -p tests
  echo '#!/usr/bin/env bash' > tests/task-008.sh
  echo 'exit 0' >> tests/task-008.sh
  chmod +x tests/task-008.sh
  echo "echo a" > src/foo.sh
  git add tests/task-008.sh src/foo.sh
  out=$(printf '%s' '{"tool_input":{"command":"git commit -m \"[SDD:006][T08] task\""}}' | bash "$HOOK" 2>&1)
  ec=$?
  if [ "$ec" -eq 0 ]; then
    echo "PASS_B"
  else
    echo "FAIL_B ec=$ec out=$out"
  fi
) > /tmp/sdd_t08_b.out 2>&1
result_b=$(grep -E '^PASS|^FAIL' /tmp/sdd_t08_b.out | tail -1)
rm -rf "$d_b" /tmp/sdd_t08_b.out

fails=()
[[ "$result_a" == PASS_A ]] || fails+=("Sub-A (exit 127): $result_a")
[[ "$result_b" == PASS_B ]] || fails+=("Sub-B (exit 1): $result_b")

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC8 — runner-crash vs test-fail distinction broken"
  for f in "${fails[@]}"; do echo "  - $f"; done
  exit 1
fi

echo "PASS: AC8 — exit 127 blocks (config wrong); exit 1 allows (real RED)"
exit 0
