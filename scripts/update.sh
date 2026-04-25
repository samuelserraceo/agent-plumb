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
cp "$TEMPLATES/.sdd/rubric.md" "$TARGET/.sdd/rubric.md"           && echo "  ✓ .sdd/rubric.md"
cp "$TEMPLATES/.sdd/CLAUDE.version" "$TARGET/.sdd/CLAUDE.version" && echo "  ✓ .sdd/CLAUDE.version"

# Hooks + commands + settings
mkdir -p "$TARGET/.claude/hooks" "$TARGET/.claude/commands"
cp "$TEMPLATES/.claude/hooks/"*.sh        "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/"*.sh
cp "$TEMPLATES/.claude/commands/"*.md      "$TARGET/.claude/commands/"
cp "$TEMPLATES/.claude/settings.json"      "$TARGET/.claude/settings.json"
echo "  ✓ .claude/hooks/, commands/, settings.json"

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

echo ""
echo "Done. Review changes:"
echo "  diff CLAUDE.md.bak CLAUDE.md"
echo ""
echo "Your Project Rules section + everything outside the MANAGED block is untouched."
echo "Your .sdd/INDEX.md, data-model.md, patterns.md, and features/ are untouched."
