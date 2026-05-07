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

# Refuse only if the user has substantive customisations (their own
# commands, hooks, agents, skills, mcp config). A bare .claude/
# containing just settings.json is the normal plugin-install state —
# Claude Code creates that BEFORE this SessionStart hook fires when
# the user installs SDD as a project-scope plugin. In that case we
# merge templates/.claude/ INTO the existing .claude/, preserving
# settings.json (the "enabledPlugins" marker).
merge_into_existing_claude=0
if [ -d ".claude" ]; then
  for sub in commands hooks agents skills mcp; do
    if [ -d ".claude/$sub" ] && [ -n "$(ls -A ".claude/$sub" 2>/dev/null)" ]; then
      echo "[SDD init] .claude/$sub/ already has user content — refusing to overwrite." >&2
      echo "[SDD init] Either move .claude aside (mv .claude .claude.bak) or merge SDD's" >&2
      echo "[SDD init] templates/.claude/ contents into yours by hand:" >&2
      echo "[SDD init]   $TEMPLATE_CLAUDE" >&2
      exit 1
    fi
  done
  merge_into_existing_claude=1
fi

echo "[SDD init] First-time setup of SDD in this project ($PROJECT_DIR)…"

# Copy framework files. Order: .sdd first (largest, most likely to
# fail on disk space), then .claude, then CLAUDE.md. If a later step
# fails the user already has the bigger piece — easier to recover.
cp -r "$TEMPLATE_SDD" .sdd || {
  echo "[SDD init] failed to copy .sdd/ into project — check disk space + permissions." >&2
  exit 1
}
if [ "$merge_into_existing_claude" -eq 1 ]; then
  # Plugin install pre-created .claude/ with just settings.json
  # (containing enabledPlugins). Stash it, copy templates over,
  # then merge so SDD's hooks land WITHOUT clobbering enabledPlugins.
  existing_settings_tmp=""
  if [ -f .claude/settings.json ]; then
    existing_settings_tmp=$(mktemp -t sdd-init-settings.XXXXXX) || {
      echo "[SDD init] failed to allocate tempfile for settings merge." >&2
      exit 1
    }
    cp .claude/settings.json "$existing_settings_tmp"
  fi
  cp -R "$TEMPLATE_CLAUDE/." .claude/ || {
    echo "[SDD init] failed to merge .claude/ contents — check disk space + permissions." >&2
    [ -n "$existing_settings_tmp" ] && rm -f "$existing_settings_tmp"
    exit 1
  }
  if [ -n "$existing_settings_tmp" ]; then
    if ! python3 - "$existing_settings_tmp" .claude/settings.json <<'PY'
import json, sys
prior = json.load(open(sys.argv[1]))
template = json.load(open(sys.argv[2]))
# Template wins on overlap (gives SDD its hook registrations); prior's
# top-level keys (notably enabledPlugins) are layered on top so the
# plugin-install marker survives.
merged = {**template, **{k: v for k, v in prior.items() if k != "hooks"}}
if "hooks" in prior and "hooks" in template:
    merged["hooks"] = {**template["hooks"], **prior["hooks"]}
json.dump(merged, open(sys.argv[2], "w"), indent=2)
PY
    then
      echo "[SDD init] settings.json merge failed — restoring plugin marker." >&2
      cp "$existing_settings_tmp" .claude/settings.json
      rm -f "$existing_settings_tmp"
      exit 1
    fi
    rm -f "$existing_settings_tmp"
  fi
else
  cp -r "$TEMPLATE_CLAUDE" .claude || {
    echo "[SDD init] failed to copy .claude/ into project — check disk space + permissions." >&2
    exit 1
  }
