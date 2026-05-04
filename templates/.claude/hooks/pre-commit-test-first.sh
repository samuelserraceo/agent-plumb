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

# Approach B fallback (T03 fills this in). For T01 skeleton: pass
# through silently when test_runner is empty.
[ -z "$test_runner" ] && exit 0

# Approach A: stash code-side files, run test, restore.
stash_msg="sdd-pre-commit-test-first-$$"

# shellcheck disable=SC2086
if ! git stash push --quiet -m "$stash_msg" -- $code_files >/dev/null 2>&1; then
  # Stash failed — likely no diff (already-clean state) or path issue.
  # Pass through; the moat hook + downstream review still apply.
  exit 0
fi

# trap restores the stash on any exit path (T05 hardens this).
# Pop + re-stage (instead of pop --index): --index doesn't survive
# new files cleanly — pop refuses with a conflict and leaves the
# stash in place. The pop-then-add pattern brings the working tree
# back, then re-stages each code path to restore the index.
# Caught dogfooding T01: the very first commit silently landed only
# the new files because pop-without-index leaves modified files in
# the working tree but not the index.
trap '
  git stash pop --quiet 2>/dev/null || true
  for _f in $code_files; do
    git add -- "$_f" 2>/dev/null || true
  done
' EXIT

# Run the configured test runner.
test_output=$(eval "$test_runner" 2>&1)
test_ec=$?

# T01 skeleton: allow regardless of test result. T02 adds the
# theatre-block path (test PASSES without code → exit 2 with stderr).
exit 0
