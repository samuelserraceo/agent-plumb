#!/usr/bin/env bash
# T302 — config.md (live + template) ships a documented
# parameters.automation: section. Groundwork for AC7
# (destructive-actions list) + supports AC4/AC5 (setup wizard
# + /sdd-config tier change need the field to exist in the
# shipped config template).
#
# Checks:
#   A) templates/.sdd/config.md frontmatter has parameters.automation.level
#   B) templates/.sdd/config.md frontmatter has parameters.automation.level
#      explicitly set to "checkpoint" (the documented default)
#   C) templates/.sdd/config.md body explains the 3 tiers with
#      plain-English descriptions

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TEMPLATE="$FRAMEWORK_ROOT/templates/.sdd/config.md"

fails=()

if [ ! -f "$TEMPLATE" ]; then
  fails+=("templates/.sdd/config.md missing")
fi

# --- A) frontmatter has parameters.automation: section ---
# Simple grep — `automation:` indented under `parameters:`. Avoids
# regex catastrophic-backtracking on the 22KB config.md.
if ! grep -qE "^[[:space:]]+automation:[[:space:]]*$" "$TEMPLATE"; then
  fails+=("templates/.sdd/config.md frontmatter missing parameters.automation: section")
fi

# --- B) parameters.automation.level: checkpoint as documented default ---
if ! grep -qE "^\s*level:\s*[\"']?checkpoint[\"']?\s*$" "$TEMPLATE"; then
  fails+=("templates/.sdd/config.md missing 'level: checkpoint' as documented default")
fi

# --- C) body has plain-English description of the 3 tiers ---
# Should mention all three tier names within reasonable proximity
# of an "automation" reference somewhere in the body.
for tier in full most checkpoint; do
  if ! grep -qiE "\b${tier}\b" "$TEMPLATE"; then
    fails+=("templates/.sdd/config.md missing tier '${tier}' reference in body")
  fi
done
if ! grep -qiE "automation level|automation\.level|AGENT-LED" "$TEMPLATE"; then
  fails+=("templates/.sdd/config.md missing explanation of automation level / AGENT-LED context")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T302 — AC7 groundwork violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T302 — templates/.sdd/config.md has parameters.automation.level=checkpoint + 3-tier explanation"
