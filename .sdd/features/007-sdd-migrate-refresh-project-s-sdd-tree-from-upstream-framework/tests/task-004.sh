#!/usr/bin/env bash
# AC4 — dry-run on a project where user has locally edited a tracked
# framework file (hash differs from BOTH upstream AND prior shipped) →
# reports under UPDATE-CONFLICT.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/templates/.sdd/scripts/sdd-migrate.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: sdd-migrate.sh missing"; exit 1; }

tmpdir=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir" || { echo "FAIL: cd $tmpdir failed"; exit 1; }

mkdir -p .sdd .claude
cp -R "$FRAMEWORK_ROOT/templates/.sdd/." .sdd/ 2>/dev/null
cp -R "$FRAMEWORK_ROOT/templates/.claude/." .claude/ 2>/dev/null

# Local edit: change advance.sh to something neither upstream nor any
# prior shipped version would have.
target=".sdd/scripts/advance.sh"
echo '#!/usr/bin/env bash' > "$target"
echo '# user-edited content that nobody else has' >> "$target"
echo 'echo "users custom logic"' >> "$target"
chmod +x "$target"

# Manifest still has the OLD shipped hash (because the user installed
# at some past version) — for this scenario we leave the manifest
# untouched. The user's edited content will not match either upstream
# (newer) or the manifest's stored hash (prior shipped) → CONFLICT.

out=$(bash "$SCRIPT" --upstream="$FRAMEWORK_ROOT" 2>&1)
ec=$?

fails=()
[ "$ec" -eq 0 ] || fails+=("expected exit 0, got $ec")
printf '%s' "$out" | grep -qE '^\s*! .sdd/scripts/advance.sh' \
  || fails+=("expected advance.sh in UPDATE-CONFLICT list")
printf '%s' "$out" | grep -qE '^\s*~ .sdd/scripts/advance.sh' \
  && fails+=("advance.sh wrongly appeared in UPDATE-CLEAN")

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC4 — locally edited file should be UPDATE-CONFLICT"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Output:"
  printf '%s\n' "$out" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC4 — locally edited file → UPDATE-CONFLICT"
exit 0
