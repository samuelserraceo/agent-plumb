#!/usr/bin/env bash
# bootstrap-uat.sh — scaffold a clean SDD v0.9 test project for UAT.
#
# Usage:
#   bootstrap-uat.sh [target-dir]
#
#   target-dir — optional; defaults to a fresh `mktemp -d` path
#                (`sdd-uat-XXXXXXXX` under the system temp dir)
#
# What it does:
#   1. Creates target directory
#   2. Runs `git init` and sets user.email / user.name
#   3. Copies framework files from templates/
#   4. Initial commit
#   5. Prints instructions for next steps
#
# Idempotent: safe to re-run on the same directory (overwrites files).
# Fails loudly if templates/ dir not found.

set -euo pipefail

# Resolve the SDD project root (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Validate templates exist
if [ ! -d "$PROJECT_ROOT/templates/.sdd" ]; then
  echo "ERROR: templates/.sdd not found in $PROJECT_ROOT" >&2
  echo "This script must run from the SDD framework repository." >&2
  exit 1
fi

# Target directory: arg 1, or a collision-safe mktemp default.
# Earlier default `/tmp/sdd-uat-$(date +%s)` collided when two
# bootstrap runs landed in the same second (rare but real on fast
# CI). mktemp -d guarantees a fresh path; the existing-dir branch
# below still handles user-supplied $1.
if [ -n "${1:-}" ]; then
  TARGET="$1"
else
  # Portable mktemp -d form (template as positional arg works on both
  # macOS and GNU mktemp; -t flag has divergent semantics between the
  # two so it's avoided).
  TARGET=$(mktemp -d "${TMPDIR:-/tmp}/sdd-uat-XXXXXXXXXX") || {
    echo "ERROR: mktemp -d failed — cannot create UAT scratch dir." >&2
    exit 1
  }
  # mktemp -d already created TARGET, so the `mkdir -p` branch below
  # would be wrong; jump past the existence check by pre-flagging.
  MKTEMP_CREATED=1
fi

# Create and enter target directory
#
# Safety: if TARGET already exists, refuse to clean unless we left a
# sentinel (.sdd-uat-bootstrap) from a previous run OR the user opts
# in via SDD_FORCE_CLEAN=1. Without this guard, a mistyped TARGET
# (e.g., the user's actual repo path) would lose .git, .sdd,
# .claude, CLAUDE.md before this script even checks. See CodeRabbit
# PR #29 review for the original report.
if [ "${MKTEMP_CREATED:-0}" = "1" ]; then
  # We just created TARGET with mktemp -d — it's empty and ours.
  # Skip the sentinel/SDD_FORCE_CLEAN guard (no prior content to
  # protect) and fall through to the framework copy.
  :
elif [ -d "$TARGET" ]; then
  if [ -f "$TARGET/.sdd-uat-bootstrap" ] || [ "${SDD_FORCE_CLEAN:-0}" = "1" ]; then
    echo "Target directory exists (bootstrap sentinel present, or SDD_FORCE_CLEAN=1)."
    echo "Cleaning and re-initializing..."
    rm -rf "$TARGET/.git" "$TARGET/.sdd" "$TARGET/.claude" "$TARGET/CLAUDE.md" || {
      echo "ERROR: failed to clean $TARGET — aborting before scaffold." >&2
      exit 1
    }
  else
    {
      echo "ERROR: Target directory exists but carries no .sdd-uat-bootstrap"
      echo "       sentinel from a prior bootstrap run:"
      echo "       $TARGET"
      echo ""
      echo "Refusing to delete .git, .sdd, .claude, CLAUDE.md from a directory"
      echo "this script didn't create. If it IS a discardable UAT scratch dir,"
      echo "either:"
      echo "  - opt in via env:  SDD_FORCE_CLEAN=1 bootstrap-uat.sh '$TARGET'"
      echo "  - or run with no arg (uses a fresh mktemp dir,"
      echo "    always safe)."
    } >&2
    exit 1
  fi
