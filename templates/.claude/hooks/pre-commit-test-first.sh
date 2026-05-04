#!/usr/bin/env bash
# pre-commit-test-first.sh — verify RED before GREEN.
#
# Closes the SDD-identity gap surfaced in the v1.0 audit: BUILD's
# "test-first" claim was discipline only — nothing mechanical caught
# a commit that paired a fresh test with code where the test happened
# to pass on first run because the code was already there.
#
# Approach A (this file's primary path; fires when parameters.test_runner
# is set):
#   1. Detect a staged pair = tests/task-NNN.* + a non-test file.
#   2. Stash the code-side staged changes (test stays in index).
#   3. Run parameters.test_runner from .sdd/config.md.
#   4. trap-restore the stash on any exit.
#   5. Test FAILS without code → real test-first → exit 0 (allow).
#      Test PASSES without code → theatre → exit 2 (T02 wires the
#      stderr message; this skeleton always allows for now).
#
# Approach B (T03 fills in; fires when parameters.test_runner is empty):
#   commit-order check — same-commit test+code pairs refused with
#   "test must land in its own commit first."
#
# Wired as PreToolUse(Bash) on `git commit` in .claude/settings.json.
#
# Exits:
#   0 — allow commit
#   2 — block (theatre detected; stderr explains)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

# Parse stdin for Claude Code PreToolUse shape; fall back to "git commit"
# for direct hook invocation.
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[ -z "$cmd" ] && cmd="git commit"

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# T04: only gate BUILD-task commits.
# When the cmd carries a -m payload (Claude Code path), look for the
# [SDD:NNN][T<n>] shape that the framework's BUILD-task convention
# uses. Anything else (spec edits, phase advances, framework chores,
# mark-shipped) should pass through silently — only the test-first
# discipline of BUILD-tasks needs the gate.
# When the cmd is just "git commit" (no -m), assume the caller is a
# native pre-commit invocation that can't see the message; gate by
# default in that case.
if printf '%s' "$cmd" | grep -qE 'git commit.*-m'; then
  if ! printf '%s' "$cmd" | grep -qE '\[SDD:[^]]+\]\[T[0-9]+'; then
    exit 0
  fi
fi

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Find staged files
staged=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
[ -z "$staged" ] && exit 0

# Detect pair: tests/task-NNN.* (anywhere in path) + at least one
# non-test file.
test_files=$(printf '%s\n' "$staged" | grep -E '(^|/)tests/task-[0-9]+(\.|$)' || true)
code_files=$(printf '%s\n' "$staged" | grep -vE '(^|/)tests/task-[0-9]+(\.|$)' || true)

[ -z "$test_files" ] && exit 0
[ -z "$code_files" ] && exit 0

# T07: multi-pair refusal. The atomic-step rule (one task = one commit)
# means a single commit should land at most one test file. If the AI
# batched 2+ tasks (multiple tests/task-NNN.* files staged together),
# refuse before any stash work — the right fix is to split commits.
test_count=$(printf '%s\n' "$test_files" | grep -c .)
if [ "$test_count" -gt 1 ]; then
  cat >&2 <<HOOK_ERR
[pre-commit-test-first] multiple test+code pairs in one commit.

  tests staged:
$(printf '%s\n' "$test_files" | sed 's/^/    /')

The framework's atomic-step rule (one task = one commit) wants each
test file to land in its own commit. This commit pairs $test_count
tests with code — that's $test_count tasks bundled together.

How to fix:
  1. Unstage everything: git reset
  2. Stage one task's test+code, commit it.
  3. Repeat for the next task.

Refusing the commit. Split into one commit per task.
HOOK_ERR
  exit 2
fi

