#!/usr/bin/env bash
# AC7 — user-data files preserved bit-for-bit on --apply. The
# script's hard-coded TRACKED list excludes everything except .claude/
# {hooks,commands} + .sdd/{scripts,actions,playbooks,skeletons}; this
# test verifies a comprehensive set of user-data paths survive an
# --apply run.

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

# Trigger an actual --apply (so the test exercises the apply path, not
# just the dry-run): create one ADD drift.
rm -f .claude/hooks/pre-commit-test-first.sh

# Plant user-data files with sentinel content. None of these should be
# touched by --apply. CR cycle 1: snapshot sha256 before+after to
# verify bit-for-bit (sentinel grep alone could miss appended/mutated
# content that still contains the sentinel string).
mkdir -p .sdd/features/001-fake-feature .sdd/bugs/001-fake-bug .sdd/refactors/001-fake-refactor .sdd/ideas
SENTINEL="USER-DATA-SENTINEL-$$-DO-NOT-OVERWRITE"
echo "$SENTINEL" > .sdd/INDEX.md
echo "$SENTINEL" > .sdd/decisions.md
echo "$SENTINEL" > .sdd/patterns.md
echo "$SENTINEL" > .sdd/data-model.md
echo "$SENTINEL" > .sdd/stack.md
echo "$SENTINEL" > .sdd/principles.md
echo "$SENTINEL" > .sdd/features/001-fake-feature/spec.md
echo "$SENTINEL" > .sdd/bugs/001-fake-bug/spec.md
echo "$SENTINEL" > .sdd/refactors/001-fake-refactor/spec.md
echo "$SENTINEL" > .sdd/ideas/some-idea.md

user_files=(
  .sdd/INDEX.md
  .sdd/decisions.md
  .sdd/patterns.md
  .sdd/data-model.md
  .sdd/stack.md
  .sdd/principles.md
  .sdd/features/001-fake-feature/spec.md
  .sdd/bugs/001-fake-bug/spec.md
  .sdd/refactors/001-fake-refactor/spec.md
  .sdd/ideas/some-idea.md
)
before_hashes=$(mktemp) || { echo "FAIL: mktemp before_hashes failed"; exit 1; }
for f in "${user_files[@]}"; do
  shasum -a 256 "$f" >> "$before_hashes" 2>/dev/null || sha256sum "$f" >> "$before_hashes"
done

# Apply
out=$(bash "$SCRIPT" --apply --upstream="$FRAMEWORK_ROOT" 2>&1)
ec=$?

fails=()
[ "$ec" -eq 0 ] || fails+=("apply exit code: $ec")

# Verify ADD landed (so the apply path actually ran, not bailed)
[ -f .claude/hooks/pre-commit-test-first.sh ] \
  || fails+=("apply path didn't fire (ADD not landed)")

# Bit-for-bit: every user-data file's sha256 must match its pre-apply
# snapshot. Sentinel grep was insufficient (CR finding L62).
after_hashes=$(mktemp) || { echo "FAIL: mktemp after_hashes failed"; exit 1; }
for f in "${user_files[@]}"; do
  shasum -a 256 "$f" >> "$after_hashes" 2>/dev/null || sha256sum "$f" >> "$after_hashes"
done
if ! diff -q "$before_hashes" "$after_hashes" >/dev/null 2>&1; then
  fails+=("user-data hash diff detected — at least one file mutated:")
  while IFS= read -r line; do fails+=("  diff: $line"); done < <(diff "$before_hashes" "$after_hashes" || true)
fi
rm -f "$before_hashes" "$after_hashes"

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC7 — user-data files must survive --apply bit-for-bit"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Apply output:"
  printf '%s\n' "$out" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC7 — user-data files preserved across --apply"
exit 0
