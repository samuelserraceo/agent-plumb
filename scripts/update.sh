#!/usr/bin/env bash
# SDD update — pull the latest canonical workflow rules into an existing project.
#
# What it touches (overwrites with template versions):
#   - .sdd/rubric.md
#   - .sdd/CLAUDE.version
#   - .claude/hooks/*.sh
#   - .claude/settings.json
#   - .claude/commands/*.md
#   - The MANAGED section of CLAUDE.md (between SDD-MANAGED-START and SDD-MANAGED-END)
#
# What it NEVER touches:
#   - .sdd/INDEX.md, .sdd/data-model.md, .sdd/patterns.md (your project state)
#   - .sdd/features/ (your features and history)
#   - The "Project Rules" section of CLAUDE.md (everything below SDD-MANAGED-END)
#
# Usage:
#   cd <your-project-root>
#   <path-to-sdd>/scripts/update.sh
#
# Always backs up CLAUDE.md to CLAUDE.md.bak before swapping the managed block.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TEMPLATES="$REPO_ROOT/templates"
TARGET="$(pwd)"

# ─── Preflight ──────────────────────────────────────────────────────

[ -d "$TEMPLATES" ] || { echo "ERROR: SDD templates/ not found at $TEMPLATES" >&2; exit 1; }
[ -d "$TARGET/.sdd" ] || { echo "ERROR: $TARGET/.sdd/ not found — is this an SDD project? Run init.sh first." >&2; exit 1; }

# Read template version
TEMPLATE_VERSION=$(cat "$TEMPLATES/.sdd/CLAUDE.version" 2>/dev/null || echo "unknown")
LOCAL_VERSION=$(cat "$TARGET/.sdd/CLAUDE.version" 2>/dev/null || echo "unknown")

echo "SDD update → $TARGET"
echo "  Template version: $TEMPLATE_VERSION"
echo "  Local version:    $LOCAL_VERSION"
echo ""

if [ "$TEMPLATE_VERSION" = "$LOCAL_VERSION" ]; then
  echo "Already on $TEMPLATE_VERSION. Nothing to update."
  echo "(Pass --force to re-apply anyway.)"
  if [ "${1:-}" != "--force" ]; then exit 0; fi
fi

# ─── Update non-managed files (overwrite) ──────────────────────────

echo "→ Updating canonical files…"
# Copy all rubric files (rubric.md for features, rubric-bug.md, rubric-idea.md, etc.)
for r in "$TEMPLATES/.sdd/"rubric*.md; do
  [ -f "$r" ] || continue
  base=$(basename "$r")
  cp "$r" "$TARGET/.sdd/$base" && echo "  ✓ .sdd/$base"
done
cp "$TEMPLATES/.sdd/CLAUDE.version" "$TARGET/.sdd/CLAUDE.version" && echo "  ✓ .sdd/CLAUDE.version"

# Ensure .sdd/ideas/ directory exists (for /idea command)
mkdir -p "$TARGET/.sdd/ideas"
[ ! -f "$TARGET/.sdd/ideas/.gitkeep" ] && touch "$TARGET/.sdd/ideas/.gitkeep"

# Hooks + commands + settings
mkdir -p "$TARGET/.claude/hooks" "$TARGET/.claude/commands"
cp "$TEMPLATES/.claude/hooks/"*.sh        "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/"*.sh
cp "$TEMPLATES/.claude/commands/"*.md      "$TARGET/.claude/commands/"
cp "$TEMPLATES/.claude/settings.json"      "$TARGET/.claude/settings.json"
echo "  ✓ .claude/hooks/, commands/, settings.json"

# Runtime scripts (ralph.sh, ship.sh, install-agent-browser.sh) live in the SDD repo's
# scripts/ directory and need to be copied into the user's project so /ship and /ralph work.
mkdir -p "$TARGET/scripts"
for s in ralph.sh ship.sh install-agent-browser.sh; do
  cp "$REPO_ROOT/scripts/$s" "$TARGET/scripts/$s"
