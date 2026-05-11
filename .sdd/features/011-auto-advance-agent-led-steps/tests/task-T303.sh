#!/usr/bin/env bash
# T303 — AC4 — /sdd-setup wizard contains an "Automation level"
# question with Full / Most / Checkpoint options + plain-English
# descriptions; the wizard records the user's choice to
# parameters.automation.level in config.md.
#
# Implementation lives as a new setup brick at
# templates/.sdd/setup/<NNN>-automation-level.md following the
# existing brick frontmatter shape.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

fails=()

# Find any setup brick whose body mentions Automation level.
BRICK_DIR="$FRAMEWORK_ROOT/templates/.sdd/setup"
BRICK=""
for f in "$BRICK_DIR"/*.md; do
  if grep -qiE "automation[[:space:]]level|automation\.level" "$f"; then
    BRICK="$f"
    break
  fi
done

if [ -z "$BRICK" ]; then
  fails+=("no setup brick in $BRICK_DIR/*.md mentions automation level")
else
  # Check brick frontmatter has expected shape.
  if ! grep -qE "^records_in:" "$BRICK"; then
    fails+=("setup brick $BRICK missing 'records_in:' frontmatter (where the answer is written)")
  fi
  if ! grep -qE "^when:" "$BRICK"; then
    fails+=("setup brick $BRICK missing 'when:' frontmatter")
  fi
  # Body should mention all 3 tiers.
  for tier in Full Most Checkpoint; do
    if ! grep -qiE "\b${tier}\b" "$BRICK"; then
      fails+=("setup brick $BRICK body missing tier '${tier}' reference")
    fi
  done
  # Body should reference the canonical config field.
  if ! grep -qE "parameters\.automation\.level|automation\.level|parameters\.automation\b" "$BRICK"; then
    fails+=("setup brick $BRICK body missing reference to the config field (parameters.automation.level)")
  fi
fi

# README index check removed — README is format-explanation, not a
# brick list. New bricks are discovered by the wizard via directory
# walk in numbered order; no README update required.

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T303 — AC4 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T303 — AC4 setup wizard ships automation-level brick (3 tiers + records_in config)"
