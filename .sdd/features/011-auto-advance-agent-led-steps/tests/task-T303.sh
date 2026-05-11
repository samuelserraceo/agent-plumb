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
  # Extract frontmatter (between leading '---' and the second '---').
  # awk pattern: print between first and second '---' line.
  FRONTMATTER=$(awk '/^---$/{c++; next} c==1 {print}' "$BRICK")
  BODY=$(awk '/^---$/{c++; next} c==2 {print}' "$BRICK")

  # Frontmatter must declare records_in.
  if ! printf '%s\n' "$FRONTMATTER" | grep -qE "^records_in:"; then
    fails+=("setup brick $BRICK frontmatter missing 'records_in:'")
  fi
  # CR cycle-3 #4 + cycle-4 tightening: records_at (or records_in) must
  # point at the canonical config field. The 008-automation-level brick
  # splits the value across `records_in: '.sdd/config.md'` + `records_at:
  # 'parameters.automation.level'` — accept either key as the carrier,
  # but require an EXPLICIT key-scoped value match (not a free-floating
  # mention anywhere in frontmatter).
  has_target=0
  if printf '%s\n' "$FRONTMATTER" | grep -qE "^records_at:[[:space:]]*['\"]?parameters\.automation\.level['\"]?[[:space:]]*$"; then
    has_target=1
  fi
  if printf '%s\n' "$FRONTMATTER" | grep -qE "^records_in:[[:space:]]*['\"]?parameters\.automation\.level['\"]?[[:space:]]*$"; then
    has_target=1
  fi
  if [ "$has_target" -eq 0 ]; then
    fails+=("setup brick $BRICK frontmatter: records_at / records_in does not point at 'parameters.automation.level' as the key-scoped value")
  fi
  # Frontmatter must declare 'when' (start vs sub-stage).
  if ! printf '%s\n' "$FRONTMATTER" | grep -qE "^when:"; then
    fails+=("setup brick $BRICK frontmatter missing 'when:'")
  fi
  # Body must mention all 3 tiers (scoped to body, not frontmatter).
  for tier in Full Most Checkpoint; do
    if ! printf '%s\n' "$BODY" | grep -qiE "\b${tier}\b"; then
      fails+=("setup brick $BRICK body missing tier '${tier}' reference")
    fi
  done
  # Body must reference the canonical config field somewhere as well.
  if ! printf '%s\n' "$BODY" | grep -qE "parameters\.automation\.level|automation\.level|parameters\.automation\b"; then
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
