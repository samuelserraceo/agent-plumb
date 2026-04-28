#!/usr/bin/env bash
# sdd-init.sh — Plugin SessionStart hook (v0.10).
#
# When the SDD plugin is installed and a session starts in a project,
# this script auto-bootstraps the project if .sdd/ doesn't exist yet.
# It's idempotent — re-running on an already-bootstrapped project
# is a silent no-op.
#
# What it does:
#   1. Detect the project root (CLAUDE_PROJECT_DIR or pwd).
#   2. If .sdd/ already exists → print one line "[SDD] already initialized" + exit 0.
#   3. Otherwise: copy the framework templates from the plugin into
#      the project root: templates/.sdd → .sdd, templates/.claude →
#      .claude, templates/CLAUDE.md → CLAUDE.md.
#   4. Wire `core.hooksPath` to .claude/hooks (closes the moat-bypass
#      from combined `git add && git commit`). Refuses if the user
#      already has a hooksPath set to something else (Husky, lefthook).
#   5. Add `.sdd/.advance.last-head` to .gitignore so the runtime
#      stamp file doesn't get committed.
#   6. Print a short "you're set up" message + the first command to try.
#
# CLAUDE_PLUGIN_ROOT is set by Claude Code when the hook fires; it
# points at the plugin's installation directory.
#
# Exit:
#   0 — initialized successfully OR already initialized (no-op).
#   1 — error (templates missing, copy failed, hookspath conflict).
#       Stderr explains in plain English; the user can re-run after
#       fixing the issue.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

cd "$PROJECT_DIR" || {
  echo "[SDD init] cannot cd into project: $PROJECT_DIR" >&2
  exit 1
}

# Idempotency: skip if already initialized. Look for the canonical
# SDD marker (config.md inside .sdd/) — present on every fresh init,
# never touched after.
#
# CodeRabbit cycle 1: requiring CLAUDE.md alongside .sdd/ meant users
# with custom CLAUDE.md re-init'd repeatedly. CodeRabbit cycle 2:
# bare `[ -d ".sdd" ]` would skip init even if user accidentally
# created an empty `.sdd` for a different purpose. Check the marker.
if [ -d ".sdd" ] && [ -f ".sdd/config.md" ]; then
  # Silent no-op on session restarts.
  exit 0
fi

# Validate plugin templates exist.
if [ ! -d "$PLUGIN_ROOT/templates/.sdd" ]; then
  echo "[SDD init] templates/.sdd not found at plugin root: $PLUGIN_ROOT" >&2
  echo "[SDD init] Plugin install may be corrupt — try reinstalling." >&2
  exit 1
fi

echo "[SDD init] First-time setup of SDD in this project ($PROJECT_DIR)…"

# Copy framework files.
cp -r "$PLUGIN_ROOT/templates/.sdd" .sdd || {
  echo "[SDD init] failed to copy .sdd/ into project — check disk space + permissions." >&2
  exit 1
}
cp -r "$PLUGIN_ROOT/templates/.claude" .claude || {
  echo "[SDD init] failed to copy .claude/ into project — check disk space + permissions." >&2
  exit 1
}
cp "$PLUGIN_ROOT/templates/CLAUDE.md" CLAUDE.md || {
  echo "[SDD init] failed to copy CLAUDE.md — check disk space + permissions." >&2
  exit 1
}

# Wire git hooksPath if a git repo is present and no conflicting setup
# is in place. Same conflict-aware logic as start.sh — refuse to
# silently override an existing Husky/lefthook setup.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  current=$(git config --get core.hooksPath 2>/dev/null || echo "")
  if [ -z "$current" ]; then
    git config core.hooksPath .claude/hooks 2>/dev/null && \
      echo "[SDD init] Wired git pre-commit hooks to .claude/hooks (closes the SDD moat)."
  elif [ "$current" = ".claude/hooks" ]; then
    : # Already set; silent.
  else
    cat >&2 <<EOF
[SDD init] Note: your project already uses git hooks at:
  $current

SDD will not override your existing setup. To wire SDD's safety
checks instead, run:
  git config core.hooksPath .claude/hooks
EOF
  fi
fi

# Add the runtime stamp file to .gitignore so it doesn't get committed.
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -qF ".sdd/.advance.last-head" "$GITIGNORE" 2>/dev/null; then
    {
      echo ""
      echo "# SDD runtime state (don't commit)"
      echo ".sdd/.advance.last-head"
    } >> "$GITIGNORE"
  fi
else
  cat > "$GITIGNORE" <<'EOF'
# SDD runtime state (don't commit)
.sdd/.advance.last-head
EOF
fi

cat <<EOF
[SDD init] Done. SDD is set up in this project.

  Catalog:    .sdd/INDEX.md
  Settings:   .sdd/config.md
  Diary:      .sdd/decisions.md  (append-only)
  Lessons:    .sdd/patterns.md
  Data:       .sdd/data-model.md

Try this next:
  /sdd:start "<one-line title for what you want to build>"

Or read the rules first: open CLAUDE.md.
EOF

exit 0
