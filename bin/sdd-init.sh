#!/usr/bin/env bash
# sdd-init.sh — Plugin SessionStart hook (v0.11).
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

# CodeRabbit cycle 3 (PR #31): preflight ALL required template paths
# before writing anything. Earlier the script wrote .sdd/, then
# discovered .claude/ was missing and aborted — leaving the project
# in a half-initialised state (.sdd present, .claude absent, no
# CLAUDE.md). Validate everything first; write second.
TEMPLATE_SDD="$PLUGIN_ROOT/templates/.sdd"
TEMPLATE_CLAUDE="$PLUGIN_ROOT/templates/.claude"
TEMPLATE_CLAUDE_MD="$PLUGIN_ROOT/templates/CLAUDE.md"

missing=""
[ -d "$TEMPLATE_SDD" ]      || missing="$missing  - $TEMPLATE_SDD\n"
[ -d "$TEMPLATE_CLAUDE" ]   || missing="$missing  - $TEMPLATE_CLAUDE\n"
[ -f "$TEMPLATE_CLAUDE_MD" ] || missing="$missing  - $TEMPLATE_CLAUDE_MD\n"
if [ -n "$missing" ]; then
  echo "[SDD init] Required template paths missing at plugin root:" >&2
  printf "$missing" >&2
  echo "[SDD init] Plugin install may be corrupt — try reinstalling." >&2
  exit 1
fi

# CodeRabbit cycle 3: refuse to overwrite an existing .claude/ — the
# user may have customised it (their own commands/hooks). If
# .claude/ exists, surface the conflict explicitly. .sdd/ presence
# was already gated by the idempotency check above (we only get here
# if .sdd/ does NOT exist), so it's safe to write.
if [ -d ".claude" ]; then
  echo "[SDD init] .claude/ already exists in project — refusing to overwrite." >&2
  echo "[SDD init] Either move it aside (mv .claude .claude.bak) or merge SDD's" >&2
  echo "[SDD init] templates/.claude/ contents into yours by hand:" >&2
  echo "[SDD init]   $TEMPLATE_CLAUDE" >&2
  exit 1
fi

echo "[SDD init] First-time setup of SDD in this project ($PROJECT_DIR)…"

# Copy framework files. Order: .sdd first (largest, most likely to
# fail on disk space), then .claude, then CLAUDE.md. If a later step
# fails the user already has the bigger piece — easier to recover.
cp -r "$TEMPLATE_SDD" .sdd || {
  echo "[SDD init] failed to copy .sdd/ into project — check disk space + permissions." >&2
  exit 1
}
cp -r "$TEMPLATE_CLAUDE" .claude || {
  echo "[SDD init] failed to copy .claude/ into project — check disk space + permissions." >&2
  exit 1
}
cp "$TEMPLATE_CLAUDE_MD" CLAUDE.md || {
  echo "[SDD init] failed to copy CLAUDE.md — check disk space + permissions." >&2
  exit 1
}

# D9 (stress-test) — copy the Obsidian vault config from templates/.obsidian
# if it ships with this version of the framework. Item 3 (#90) added this
# in v1.0 but only via the legacy scripts/init.sh path; the plugin-path
# install (this script) was missed. Plugin-path users were getting an SDD
# project with no Obsidian configuration.
TEMPLATE_OBSIDIAN="$PLUGIN_ROOT/templates/.obsidian"
if [ -d "$TEMPLATE_OBSIDIAN" ] && [ ! -d ".obsidian" ]; then
  cp -r "$TEMPLATE_OBSIDIAN" .obsidian || {
    # Non-fatal — the project still works without Obsidian. Tell the user.
    echo "[SDD init] note: failed to copy templates/.obsidian/ (Obsidian vault config)." >&2
    echo "[SDD init]       The project still works; you just lose the graph view." >&2
  }
fi

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
# CR cycle-6 Major — also add `.obsidian/` if we just copied the Obsidian
# vault config. The vault directory accumulates per-user state (workspace.json,
# pinned tabs, recent-files history) that should never land in the project
# repo. The committed copy lives at `templates/.obsidian/`; downstream
# projects keep their own .obsidian/ local-only.
GITIGNORE="$PROJECT_DIR/.gitignore"
gitignore_block=""
if [ -f "$GITIGNORE" ]; then
  if ! grep -qF ".sdd/.advance.last-head" "$GITIGNORE" 2>/dev/null; then
    gitignore_block="${gitignore_block}# SDD runtime state (don't commit)"$'\n'".sdd/.advance.last-head"$'\n'
  fi
  if [ -d "$PROJECT_DIR/.obsidian" ] && ! grep -qF "/.obsidian/" "$GITIGNORE" 2>/dev/null; then
    gitignore_block="${gitignore_block}# Per-user Obsidian vault state (don't commit; templates/.obsidian/ is the shipped copy)"$'\n'"/.obsidian/"$'\n'
  fi
  if [ -n "$gitignore_block" ]; then
    printf '\n%s' "$gitignore_block" >> "$GITIGNORE"
  fi
else
  {
    echo "# SDD runtime state (don't commit)"
    echo ".sdd/.advance.last-head"
    if [ -d "$PROJECT_DIR/.obsidian" ]; then
      echo ""
      echo "# Per-user Obsidian vault state (don't commit; templates/.obsidian/ is the shipped copy)"
      echo "/.obsidian/"
    fi
  } > "$GITIGNORE"
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