else
  mkdir -p "$TARGET"
  echo "Created: $TARGET"
fi

cd "$TARGET" || { echo "ERROR: failed to cd into $TARGET" >&2; exit 1; }

# Drop a sentinel so future bootstrap-uat.sh invocations on this same
# TARGET know it's a discardable UAT scratch dir (the existence-check
# at the top of this script reads it). Created BEFORE git init so
# even if git init fails, the marker is in place.
#
# CodeRabbit cycle 9/10/11: explicit error guards on touch + git init.
# With `set -euo pipefail` above these would already fail-stop, but
# the explicit messages give the user a clearer diagnostic.
touch .sdd-uat-bootstrap || {
  echo "ERROR: failed to create sentinel file in $TARGET — check permissions." >&2
  exit 1
}

# Initialize git repo
if [ ! -d .git ]; then
  git init -q || {
    echo "ERROR: git init failed in $TARGET — refusing to scaffold without a git repo." >&2
    exit 1
  }
fi

# Configure git user (test values)
git config user.email "test@sdd-uat.local" || { echo "ERROR: git config user.email failed" >&2; exit 1; }
git config user.name "UAT Test User" || { echo "ERROR: git config user.name failed" >&2; exit 1; }

# UAT fix: wire the safety-check chain via native git pre-commit. Without
# this, combined `git add && git commit` patterns bypass the moat (the
# Phase B-1 UAT BLOCKER finding). Native pre-commit fires AFTER staging,
# regardless of how the agent invoked git.
git config core.hooksPath .claude/hooks || {
  echo "ERROR: git config core.hooksPath failed — moat won't fire on combined" >&2
  echo "       'git add && git commit' patterns. Refusing to scaffold UAT" >&2
  echo "       project without the safety wiring." >&2
  exit 1
}

# Copy framework files (preserve .git, don't overwrite any user modifications)
echo "Copying framework files..."
cp -r "$PROJECT_ROOT/templates/.sdd" .sdd 2>/dev/null || {
  echo "ERROR: Failed to copy .sdd/" >&2
  exit 1
}

cp -r "$PROJECT_ROOT/templates/.claude" .claude 2>/dev/null || {
  echo "ERROR: Failed to copy .claude/" >&2
  exit 1
}

cp "$PROJECT_ROOT/templates/CLAUDE.md" CLAUDE.md 2>/dev/null || {
  echo "ERROR: Failed to copy CLAUDE.md" >&2
  exit 1
}

# Initial commit. CodeRabbit fix (4th-cycle): drop the `|| true`
# silent-error swallow. If `git add` fails (disk full, permission
# change, or anything weird), the subsequent commit would fail with
# a confusing message — better to surface the staging error here.
git add .sdd .claude CLAUDE.md >/dev/null 2>&1 || {
  echo "ERROR: git add failed during scaffold — staging didn't pick up" >&2
  echo "       framework files. Check disk space + permissions in $TARGET." >&2
  exit 1
}
if git diff-index --quiet HEAD -- >/dev/null 2>&1; then
  # Already committed (e.g., re-run on same dir after cleanup)
  echo "Framework files already in place."
else
  git commit -q -m "[SDD] bootstrap: initialize framework files" \
    --author="UAT Bootstrap <test@sdd-uat.local>" || {
    echo "ERROR: Initial git commit failed" >&2
    exit 1
  }
  echo "Initial commit: framework files"
fi

# Success message
cat <<EOF

====================================================================
SDD v0.9 UAT Project Ready
====================================================================

Location: $TARGET

Next steps:

1. Open Session A (Claude Code in this project):
   cd $TARGET
   claude code

2. Open Session B (another Claude to drive the test):
   Paste the Session B Primer from the UAT plan

3. Follow the 8 scenarios in the UAT plan, copying setup commands
   into a terminal and action text into Session A.

====================================================================
EOF

exit 0
