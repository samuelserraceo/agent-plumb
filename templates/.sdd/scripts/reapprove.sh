#!/usr/bin/env bash
# reapprove.sh — body of the /re-approve slash command.
#
# Use case: user gets a Theme 1.6 moat block ("section §X CHANGED since
# you approved it") because spec.md content changed AFTER the user's
# original approval. If the new content is intentional, this script
# re-locks the new content by recomputing the section hash and writing
# it to verification.json's approved_sections.<slug>.
#
# Usage:
#   reapprove.sh <slug> <work-item-dir>
#
#   <slug>            — the action whose section was edited
#   <work-item-dir>   — the work item folder, e.g.
#                       .sdd/features/001-waitlist (must contain spec.md
#                       and verification.json)
#
# Behavior:
#   - Reads <work-item-dir>/spec.md
#   - Computes the new SHA-256 of the §<slug> section via hash-section.sh
#     (single source of truth — same algorithm as the moat)
#   - Reads <work-item-dir>/verification.json (creates one if missing)
#   - Updates approved_sections.<slug> to the new hash
#   - Writes verification.json back
#
# This script does NOT git-add or git-commit. The caller (the user or
# their /next slash command) is expected to:
#     git add <work-item-dir>/verification.json
#     git commit -m "[SDD:...] spec: re-approve §<slug>"
# This separation keeps reapprove.sh side-effect-light and lets the
# user review the diff before committing.
#
# Exit:
#   0 — verification.json updated successfully (new hash printed to stdout)
#   1 — error (file missing, hash failed, JSON malformed). Stderr explains.

set -uo pipefail

if [ $# -ne 2 ]; then
  echo "reapprove: usage: reapprove.sh <slug> <work-item-dir>" >&2
  exit 1
fi

slug="$1"
work_item_dir="$2"

# --- input validation (security: slug + work_item_dir come from CLI and are
# concatenated into file paths below; reject path-traversal payloads BEFORE
# any path construction).
#
# slug: closed-enum action shape — lowercase letters, digits, `_`, `-`, must
# start with a letter. Anything else (path separators, `..`, spaces) is a
# malformed action name and we refuse it.
if ! [[ "$slug" =~ ^[a-z][a-z0-9_-]*$ ]]; then
  echo "reapprove: invalid slug '$slug' — must be lowercase letters, digits, '_' or '-', starting with a letter" >&2
  exit 1
fi

# work_item_dir: must NOT contain `..` segments and must live inside `.sdd/`.
# Reuse validate-sdd-path.sh if available — it's the single source of truth
# for "is this path safe inside the framework root?".
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 1

VALIDATE_PATH="$PROJECT_DIR/.sdd/scripts/validate-sdd-path.sh"
[ -f "$VALIDATE_PATH" ] || VALIDATE_PATH="$PROJECT_DIR/templates/.sdd/scripts/validate-sdd-path.sh"
if [ -f "$VALIDATE_PATH" ]; then
  if ! bash "$VALIDATE_PATH" "$work_item_dir" >/dev/null; then
    echo "reapprove: invalid work-item-dir '$work_item_dir' — must be inside .sdd/ and contain no '..' segments" >&2
    exit 1
  fi
else
  # Fallback inline check if validate-sdd-path.sh is missing (defence in depth).
  case "$work_item_dir" in
    /*|[A-Za-z]:[/\\]*)
      echo "reapprove: invalid work-item-dir '$work_item_dir' — absolute paths not allowed" >&2
      exit 1
      ;;
  esac
  case "$work_item_dir" in
    .sdd|.sdd/*) ;;
    *)
      echo "reapprove: invalid work-item-dir '$work_item_dir' — must be inside .sdd/" >&2
      exit 1
      ;;
  esac
  normalised="${work_item_dir//\\//}"
  IFS='/' read -r -a parts <<< "$normalised"
  for seg in "${parts[@]}"; do
    if [ "$seg" = ".." ]; then
      echo "reapprove: invalid work-item-dir '$work_item_dir' — '..' segments not allowed" >&2
      exit 1
    fi
  done
fi

spec="$work_item_dir/spec.md"
ver="$work_item_dir/verification.json"
sa_path="$PROJECT_DIR/.sdd/actions/$slug.md"

[ -f "$spec" ] || { echo "reapprove: spec not found at $spec" >&2; exit 1; }
[ -f "$sa_path" ] || { echo "reapprove: action not found at $sa_path" >&2; exit 1; }

# Locate hash-section.sh
HASH_SECTION="$PROJECT_DIR/.sdd/scripts/hash-section.sh"
[ -f "$HASH_SECTION" ] || HASH_SECTION="$PROJECT_DIR/templates/.sdd/scripts/hash-section.sh"
[ -f "$HASH_SECTION" ] || {
  echo "reapprove: hash-section.sh not found (looked under .sdd/scripts/ and templates/.sdd/scripts/)" >&2
  exit 1
}

# Compute new hash for the §<slug> section in the current spec.md
new_hash=$(bash "$HASH_SECTION" "$spec" "$sa_path")
hs_ec=$?
if [ $hs_ec -ne 0 ] || [ -z "$new_hash" ]; then
  echo "reapprove: hash-section.sh failed for slug '$slug' (exit $hs_ec)" >&2
  exit 1
fi

# Update verification.json (create if missing). Use python3 for safe JSON.
SLUG="$slug" NEW_HASH="$new_hash" VER_PATH="$ver" python3 <<'PYEOF'
import json, os, sys

slug = os.environ["SLUG"]
new_hash = os.environ["NEW_HASH"]
ver_path = os.environ["VER_PATH"]

if os.path.isfile(ver_path):
    try:
        with open(ver_path, encoding="utf-8") as f:
            d = json.load(f)
    except Exception as e:
        print(f"reapprove: verification.json malformed: {e}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(d, dict):
        print(f"reapprove: verification.json is not a JSON object", file=sys.stderr)
        sys.exit(1)
else:
    # Create a minimal verification.json. The user can re-run verify-stage.sh
    # to populate phase + checks before committing.
    d = {"phase": "", "checks": []}

approved = d.get("approved_sections")
if approved is None or not isinstance(approved, dict):
    approved = {}
approved[slug] = new_hash
d["approved_sections"] = approved

with open(ver_path, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2, sort_keys=True)
    f.write("\n")
PYEOF

py_ec=$?
if [ $py_ec -ne 0 ]; then
  exit 1
fi

# Plain-English confirmation to stdout (caller can show the user)
cat <<EOF
[SDD] §$slug re-approved.
  new hash: ${new_hash:0:12}...

Next steps:
  git add $ver
  git commit -m "[SDD:<id>] spec: re-approve §$slug"
EOF
