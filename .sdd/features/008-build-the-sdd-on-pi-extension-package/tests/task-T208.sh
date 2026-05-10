#!/usr/bin/env bash
# T208 — AC9 — Multi-model discipline regression: the BUILD-TASK
# calculator-add fixture from the 2026-05-08 discipline test passes
# when run through pi.dev under both claude-sonnet-4-6 AND one
# non-Claude model (GPT-5 OR Kimi K2 OR Llama). Captures cross-model
# regression on the atomic-step rule.
#
# Why a structural test, not a live cross-model run: the live pi.dev
# invocation against multiple model providers requires API keys, paid
# inference, and a running pi.dev binary — operator territory, not
# framework CI. The framework's scope is owning the fixture itself
# (so any operator can replay it on demand) plus proving the fixture
# is mechanically sound (RED before code, GREEN after the documented
# one-line add).
#
# T208 verifies five things:
#
#   A) Fixture directory exists at the documented stable path
#      extensions/sdd-pi-extension/fixtures/calculator-add/.
#
#   B) Fixture spec.md exists and declares exactly one BUILD-TASK
#      (the discipline-test contract is "one atomic step = one
#      commit"; more than one task would muddy the cross-model signal).
#
#   C) Fixture test (tests/task-T001.sh) exists and is RED against the
#      empty fixture project (no add.js yet) — proves the test is a
#      real RED before code, not green-by-accident theatre.
#
#   D) Adding the documented one-line add (lib/add.js with
#      `module.exports = (a, b) => a + b`) flips the test to GREEN.
#      Same mechanical proof Claude Code's atomic-step tests use.
#
#   E) Replay README documents the operator path: which pi.dev models
#      AC9 requires (claude-sonnet-4-6 + at least one of GPT-5 / Kimi
#      K2 / Llama), where the run log lives, and how to re-run after
#      a new model release.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FIX="$FRAMEWORK_ROOT/extensions/sdd-pi-extension/fixtures/calculator-add"

fails=()

# --- A) Fixture directory exists ------------------------------------
if [ ! -d "$FIX" ]; then
  echo "FAIL: T208 — calculator-add fixture directory missing at $FIX"
  exit 1
fi

# --- B) Fixture spec.md exists with exactly one BUILD-TASK ----------
SPEC="$FIX/spec.md"
if [ ! -f "$SPEC" ]; then
  fails+=("fixture spec.md missing at $SPEC")
else
  task_count="$(grep -cE '^- \[[ x]\] T[0-9]+' "$SPEC" || true)"
  if [ "$task_count" -ne 1 ]; then
    fails+=("fixture spec.md must declare exactly 1 BUILD-TASK (got $task_count) — discipline test is single-step")
  fi
fi

# --- C/D) Mechanical RED-then-GREEN proof ---------------------------
TEST="$FIX/tests/task-T001.sh"
if [ ! -f "$TEST" ]; then
  fails+=("fixture tests/task-T001.sh missing at $TEST")
else
  WORK="$(mktemp -d -t sdd-t208.XXXXXX)"
  trap 'rm -rf "$WORK"' EXIT

  # --- C) Empty fixture project — test must be RED ------------------
  PROJECT="$WORK/red"
  mkdir -p "$PROJECT/lib"
  cp "$TEST" "$PROJECT/task-T001.sh"

  ( cd "$PROJECT" && bash task-T001.sh ) >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    fails+=("fixture test is GREEN before code — not a real RED, atomic-step rule cannot be proven")
  fi

  # --- D) After one-line add — test must be GREEN -------------------
  PROJECT2="$WORK/green"
  mkdir -p "$PROJECT2/lib"
  cp "$TEST" "$PROJECT2/task-T001.sh"
  echo 'module.exports = (a, b) => a + b;' > "$PROJECT2/lib/add.js"

  ( cd "$PROJECT2" && bash task-T001.sh ) >/dev/null 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fails+=("fixture test stays RED after the documented one-line add — fixture is not replayable, AC9 unprovable")
  fi
fi

# --- E) Replay README documents the operator path ------------------
README="$FIX/README.md"
if [ ! -f "$README" ]; then
  fails+=("fixture README.md missing at $README — operators have no replay instructions")
else
  grep -qF 'claude-sonnet-4-6' "$README" || fails+=("README.md does not name claude-sonnet-4-6 — AC9 model contract unclear")
  grep -qE '(GPT-5|Kimi K2|Llama)' "$README" || fails+=("README.md does not name any of the AC9 non-Claude models (GPT-5 / Kimi K2 / Llama)")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T208 — AC9 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T208 — AC9 calculator-add fixture present, RED-then-GREEN mechanically sound, operator replay path documented for cross-model regression"
