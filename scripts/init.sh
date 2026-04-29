#!/usr/bin/env bash
# SDD workflow installer.
# Drops .sdd/, .claude/, and CLAUDE.md into the current directory.
# Safe to re-run: will not overwrite existing files unless --force is passed.

set -euo pipefail

FORCE=0
if [ "${1:-}" = "--force" ]; then FORCE=1; fi

# Resolve the directory this script lives in, regardless of how it was invoked.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TEMPLATES="$REPO_ROOT/templates"
TARGET="$(pwd)"

if [ ! -d "$TEMPLATES" ]; then
  echo "ERROR: templates/ not found at $TEMPLATES. Run init.sh from a cloned copy of the SDD repo." >&2
  exit 1
fi

if [ ! -f "$TEMPLATES/.sdd/rubric.md" ]; then
  echo "ERROR: rubric not found at $TEMPLATES/.sdd/rubric.md. The SDD repo is missing its rubric." >&2
  exit 1
fi
if [ ! -f "$TEMPLATES/.sdd/rubric-bug.md" ]; then
  echo "ERROR: bug rubric not found at $TEMPLATES/.sdd/rubric-bug.md. The SDD repo is missing its bug rubric." >&2
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

# Top-level .sdd/ and .claude/ trees (.sdd/ already includes rubric.md,
# data-model.md, etc.). Same nesting guard as .obsidian below: a plain
# `copy_if_absent` would mis-copy under `--force` when the destination
# already exists, since `cp -R src dst-existing-dir` puts `.sdd` inside
# `.sdd/.sdd/`. Walk the contents so the destination is the directory
# ITSELF, not a parent of it.
for tree in .sdd .claude; do
  if [ -e "$TARGET/$tree" ] && [ "$FORCE" = "0" ]; then
    echo "  skip   $TARGET/$tree (exists)"
  else
    mkdir -p "$TARGET/$tree"
    cp -R "$TEMPLATES/$tree/." "$TARGET/$tree/"
    echo "  write  $TARGET/$tree"
  fi
done

# Optional Obsidian Tier-1 vault config (closes #83). Drops a minimal
# .obsidian/ directory so opening the project root in Obsidian renders
# the .sdd/ tree as a connected graph (features → decisions → patterns
# → data-model). Skipped if the user already has their own .obsidian/.
if [ -d "$TEMPLATES/.obsidian" ]; then
  # `copy_if_absent` would mis-copy this on `--force` when destination
  # already exists: `cp -R src dst` with dst-as-existing-dir nests
  # `.obsidian` into `.obsidian/.obsidian/`. Handle .obsidian/
  # explicitly: skip if a real `.obsidian/` already exists in the
  # target (user's own vault); otherwise copy by walking the contents
  # so the destination is the directory ITSELF, not a parent of it.
  if [ -e "$TARGET/.obsidian" ] && [ "$FORCE" = "0" ]; then
    echo "  skip   $TARGET/.obsidian (exists)"
  else
    mkdir -p "$TARGET/.obsidian"
    cp -R "$TEMPLATES/.obsidian/." "$TARGET/.obsidian/"
    echo "  write  $TARGET/.obsidian"
  fi
fi

# CLAUDE.md at project root — has SDD-managed section + your project rules section
copy_if_absent "$TEMPLATES/CLAUDE.md" "$TARGET/CLAUDE.md"

# Runtime scripts the project itself uses (ralph, ship, install-agent-browser).
# init.sh and update.sh stay in the SDD source repo — only project-runtime scripts get copied.
mkdir -p "$TARGET/scripts"
for s in ralph.sh ship.sh install-agent-browser.sh; do
  copy_if_absent "$REPO_ROOT/scripts/$s" "$TARGET/scripts/$s"
done
chmod +x "$TARGET/scripts/"*.sh 2>/dev/null || true

# Ensure hook scripts are executable (cp preserves mode on macOS/Linux, but be safe)
if [ -d "$TARGET/.claude/hooks" ]; then
  chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
fi

# agent-browser global install — delegated to its own script
"$SCRIPT_DIR/install-agent-browser.sh" || echo "  (agent-browser install skipped or failed — run scripts/install-agent-browser.sh later)"

echo ""
echo "Done. Next steps:"
echo "  1. Review CLAUDE.md (project root) and .sdd/rubric.md."
echo "  2. Start a feature: tell Claude 'work on <feature name>' or run /next."
echo "  3. Run /status anytime to see current state, or open .sdd/INDEX.md for the table of contents."
