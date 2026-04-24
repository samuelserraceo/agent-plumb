#!/usr/bin/env bash
# SDD workflow installer.
# Drops .sdd/, .claude/, dashboard.html, and rubric.md into the current directory.
# Safe to re-run: will not overwrite existing files unless --force is passed.

set -euo pipefail

FORCE=0
if [ "${1:-}" = "--force" ]; then FORCE=1; fi

# Resolve the directory this script lives in, regardless of how it was invoked.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TEMPLATES="$REPO_ROOT/templates"
RUBRIC="$REPO_ROOT/rubric.md"
TARGET="$(pwd)"

if [ ! -d "$TEMPLATES" ]; then
  echo "ERROR: templates/ not found at $TEMPLATES. Run init.sh from a cloned copy of the SDD repo." >&2
  exit 1
fi

if [ ! -f "$RUBRIC" ]; then
  echo "ERROR: rubric.md not found at $RUBRIC. The SDD repo is missing its rubric." >&2
  exit 1
fi

echo "SDD install → $TARGET"
echo ""

copy_if_absent() {
  local src="$1"
  local dst="$2"
  if [ -e "$dst" ] && [ "$FORCE" = "0" ]; then
    echo "  skip   $dst (exists)"
  else
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
    echo "  write  $dst"
  fi
}

# Top-level .sdd/ and .claude/ trees
copy_if_absent "$TEMPLATES/.sdd" "$TARGET/.sdd"
copy_if_absent "$TEMPLATES/.claude" "$TARGET/.claude"

# dashboard.html at project root
copy_if_absent "$TEMPLATES/dashboard.html" "$TARGET/dashboard.html"

# rubric.md at project root (used as template when starting new features)
copy_if_absent "$RUBRIC" "$TARGET/rubric.md"

# Ensure hook scripts are executable (cp preserves mode on macOS/Linux, but be safe)
if [ -d "$TARGET/.claude/hooks" ]; then
  chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
fi

# agent-browser global install — delegated to its own script
"$SCRIPT_DIR/install-agent-browser.sh" || echo "  (agent-browser install skipped or failed — run scripts/install-agent-browser.sh later)"

echo ""
echo "Done. Next steps:"
echo "  1. Review .sdd/CLAUDE.md and rubric.md — these are your workflow's 'personality'. Edit freely."
echo "  2. Start a feature: tell Claude 'work on <feature name>' or run /next."
echo "  3. Serve the dashboard: npx serve . (then open http://localhost:3000/dashboard.html)"
