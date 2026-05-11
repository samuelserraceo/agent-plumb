#!/usr/bin/env bash
# rename-collided-feature.sh — idea 007 final.
#
# Renames a feature folder when two branches independently scaffolded
# the same NNN-prefix and you discover the collision before merging.
# Updates wiki-links inside the renamed folder's spec.md (and any other
# files under the folder) from `[[<old-id>-<slug>]]` to
# `[[<new-id>-<slug>]]` so internal references stay coherent.
#
# REFUSES TO RUN if decisions.md already references the old slug via a
# wiki-link — decisions.md is append-only by framework contract, so the
# rename would either fail at commit time or require rewriting history.
# In that case both folders must coexist (the slug after the NNN- is
# already enough to disambiguate in decisions.md).
#
# Usage:
#   bash .sdd/scripts/rename-collided-feature.sh <old-id-slug> <new-id-slug>
#
# Example:
#   bash .sdd/scripts/rename-collided-feature.sh \
#     011-per-file-injection-budgets \
#     016-per-file-injection-budgets
#
# Both arguments MUST start with a 3-digit ID. The work-folder
# (features / bugs / refactors / ideas / ...) is auto-detected by
# scanning .sdd/*/<id>-*/ — the first match wins.
#
# Exits 0 on success, 1 on usage error, 2 on append-only block.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || { echo "[rename-collided-feature] cannot cd to $PROJECT_DIR" >&2; exit 1; }

OLD="${1:-}"
NEW="${2:-}"

if [ -z "$OLD" ] || [ -z "$NEW" ]; then
  cat >&2 <<'EOF'
[rename-collided-feature] usage:
  bash .sdd/scripts/rename-collided-feature.sh <old-id-slug> <new-id-slug>

Both arguments must start with a 3-digit ID, e.g.:
  bash .sdd/scripts/rename-collided-feature.sh \
    011-per-file-injection-budgets \
    016-per-file-injection-budgets

Run this BEFORE the first decisions.md entry references the old slug.
After that, append-only blocks the rename — let both folders coexist.
EOF
  exit 1
fi

# Shape check: each argument must match NNN-<slug>.
case "$OLD" in
  [0-9][0-9][0-9]-*) ;;
  *) echo "[rename-collided-feature] old id '$OLD' must start with NNN- (3 digits)" >&2; exit 1 ;;
esac
case "$NEW" in
  [0-9][0-9][0-9]-*) ;;
  *) echo "[rename-collided-feature] new id '$NEW' must start with NNN- (3 digits)" >&2; exit 1 ;;
esac

[ -d ".sdd" ] || { echo "[rename-collided-feature] no .sdd/ directory — not an SDD project" >&2; exit 1; }

# Find the work-folder containing $OLD. First match wins.
OLD_DIR=""
WORK_FOLDER=""
for wf_dir in .sdd/*/; do
  candidate="${wf_dir}${OLD}"
  if [ -d "$candidate" ]; then
    OLD_DIR="$candidate"
    WORK_FOLDER=$(basename "$wf_dir")
    break
  fi
done

if [ -z "$OLD_DIR" ]; then
  echo "[rename-collided-feature] no folder found at .sdd/*/$OLD — already renamed or never existed?" >&2
  exit 1
fi

NEW_DIR=".sdd/${WORK_FOLDER}/${NEW}"
if [ -e "$NEW_DIR" ]; then
  echo "[rename-collided-feature] destination already exists: $NEW_DIR — pick a different new id" >&2
  exit 1
fi

# Append-only guard: refuse if decisions.md references the old slug via wiki-link.
DECISIONS=".sdd/decisions.md"
if [ -f "$DECISIONS" ] && grep -qF "[[${OLD}]]" "$DECISIONS"; then
  cat >&2 <<EOF
[rename-collided-feature] REFUSED.

  .sdd/decisions.md already contains \`[[${OLD}]]\` — at least one
  past entry references this feature by its full slug. decisions.md
  is append-only by framework contract (\`file_rules.append_only\`),
  so rewriting prior content would fail at commit time anyway.

  What to do instead — let both feature folders coexist:

    - Keep $OLD_DIR
    - Keep the parallel folder that collided (different NNN- prefix
      already disambiguates them in any new decisions.md entries).
    - From now on, use the full slug in wiki-links to remove ambiguity.

  This is the documented fallback when collision detection fires
  AFTER decisions.md already pinned the slug. See CLAUDE.md
  "Multi-feature parallel work" → ID-collision tooling.
EOF
  exit 2
fi

# Perform the rename.
mv "$OLD_DIR" "$NEW_DIR" || { echo "[rename-collided-feature] mv failed" >&2; exit 1; }

# Rewrite wiki-links inside the renamed folder (spec.md + any other markdown).
# Scope: only files INSIDE the renamed folder — does NOT touch decisions.md
# (the guard above already proved nothing in decisions.md mentions OLD).
files_touched=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # POSIX-safe rewrite — use python3 to keep grep/sed cross-version compat.
  python3 - "$f" "$OLD" "$NEW" <<'PYEOF' || continue
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, 'r', encoding='utf-8') as fh:
        text = fh.read()
except OSError:
    sys.exit(0)
new_text = text.replace(f'[[{old}]]', f'[[{new}]]')
if new_text != text:
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(new_text)
    print("touched")
PYEOF
  if [ -f "$f" ] && grep -qF "[[${NEW}]]" "$f" 2>/dev/null; then
    files_touched=$((files_touched + 1))
  fi
done < <(find "$NEW_DIR" -type f -name '*.md' 2>/dev/null)

cat <<EOF
[rename-collided-feature] OK.
  - moved: $OLD_DIR -> $NEW_DIR
  - wiki-links rewritten inside the folder (files touched: $files_touched)
  - decisions.md: untouched (no prior wiki-link to '$OLD' — append-only respected)

Next:
  - If you've already committed under the old slug, re-stage the move:
      git add -A
  - If your branch name embeds the old slug (sdd/${OLD}), rename it:
      git branch -m sdd/${NEW}
  - Re-run /next to keep going.
EOF

exit 0
