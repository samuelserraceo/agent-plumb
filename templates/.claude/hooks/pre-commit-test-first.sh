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
# Known limitations (deferred, not blockers):
#   - EC3 (initial commit on a fresh repo): Approach B's "was test
#     committed in a prior commit?" can't run when there's no parent.
#     A first commit that pairs test+code on a brand-new repo will
#     always trip Approach B's same-commit refusal — which is the
#     safer failure mode (block, ask user to split). Documented here
#     so future readers know it's intentional.
#   - L69 (paths with spaces): the staged-file iteration uses
#     newline-separated text instead of NUL-delimited. Paths
#     containing spaces would split unexpectedly during stash push +
#     re-stage. Rare in practice for the tests/task-NNN.<ext> shape;
#     left as a follow-up.
#
# Exits:
#   0 — allow commit
#   2 — block (theatre detected, stash conflict, runner config wrong,
#       multi-pair, or Approach B same-commit pair; stderr explains)

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

# === MERGE / REBASE / CHERRY-PICK detection (mirror of pre-commit-rules.sh v1.7.0) ===
# Legitimate parallel-stream merges bring in test files from already-shipped
# features that pre-commit-test-first would otherwise refuse as multi-pair
# commits. Same gating signal as pre-commit-rules.sh's lenient-mode skip:
# detect .git/MERGE_HEAD / REBASE_HEAD / CHERRY_PICK_HEAD (+ rebase-merge/
# and rebase-apply/ dir probes) and pass through. The atomic-step rule
# applies to ORIGINATING commits on a branch — not to merge commits that
# combine prior-task commits from two branches. v1.7.0 fixed cofile-block;
# this closes the same gap for pre-commit-test-first.
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo ".git")
if [ -f "$GIT_DIR/MERGE_HEAD" ] || \
   [ -f "$GIT_DIR/REBASE_HEAD" ] || \
   [ -d "$GIT_DIR/rebase-merge" ] || \
   [ -d "$GIT_DIR/rebase-apply" ] || \
   [ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]; then
  echo "[pre-commit-test-first] merge/rebase/cherry-pick in progress — skipping multi-pair check" >&2
  exit 0
fi

# T04: only gate BUILD-task commits.
# Look for the [SDD:NNN][T<n>] shape in any visible message source —
# -m / --message inline, OR -F / --file path (read from the file), OR
# COMMIT_EDITMSG (editor-backed). Anything else (spec edits, phase
# advances, framework chores, mark-shipped) should pass through
# silently — only the test-first discipline of BUILD-tasks needs the
# gate. (CR cycle 1 L58 fix — extend beyond the -m-only original.)
build_task_msg=""
# Inline -m / --message: pull text from cmd
if printf '%s' "$cmd" | grep -qE 'git commit.*(-m|--message)'; then
  build_task_msg=$(printf '%s' "$cmd")