# Read parameters.test_runner from .sdd/config.md (YAML-ish parse).
test_runner=""
if [ -f .sdd/config.md ]; then
  test_runner=$(awk '
    /^parameters:/ { in_params = 1; next }
    /^[A-Za-z_]/ && !/^[[:space:]]/ { in_params = 0 }
    in_params && /^[[:space:]]+test_runner:/ {
      sub(/^[[:space:]]+test_runner:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit
    }
  ' .sdd/config.md 2>/dev/null || echo "")
fi

# Approach B: parameters.test_runner empty → commit-order check.
# For each staged test file: was it committed in a PRIOR commit on this
# branch? If yes → allow. If no → refuse same-commit pair.
if [ -z "$test_runner" ]; then
  while IFS= read -r tf; do
    [ -z "$tf" ] && continue
    if [ -z "$(git log --diff-filter=A --pretty=format:%H -- "$tf" 2>/dev/null)" ]; then
      cat >&2 <<HOOK_ERR
[pre-commit-test-first] test+code paired in the same commit (no test_runner configured).

  test:  $tf
  code:  $(printf '%s' "$code_files" | tr '\n' ' ')

The framework's test-first discipline says the test must land in its
own commit first. This commit pairs both. Either:
  1. Set parameters.test_runner in .sdd/config.md (enables the
     stash-and-rerun gate, Approach A).
  2. Split the commit so the test lands first, then the code.

Refusing — test must land in its own commit first.
HOOK_ERR
      exit 2
    fi
  done <<< "$test_files"
  exit 0
fi

# Approach A: stash code-side files, run test, restore.
stash_msg="sdd-pre-commit-test-first-$$"

# shellcheck disable=SC2086
if ! git stash push --quiet -m "$stash_msg" -- $code_files >/dev/null 2>&1; then
  # Stash failed — likely no diff (already-clean state) or path issue.
  # Pass through; the moat hook + downstream review still apply.
  exit 0
fi

# trap restores the stash on any exit path.
#
# Pop + re-stage (instead of pop --index): --index doesn't survive
# new files cleanly — pop refuses with a conflict and leaves the
# stash in place. The pop-then-add pattern brings the working tree
# back, then re-stages each code path to restore the index.
# Caught dogfooding T01: the very first commit silently landed only
# the new files because pop-without-index leaves modified files in
# the working tree but not the index.
#
# T05: explicit INT TERM HUP signals alongside EXIT. macOS bash 3.2's
# EXIT trap empirically fires on SIGTERM/SIGINT too, but the bash
# manual doesn't guarantee that across all platforms — Linux bash 5+
# and other shells handle this differently. Naming the signals
# explicitly is the portable form: the cleanup runs whether bash
# exits normally, gets Ctrl+C'd, or is sent SIGTERM by a CI runner.
trap '
  pop_err=$(git stash pop 2>&1)
  pop_ec=$?
  if [ "$pop_ec" -ne 0 ]; then
    stash_ref=$(git stash list 2>/dev/null | grep -F "$stash_msg" | head -1 | cut -d":" -f1)
    [ -z "$stash_ref" ] && stash_ref="stash@{0}"
    cat >&2 <<RECOVERY
[pre-commit-test-first] stash pop failed — your code is in $stash_ref.

This usually means the test runner created a file the stashed code
also touches, so the merge cannot apply cleanly.

To recover by hand:
  1. Inspect what the test left behind: git status
  2. Drop the test runners output if youre sure: git checkout -- <files>
  3. Re-apply your code:    git stash pop $stash_ref
  4. Resolve any conflicts, re-stage, commit again.

Pop error:
$pop_err
RECOVERY
  fi
  for _f in $code_files; do
    git add -- "$_f" 2>/dev/null || true
  done
' EXIT INT TERM HUP

# Run the configured test runner.
test_output=$(eval "$test_runner" 2>&1)
test_ec=$?

if [ "$test_ec" -eq 0 ]; then
  # Test PASSED without the code → theatre → block.
  # 3 elements (AC6): test path, what test-first means, how to fix.
  cat >&2 <<HOOK_ERR
[pre-commit-test-first] test PASSED without the code — theatre detected.

  test:  $(printf '%s' "$test_files" | tr '\n' ' ')

What this means:
The test you staged passes WITHOUT the code paired with it. That
means it doesn't pin behaviour — it was written to match whatever
the code happens to do, not to fail before the code existed. Future
regressions will sneak past this test.

How to fix:
  1. Rewrite the test against the not-yet-existing code shape.
  2. Run it — it should FAIL (because the code doesn't exist yet).
  3. Then write the code that makes it pass.
  4. Commit again.

Refusing the commit. (Stash restored.)
HOOK_ERR
  exit 2
fi

# T08: distinguish "runner config wrong" from "test legitimately failed".
# bash returns 127 when the command itself can't be found. That's the
# user pointing test_runner at a non-existent binary — not a real RED
# signal. Block with a config-wrong message instead of silently
# accepting the commit (which would let theatre slip through whenever
# the runner happens to be misconfigured).
if [ "$test_ec" -eq 127 ]; then
  cat >&2 <<HOOK_ERR
[pre-commit-test-first] test_runner config is wrong — fix .sdd/config.md.

  test_runner: $test_runner
  exit code:   127 (command not found)

The configured test_runner couldn't be executed. Set
parameters.test_runner in .sdd/config.md to a real test command
(e.g. "bash test/run-test.sh", "npx vitest run", "pytest"), or
leave it empty to use the lighter Approach B (commit-order check).

Refusing the commit so theatre doesn't slip through a broken runner.
HOOK_ERR
  exit 2
fi

# Test FAILED with a normal exit code → real test-first → allow.
exit 0
