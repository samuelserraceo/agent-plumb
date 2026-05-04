#!/usr/bin/env bash
# sdd-migrate.sh — refresh project's .sdd/ + .claude/ from upstream framework.
#
# Closes the SDD-identity gap that previously made framework updates
# manual: when a teammate installed SDD a week ago, today's hook fixes
# don't reach them via /plugin update (Channel A) — only the .claude/
# layer auto-flows. The .sdd/ project tree (Channel B) needed a tool
# to refresh framework files without losing project-specific data.
#
# Categorises every framework-tracked file as:
#   ADD               — upstream has, user doesn't (new since user installed)
#   UPDATE-CLEAN      — user has stock prior version, upstream has newer
#   UPDATE-CONFLICT   — user has local edits (prompts before overwrite)
#   REMOVED           — upstream removed, user has (left untouched)
#
# Dry-run is the default; --apply opts in to actually changing files.
#
# User-data files (spec.md, INDEX.md, decisions.md, patterns.md,
# data-model.md, stack.md, principles.md, .sdd/features/**, .sdd/bugs/**,
# .sdd/refactors/**, .sdd/ideas/**, .sdd/.cache/) are excluded by
# walk-list — sdd-migrate never touches them. The list is enforced by
# choosing TRACKED_DIRS below; files outside those dirs are invisible
# to the script.
#
# Exits:
#   0 — dry-run completed (regardless of drift count) OR --apply done
#   2 — usage error / upstream not found

set -uo pipefail

# ─── Argument parsing ────────────────────────────────────────────────
UPSTREAM=""
APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --upstream=*) UPSTREAM="${1#--upstream=}" ;;
    --upstream) shift; UPSTREAM="${1:-}" ;;
    --apply) APPLY=1 ;;
    -h|--help)
      cat <<HELP
sdd-migrate — refresh project's .sdd/ + .claude/ from upstream framework

Usage:
  bash .sdd/scripts/sdd-migrate.sh --upstream=<path>             # dry-run
  bash .sdd/scripts/sdd-migrate.sh --apply --upstream=<path>     # apply

Categorises framework files as:
  ADD               — upstream has, user doesn't
  UPDATE-CLEAN      — user has stock prior version, upstream has newer
                      (safe overwrite under --apply)
  UPDATE-CONFLICT   — user has local edits (prompts before overwrite)
  REMOVED           — upstream removed, user has (left untouched)

