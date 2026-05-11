#!/usr/bin/env bash
# T306 — AC7 — .sdd/config.md (live + template) enumerates the
# destructive-actions list under parameters.automation.destructive_actions
# (or sibling field name).
#
# The 6 canonical destructive action slugs (per F011 §11 + decision tree
# in /next prose):
#   - mark-shipped         — writes the .shipped marker
#   - manifest-repin       — '[SDD] manifest: repin' commits
#   - --delete-branch      — gh pr merge --delete-branch
#   - decisions.md-append  — append-only audit-log writes
#   - .shipped-marker      — direct .shipped file writes
#   - repin                — pre-commit-stage-verified.sh repin commits
#
# The 'most' tier reads this list to decide which actions still prompt
# even when their per-action requires_user_approval would auto-advance.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

fails=()

for CFG in "$FRAMEWORK_ROOT/.sdd/config.md" \
           "$FRAMEWORK_ROOT/templates/.sdd/config.md"; do
  if [ ! -f "$CFG" ]; then
    fails+=("missing config file: $CFG")
    continue
  fi

  # Must have a destructive_actions field under parameters.automation.
  if ! grep -qE "^[[:space:]]+destructive_actions:" "$CFG"; then
    fails+=("$CFG missing 'destructive_actions:' field under parameters.automation")
  fi

  # Each of the 6 canonical slugs must appear in the file. Use -e so
  # leading '-' / '.' aren't parsed as grep options.
  for slug in mark-shipped manifest-repin -delete-branch decisions.md-append .shipped-marker repin; do
    if ! grep -qF -e "$slug" "$CFG"; then
      fails+=("$CFG missing destructive-action slug '$slug'")
    fi
  done
done

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T306 — AC7 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T306 — AC7 destructive-actions list enumerated in config.md (live + template, 6 slugs)"
