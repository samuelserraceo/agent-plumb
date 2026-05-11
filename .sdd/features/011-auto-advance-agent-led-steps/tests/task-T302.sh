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

fails=()

# AC7 claim covers BOTH live + template config — iterate over both.
for CFG in "$FRAMEWORK_ROOT/templates/.sdd/config.md" \
           "$FRAMEWORK_ROOT/.sdd/config.md"; do
  # Quote prefix to prevent glob-expansion if FRAMEWORK_ROOT contains
  # special chars (CR cycle-3 #3).
  REL="${CFG#"$FRAMEWORK_ROOT"/}"
  if [ ! -f "$CFG" ]; then
    fails+=("$REL missing")
    continue
  fi

  # --- A) parameters.automation: section exists (indented under parameters:) ---
  # Simple grep — `automation:` indented under `parameters:`. Avoids
  # regex catastrophic-backtracking on the 22KB config.md.
  if ! grep -qE "^[[:space:]]+automation:[[:space:]]*$" "$CFG"; then
    fails+=("$REL missing parameters.automation: section")
  fi

  # --- B) parameters.automation.level: checkpoint as documented default ---
  # Allow trailing comments (the line typically has explanatory comment).
  if ! grep -qE "^[[:space:]]+level:[[:space:]]*[\"']?checkpoint[\"']?([[:space:]]|#|$)" "$CFG"; then
    fails+=("$REL missing 'level: checkpoint' as documented default")
  fi

  # --- C) body has plain-English description of the 3 tiers ---
  # Should mention all three tier names within reasonable proximity
  # of an "automation" reference somewhere in the body.
  for tier in full most checkpoint; do
    if ! grep -qiE "\b${tier}\b" "$CFG"; then
      fails+=("$REL missing tier '${tier}' reference in body")
    fi
  done
  if ! grep -qiE "automation level|automation\.level|AGENT-LED" "$CFG"; then
    fails+=("$REL missing explanation of automation level / AGENT-LED context")
  fi
done

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T302 — AC7 groundwork violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T302 — .sdd/config.md (live + template) has parameters.automation.level=checkpoint + 3-tier explanation"
