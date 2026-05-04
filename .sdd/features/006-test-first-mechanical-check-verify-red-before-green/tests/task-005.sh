#!/usr/bin/env bash
# AC5 — trap restores stash even when the hook is interrupted mid-run.
#
# The classic real-world case: the user Ctrl+C's a long test run. Bash's
# EXIT trap alone may not fire on uncaught signals (TERM/INT/HUP), so
# the stash gets orphaned. Hook needs explicit signal traps.
#
# Sub-test A: test_runner crashes with strict-mode undefined-var → hook
#   completes normally (eval captures exit code) → EXIT trap recovers.
# Sub-test B: test_runner sleeps; we send SIGTERM to the hook process
#   mid-execution. Without an explicit TERM trap, the stash stays
#   orphaned. With it, stash gets restored.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-test-first.sh"
[ -x "$HOOK" ] || { echo "FAIL: hook missing at $HOOK"; exit 1; }

# ── Sub-test A: undefined-var crash inside test_runner ────────────────
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
  test_runner: "bash -c 'set -u; echo $UNDEFINED_VAR; exit 99'"
---
CFG
  cat > src/foo.sh <<'SRC'
#!/usr/bin/env bash
echo "hello"
SRC
  chmod +x src/foo.sh
  git add .sdd/config.md src/foo.sh
  git commit -q -m scaffold
  mkdir -p tests
  echo '#!/usr/bin/env bash' > tests/task-005.sh
  echo 'exit 0' >> tests/task-005.sh
  chmod +x tests/task-005.sh
  echo "# cosmetic" >> src/foo.sh
  git add tests/task-005.sh src/foo.sh
  input='{"tool_input":{"command":"git commit -m \"[SDD:006][T05] task\""}}'
  printf '%s' "$input" | bash "$HOOK" >/dev/null 2>&1
  stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  echo "$stash_count"
)
sub_a_stash=$(cd "$d_a" && git stash list 2>/dev/null | wc -l | tr -d ' ')
rm -rf "$d_a"

# ── Sub-test B: SIGTERM during slow test_runner ───────────────────────
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
  test_runner: "sleep 3; exit 1"
---
CFG
  cat > src/foo.sh <<'SRC'
#!/usr/bin/env bash
echo "hello"
SRC
  chmod +x src/foo.sh
  git add .sdd/config.md src/foo.sh
  git commit -q -m scaffold
  mkdir -p tests
  echo '#!/usr/bin/env bash' > tests/task-005.sh
  echo 'exit 0' >> tests/task-005.sh
  chmod +x tests/task-005.sh
  echo "# cosmetic" >> src/foo.sh
  git add tests/task-005.sh src/foo.sh

  # Run hook in background; capture its PID
  input='{"tool_input":{"command":"git commit -m \"[SDD:006][T05] task\""}}'
  printf '%s' "$input" | bash "$HOOK" >/dev/null 2>&1 &
  hook_pid=$!
  # Give it time to hit the sleep
  sleep 0.5
  # Send SIGTERM
  kill -TERM "$hook_pid" 2>/dev/null
  # Wait for hook to die (give it time for trap to run)
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$hook_pid" 2>/dev/null; then break; fi
    sleep 0.2
  done
  wait "$hook_pid" 2>/dev/null || true
  git stash list 2>/dev/null | wc -l | tr -d ' '
) > /tmp/sdd_t05_subB.out 2>&1
sub_b_stash=$(tail -1 /tmp/sdd_t05_subB.out)
rm -rf "$d_b" /tmp/sdd_t05_subB.out

fails=()
[ "$sub_a_stash" = "0" ] || fails+=("sub-A (undefined-var crash): stash count = $sub_a_stash, expected 0")
[ "$sub_b_stash" = "0" ] || fails+=("sub-B (SIGTERM during sleep): stash count = $sub_b_stash, expected 0 (hook needs TERM trap)")

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC5 — trap doesn't cover all interrupt paths"
  for f in "${fails[@]}"; do echo "  - $f"; done
  exit 1
fi

echo "PASS: AC5 — trap recovers stash on crash + on SIGTERM"
exit 0
