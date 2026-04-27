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
#   <slug>            — the sub-action whose section was edited
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

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 1

spec="$work_item_dir/spec.md"
ver="$work_item_dir/verification.json"
sa_path="$PROJECT_DIR/.sdd/subactions/$slug.md"

[ -f "$spec" ] || { echo "reapprove: spec not found at $spec" >&2; exit 1; }
[ -f "$sa_path" ] || { echo "reapprove: sub-action not found at $sa_path" >&2; exit 1; }

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
        with open(ver_path) as f:
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

with open(ver_path, "w") as f:
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
