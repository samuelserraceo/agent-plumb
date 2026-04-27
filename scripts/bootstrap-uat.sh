#!/usr/bin/env bash
# bootstrap-uat.sh — scaffold a clean SDD v0.8 test project for UAT.
#
# Usage:
#   bootstrap-uat.sh [target-dir]
#
#   target-dir — optional, defaults to /tmp/sdd-uat-<timestamp>
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

set -uo pipefail

# Resolve the SDD project root (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Validate templates exist
if [ ! -d "$PROJECT_ROOT/templates/.sdd" ]; then
  echo "ERROR: templates/.sdd not found in $PROJECT_ROOT" >&2
  echo "This script must run from the SDD framework repository." >&2
  exit 1
fi

# Target directory: arg 1, or default to /tmp/sdd-uat-<timestamp>
TARGET="${1:-/tmp/sdd-uat-$(date +%s)}"

# Create and enter target directory
if [ -d "$TARGET" ]; then
  echo "Target directory exists: $TARGET"
  echo "Cleaning and re-initializing..."
  rm -rf "$TARGET/.git" "$TARGET/.sdd" "$TARGET/.claude" "$TARGET/CLAUDE.md"
else
  mkdir -p "$TARGET"
  echo "Created: $TARGET"
fi

cd "$TARGET"

# Initialize git repo
if [ ! -d .git ]; then
  git init -q
fi

# Configure git user (test values)
git config user.email "test@sdd-uat.local"
git config user.name "UAT Test User"

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

# Initial commit
git add .sdd .claude CLAUDE.md >/dev/null 2>&1 || true
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
SDD v0.8 UAT Project Ready
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