User-data files (spec.md, INDEX.md, decisions.md, patterns.md,
data-model.md, stack.md, principles.md, .sdd/features/**, etc.)
are untouched.
HELP
      exit 0 ;;
    *) echo "[sdd-migrate] unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ -z "$UPSTREAM" ]; then
  echo "[sdd-migrate] --upstream=<path> required (point at a local SDD framework checkout)" >&2
  exit 2
fi
if [ ! -d "$UPSTREAM" ]; then
  echo "[sdd-migrate] upstream is not a directory: $UPSTREAM" >&2
  exit 2
fi

# ─── Hash helper ─────────────────────────────────────────────────────
# Same normalised SHA-256 the framework's manifest pin uses:
#   - CRLF/CR → LF
#   - strip BOM
#   - strip trailing whitespace per line
#   - strip blank-line edges
#   - hash UTF-8 bytes
hash_file() {
  local f="$1"
  [ -f "$f" ] || { echo ""; return; }
  python3 - "$f" <<'PY'
import hashlib, sys
p = sys.argv[1]
with open(p, 'rb') as fh:
    data = fh.read()
# Decode tolerantly; keep replacement chars
text = data.decode('utf-8', errors='replace')
# Normalise line endings + strip BOM
if text.startswith('﻿'):
    text = text[1:]
text = text.replace('\r\n', '\n').replace('\r', '\n')
# Strip trailing whitespace per line
lines = [ln.rstrip() for ln in text.split('\n')]
# Strip blank-line edges
while lines and lines[0] == '': lines.pop(0)
while lines and lines[-1] == '': lines.pop()
norm = '\n'.join(lines).encode('utf-8')
print(hashlib.sha256(norm).hexdigest())
PY
}

# ─── Tracked directory pairs ─────────────────────────────────────────
# (project-relative-prefix : templates-relative-prefix)
# All other paths are invisible — that's how user-data is excluded.
TRACKED=(
  ".claude/hooks"
  ".claude/commands"
  ".sdd/scripts"
  ".sdd/actions"
  ".sdd/playbooks"
  ".sdd/skeletons"
)

# Lookup table: framework-rel-path → prior-shipped-hash from user manifest.
USER_MANIFEST=".sdd/.cache/manifest.json"
declare -A PRIOR_HASH=()
if [ -f "$USER_MANIFEST" ]; then
  while IFS=$'\t' read -r path sha; do
    [ -n "$path" ] && PRIOR_HASH["$path"]="$sha"
  done < <(python3 -c "
import json, sys
try:
    m = json.load(open('$USER_MANIFEST'))
except Exception:
    sys.exit(0)
for section in ('scripts', 'actions', 'playbooks'):
    for name, entry in (m.get(section) or {}).items():
        if isinstance(entry, dict):
            p = entry.get('path', '')
            h = entry.get('expected_sha256', '')
            if p and h:
                print(f'{p}\t{h}')
")
fi

# ─── Categorisation ──────────────────────────────────────────────────
declare -a ADD_LIST=()
declare -a CLEAN_LIST=()
declare -a CONFLICT_LIST=()
declare -a REMOVED_LIST=()

for prefix in "${TRACKED[@]}"; do
  upstream_dir="$UPSTREAM/templates/$prefix"
  user_dir="$prefix"

  # Forward scan: every upstream file → ADD / synced / CLEAN / CONFLICT
  if [ -d "$upstream_dir" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      rel="${f#$upstream_dir/}"
      project_path="$prefix/$rel"
      user_file="$user_dir/$rel"

      upstream_hash=$(hash_file "$f")
      if [ ! -f "$user_file" ]; then
        ADD_LIST+=("$project_path")
        continue
      fi

      user_hash=$(hash_file "$user_file")
      if [ "$user_hash" = "$upstream_hash" ]; then
        :  # synced — silent
      else
        prior="${PRIOR_HASH[$project_path]:-}"
        if [ -n "$prior" ] && [ "$user_hash" = "$prior" ]; then
          CLEAN_LIST+=("$project_path")
        else
          CONFLICT_LIST+=("$project_path")
        fi
      fi
    done < <(find "$upstream_dir" -type f \( -name '*.sh' -o -name '*.md' -o -name '*.html' -o -name 'pre-commit' -o -name 'commit-msg' \) 2>/dev/null)
  fi

  # Reverse scan: every user file with no upstream counterpart → REMOVED
  if [ -d "$user_dir" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      rel="${f#$user_dir/}"
      upstream_file="$upstream_dir/$rel"
      if [ ! -f "$upstream_file" ]; then
        REMOVED_LIST+=("$prefix/$rel")
      fi
    done < <(find "$user_dir" -type f \( -name '*.sh' -o -name '*.md' -o -name '*.html' -o -name 'pre-commit' -o -name 'commit-msg' \) 2>/dev/null)
  fi
done

# ─── Print drift summary ─────────────────────────────────────────────
echo "== sdd-migrate drift summary =="
echo ""
echo "ADD (upstream has, user doesn't):"
if [ ${#ADD_LIST[@]} -eq 0 ]; then
  echo "  (none)"
else
  for f in "${ADD_LIST[@]}"; do echo "  + $f"; done
fi
echo ""
echo "UPDATE-CLEAN (user has stock prior version, upstream has newer):"
if [ ${#CLEAN_LIST[@]} -eq 0 ]; then
  echo "  (none)"
else
  for f in "${CLEAN_LIST[@]}"; do echo "  ~ $f"; done
fi
echo ""
echo "UPDATE-CONFLICT (user has local edits — confirmation needed on --apply):"
if [ ${#CONFLICT_LIST[@]} -eq 0 ]; then
  echo "  (none)"
else
  for f in "${CONFLICT_LIST[@]}"; do echo "  ! $f"; done
fi
echo ""
echo "REMOVED (upstream removed, user has — left alone):"
if [ ${#REMOVED_LIST[@]} -eq 0 ]; then
  echo "  (none)"
else
  for f in "${REMOVED_LIST[@]}"; do echo "  · $f"; done
fi
echo ""

total_changes=$(( ${#ADD_LIST[@]} + ${#CLEAN_LIST[@]} + ${#CONFLICT_LIST[@]} ))

if [ "$APPLY" -eq 0 ]; then
  if [ "$total_changes" -eq 0 ]; then
    echo "Project is in sync with upstream. No changes needed."
  else
    echo "To apply ADD + UPDATE-CLEAN automatically and prompt on UPDATE-CONFLICT:"
    echo "  bash .sdd/scripts/sdd-migrate.sh --apply --upstream=$UPSTREAM"
  fi
  exit 0
fi

# ─── Apply mode ──────────────────────────────────────────────────────
# T05+T06+T07 build out this path in subsequent commits. T01 ships the
# dry-run + skeleton; trying --apply now exits with a not-yet message
# rather than silently doing nothing.
echo "[sdd-migrate] --apply not yet implemented in T01 skeleton."
echo "Subsequent BUILD tasks (T05+) will land the apply path."
exit 0