fi
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
# CR cycle-6 Major / cycle-7 Major refinement — ALWAYS add `/.obsidian/`,
# regardless of whether we just copied templates/.obsidian/. Reasoning:
# even if the vault copy failed (non-fatal at line 116) or the plugin
# build doesn't ship templates/.obsidian/, a downstream user can still
# open the project in Obsidian themselves at any later time and create
# a local `.obsidian/` directory. Pre-emptively ignoring it prevents
# accidental commits of per-user vault state. The committed copy lives
# at `templates/.obsidian/`; downstream projects keep their own
# .obsidian/ local-only.
GITIGNORE="$PROJECT_DIR/.gitignore"
gitignore_block=""
if [ -f "$GITIGNORE" ]; then
  if ! grep -qF ".sdd/.advance.last-head" "$GITIGNORE" 2>/dev/null; then
    gitignore_block="${gitignore_block}# SDD runtime state (don't commit)"$'\n'".sdd/.advance.last-head"$'\n'
  fi
  if ! grep -qF "/.obsidian/" "$GITIGNORE" 2>/dev/null; then
    gitignore_block="${gitignore_block}# Per-user Obsidian vault state (don't commit; templates/.obsidian/ is the shipped copy)"$'\n'"/.obsidian/"$'\n'
  fi
  # Closes #176 — extensions/ is a per-machine symlink to the plugin
  # install's MCP server. The path differs per user (Linux/macOS/WSL),
  # so it's never committable. Always added preemptively, same shape
  # as the .obsidian/ rule above.
  if ! grep -qF "/extensions/" "$GITIGNORE" 2>/dev/null; then
    gitignore_block="${gitignore_block}# Per-machine symlink to the SDD plugin's MCP server (don't commit; sdd-init.sh manages it)"$'\n'"/extensions/"$'\n'
  fi
  if [ -n "$gitignore_block" ]; then
    printf '\n%s' "$gitignore_block" >> "$GITIGNORE"
  fi
else
  cat > "$GITIGNORE" <<'EOF'
# SDD runtime state (don't commit)
.sdd/.advance.last-head

# Per-user Obsidian vault state (don't commit; templates/.obsidian/ is the shipped copy)
/.obsidian/

# Per-machine symlink to the SDD plugin's MCP server (don't commit; sdd-init.sh manages it)
/extensions/
EOF
fi

# Closes #176. Symlink the MCP server into the project so post-stop-lint
# can find it (closes #175 — without the symlink, invariant 8 fires the
# "MCP missing" warning every turn). The MCP server lives in the plugin
# install at $PLUGIN_ROOT/extensions/sdd-mcp-server/; project-local hooks
# look at $PROJECT_DIR/extensions/sdd-mcp-server/.
#
# Symlink (not copy): per-machine, points at the user's installed plugin
# version. When they upgrade the plugin via /plugin install, the symlink
# auto-resolves to the new version. The /extensions/ entry was added to
# .gitignore above so the symlink never gets committed.
MCP_SOURCE="$PLUGIN_ROOT/extensions/sdd-mcp-server"
MCP_TARGET="$PROJECT_DIR/extensions/sdd-mcp-server"
if [ -d "$MCP_SOURCE" ]; then
  if [ -e "$MCP_TARGET" ] || [ -L "$MCP_TARGET" ]; then
    : # Already linked / present; idempotent silent skip.
  else
    # CR cycle 1 (#190): fold mkdir into the same condition as ln
    # so a read-only-fs failure goes through the non-fatal warning
    # path instead of `set -e` aborting the script silently. The
    # rest of init has already succeeded by this point — losing
    # wiki-link checking is a soft warning, not a reason to fail
    # the whole bootstrap.
    if mkdir -p "$PROJECT_DIR/extensions" 2>/dev/null && \
       ln -sfn "$MCP_SOURCE" "$MCP_TARGET" 2>/dev/null; then
      echo "[SDD init] Symlinked MCP server into project (extensions/sdd-mcp-server → plugin install). Wiki-link resolution active."
    else
      cat >&2 <<EOM
[SDD init] note: couldn't symlink MCP server — wiki-link checking will be silent.
[SDD init] To enable: mkdir -p "$PROJECT_DIR/extensions" && ln -sfn "$MCP_SOURCE" "$MCP_TARGET"
[SDD init] Or set CLAUDE_PLUGIN_ROOT in your shell. (See #175 / #176.)
EOM
    fi
  fi
else
  cat >&2 <<EOM
[SDD init] note: MCP server not found at $MCP_SOURCE — wiki-link checking will be silent.
[SDD init] This is a setup warning, not a blocker. The framework still works without it.
EOM
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