done
chmod +x "$TARGET/scripts/"*.sh 2>/dev/null || true
echo "  ✓ scripts/ralph.sh, ship.sh, install-agent-browser.sh"

# ─── Update CLAUDE.md MANAGED block in place ───────────────────────

if [ ! -f "$TARGET/CLAUDE.md" ]; then
  # No existing CLAUDE.md — drop the template directly.
  cp "$TEMPLATES/CLAUDE.md" "$TARGET/CLAUDE.md"
  echo "  ✓ CLAUDE.md (no existing file — template installed in full)"
else
  # Backup
  cp "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.md.bak"

  # Pull the new managed block from the template
  python3 <<PY
import pathlib, re

template = pathlib.Path("$TEMPLATES/CLAUDE.md").read_text()
target_p = pathlib.Path("$TARGET/CLAUDE.md")
target = target_p.read_text()

start_marker = "<!-- SDD-MANAGED-START"
end_marker = "<!-- SDD-MANAGED-END -->"

def extract_block(text):
    m = re.search(re.escape(start_marker) + r".*?" + re.escape(end_marker), text, flags=re.DOTALL)
    return m.group(0) if m else None

template_block = extract_block(template)
if template_block is None:
    raise SystemExit("Template CLAUDE.md missing managed markers — aborting")

target_block = extract_block(target)
if target_block is None:
    # No existing managed block — prepend to existing CLAUDE.md
    new = template_block + "\n\n" + target
else:
    new = target.replace(target_block, template_block, 1)

target_p.write_text(new)
PY
  echo "  ✓ CLAUDE.md MANAGED block (backup at CLAUDE.md.bak)"
fi

# ─── Auto-remove deprecated files ──────────────────────────────────

ver_le() {
  # Returns 0 if $1 ≤ $2 (semver-ish, two-or-three-part)
  [ "$1" = "$2" ] && return 0
  printf '%s\n%s\n' "$1" "$2" | sort -V -C 2>/dev/null
}

ver_gt_local() {
  # True if $1 > LOCAL_VERSION (so the deprecation/migration applies on this update)
  if [ "$LOCAL_VERSION" = "unknown" ]; then return 0; fi
  ! ver_le "$1" "$LOCAL_VERSION"
}

if [ -f "$TEMPLATES/DEPRECATED.list" ]; then
  removed_count=0
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    dep_ver=$(echo "$line" | awk '{print $1}')
    dep_path=$(echo "$line" | awk '{print $2}')
    [ -z "$dep_ver" ] || [ -z "$dep_path" ] && continue
    if ver_gt_local "$dep_ver" && ver_le "$dep_ver" "$TEMPLATE_VERSION"; then
      if [ -e "$TARGET/$dep_path" ]; then
        rm -rf "$TARGET/$dep_path"
        echo "  ✓ removed deprecated: $dep_path (deprecated in $dep_ver)"
        removed_count=$((removed_count + 1))
      fi
    fi
  done < "$TEMPLATES/DEPRECATED.list"
  [ $removed_count -eq 0 ] && echo "  (no deprecated files to remove)"
fi

# ─── Run migrations in order ───────────────────────────────────────

if [ -d "$TEMPLATES/migrations" ]; then
  ran_count=0
  for mig in $(ls "$TEMPLATES/migrations/to-"*.sh 2>/dev/null | sort -V); do
    mig_ver=$(basename "$mig" | sed -E 's/^to-([0-9.]+)\.sh$/\1/')
    if ver_gt_local "$mig_ver" && ver_le "$mig_ver" "$TEMPLATE_VERSION"; then
      echo "  → running migration to-$mig_ver…"
      bash "$mig" "$TARGET"
      ran_count=$((ran_count + 1))
    fi
  done
  [ $ran_count -eq 0 ] && echo "  (no migrations needed)"
fi

echo ""
echo "Done. Review changes:"
echo "  diff CLAUDE.md.bak CLAUDE.md"
echo ""
echo "Your Project Rules section + everything outside the MANAGED block is untouched."
echo "Your .sdd/INDEX.md (your data), data-model.md, patterns.md, and features/ are untouched."