fi
# -F / --file: read the named file
if printf '%s' "$cmd" | grep -qE 'git commit.*(-F|--file)'; then
  msg_path=$(printf '%s' "$cmd" | python3 -c "
import sys, re, shlex
s = sys.stdin.read()
m = re.search(r'git commit(.*)', s, re.DOTALL)
if not m: sys.exit(0)
args = shlex.split(m.group(1))
for i,a in enumerate(args):
    if a in ('-F','--file') and i+1 < len(args):
        print(args[i+1]); break
" 2>/dev/null)
  if [ -n "$msg_path" ] && [ -f "$msg_path" ]; then
    build_task_msg="$build_task_msg $(cat "$msg_path" 2>/dev/null)"
  fi
fi
# Native git pre-commit fallback: the framework's pre-commit shim
# (templates/.claude/hooks/pre-commit) invokes hooks with the
# synthetic stdin `{"tool_input":{"command":"git commit"}}` that
# strips the -m payload. In that path, .git/COMMIT_EDITMSG holds
# the message git is about to commit (editor flow has already
# written it), so we recover the BUILD-task shape check from there.
# Detect the shim by its exact synthetic-stdin signature — avoids
# false-firing on test scenarios that invoke the hook directly with
# an empty stdin.
if [ -z "$build_task_msg" ] \
   && [ "$input" = '{"tool_input":{"command":"git commit"}}' ] \
   && git rev-parse --git-dir >/dev/null 2>&1; then
  git_dir=$(git rev-parse --git-dir 2>/dev/null)
  if [ -n "$git_dir" ] && [ -f "$git_dir/COMMIT_EDITMSG" ]; then
    build_task_msg=$(head -1 "$git_dir/COMMIT_EDITMSG" 2>/dev/null)
  fi
fi
# If we have a visible message and it's NOT BUILD-task shape, exit 0.
# If we still have NO visible message, gate by default.
if [ -n "$build_task_msg" ]; then
  if ! printf '%s' "$build_task_msg" | grep -qE '\[SDD:[^]]+\]\[T[0-9]+'; then
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
  # v1.10/4 (closes GPT-5.5 review Q4 site 5): fail-closed when stash
  # fails in an initialized SDD project. Without the stash we can't
  # actually run the test against test-only state — passing through
  # silently lets an adversary commit code-with-test in one breath
  # while claiming TDD discipline. SDD_STRICT=0 for migration.
  if [ -f "$PROJECT_DIR/.sdd/INDEX.md" ] && [ "${SDD_STRICT:-1}" != "0" ]; then
    cat >&2 <<HOOK_ERR
[pre-commit-test-first] Cannot run the test-first gate.

  git stash push failed when isolating code-side files. Without the
  stash the framework can't verify the test fails on test-only state
  (the RED step of test-first). Common causes:
    - paths containing spaces (CR cycle 1 L69 known limitation)
    - no clean working tree to stash onto
    - git index is partially-locked from a prior aborted operation

  Fix the working tree (resolve any conflicts, retry git operations)
  and re-commit. For a one-off migration commit, set SDD_STRICT=0.
HOOK_ERR
    exit 2
  fi
  # Not an SDD project — preserve legacy pass-through.
  exit 0
fi

# Signal traps: if the hook is interrupted (Ctrl+C, CI SIGTERM)
# BEFORE the explicit pop in the main flow runs, best-effort restore
# so the user's code isn't orphaned. Normal-exit pop is handled in
# the main flow below — that path checks pop_ec and blocks the commit
# on conflict (CR cycle 1 L193 fix).
#
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
  exit 130
' INT TERM HUP

# Run the configured test_runner (broad signal — catches general
# regressions). Result kept for fallback when the staged test has an
# unknown extension.
# Subshell isolation: an `exit N` inside test_runner shouldn't kill
# the hook itself. Caught dogfooding T09 (CR cycle 1 follow-up): the
# unwrapped eval let test_runners with `; exit 1` terminate the hook
# silently before pop ran.
( eval "$test_runner" ) >/dev/null 2>&1
test_ec=$?

# CR cycle 1 L248 fix — run the staged test SPECIFICALLY against the
# stashed (HEAD-only) code. Without this, full-suite test_runner masks
# theatre whenever an unrelated test happens to fail (suite returns
# non-zero, hook treats as "real RED", allows). Per-extension dispatch
# below; falls back to test_runner result for unknown extensions.
staged_test_ec=0
while IFS= read -r tf; do
  [ -z "$tf" ] && continue
  case "$tf" in
    *.sh)        bash "$tf" >/dev/null 2>&1; tf_ec=$? ;;
    *.py)        python3 "$tf" >/dev/null 2>&1; tf_ec=$? ;;
    *.js|*.mjs)  node "$tf" >/dev/null 2>&1; tf_ec=$? ;;
    *)           tf_ec=$test_ec ;;
  esac
  # If any staged test failed, the overall staged_test_ec is non-zero.
  # If they all passed (exit 0), staged_test_ec stays 0 → theatre.
  [ "$tf_ec" -ne 0 ] && staged_test_ec=$tf_ec
done <<< "$test_files"

# Pop stash explicitly + re-stage. CR cycle 1 L193 fix: capture the
# pop exit code so we can block the commit on conflict instead of
# silently swallowing it.
pop_err=$(git stash pop 2>&1)
pop_ec=$?
for _f in $code_files; do
  git add -- "$_f" 2>/dev/null || true
done
trap - INT TERM HUP

# CR cycle 1 L193 fix — block when stash pop fails. Previously the
# trap-only logic logged the error but the hook still returned 0 from
# the test-result check below, letting an invalid commit proceed.
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

Refusing the commit.
RECOVERY
  exit 2
fi

# T08: distinguish "runner config wrong" from a real test result.
# Check this FIRST — when the configured test_runner can't be executed
# (exit 127), bash returns 127 from eval. The staged test below would
# still run separately, but its result is meaningless if the runner
# itself is broken — we should surface the config error first.
if [ "$test_ec" -eq 127 ] || [ "$staged_test_ec" -eq 127 ]; then
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

# Decide based on the STAGED test specifically (CR cycle 1 L248 fix).
if [ "$staged_test_ec" -eq 0 ]; then
  # Theatre — the staged test passed without the code paired with it.
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

# Staged test failed with a normal exit code → real test-first → allow.
exit 0
