#!/usr/bin/env bash
# check-worktree-hookpath.sh — folded edge case #4 from feature 008.
#
# When `extensions.worktreeConfig=true` is set, git-worktree creates per-
# worktree config that can OVERRIDE core.hooksPath. SDD's pre-commit
# chain lives at .claude/hooks; if the worktree-level config doesn't
# point there, every commit silently bypasses the framework's safety
# rails.
#
# This script detects the conflict and prints the exact actionable
# command. Called by the extension's session_start handler (T203) the
# first time pi loads in a project, and rerunnable by the user any
# time. Exits 0 when the hookpath is correct or unconfigured; exits 1
# with a plain-English message + the git command to run when wrong.

set -uo pipefail

# Only act when worktree-level config is enabled (otherwise core.hooksPath
# from the main repo applies and there's nothing to detect).
worktree_enabled="$(git config --get extensions.worktreeConfig 2>/dev/null || echo false)"
if [ "$worktree_enabled" != "true" ]; then
  exit 0
fi

# Read the worktree-level core.hooksPath, if any.
worktree_hookpath="$(git config --worktree --get core.hooksPath 2>/dev/null || echo)"

EXPECTED=".claude/hooks"

if [ "$worktree_hookpath" = "$EXPECTED" ]; then
  exit 0
fi

cat <<MSG
[sdd-pi] Worktree config conflict detected.

This worktree has \`extensions.worktreeConfig=true\` but \`core.hooksPath\` at
the worktree level is "${worktree_hookpath:-<unset>}", not "$EXPECTED".

That means SDD's pre-commit safety rails (anti-theatre, atomic-step,
test-first) will NOT run on commits from this worktree. Fix it with:

  git config --worktree core.hooksPath .claude/hooks

Re-run this check any time with:

  bash extensions/sdd-pi-extension/scripts/check-worktree-hookpath.sh
MSG

exit 1
