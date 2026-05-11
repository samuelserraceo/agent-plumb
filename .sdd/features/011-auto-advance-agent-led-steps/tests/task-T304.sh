#!/usr/bin/env bash
# T304 — AC5 — /sdd-config supports `automation <tier>` subcommand
# to change parameters.automation.level post-setup.
#
# /sdd-config is a slash command — its prose lives at
# .claude/commands/sdd-config.md (and templates/.claude/commands/
# sdd-config.md for new projects). The command body describes the
# `automation <tier>` subcommand: parses Full|Most|Checkpoint,
# updates parameters.automation.level in .sdd/config.md, confirms
# back to the user.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

fails=()

for CMD in "$FRAMEWORK_ROOT/.claude/commands/sdd-config.md" \
           "$FRAMEWORK_ROOT/templates/.claude/commands/sdd-config.md"; do
  if [ ! -f "$CMD" ]; then
    fails+=("missing slash-command file: $CMD")
    continue
  fi

  # Body must describe the `automation` subcommand.
  if ! grep -qiE "automation[[:space:]]+(<tier>|full|most|checkpoint|level)" "$CMD"; then
    fails+=("$CMD body missing 'automation' subcommand description")
  fi

  # Must mention all 3 tier names.
  for tier in Full Most Checkpoint; do
    if ! grep -qiE "\b${tier}\b" "$CMD"; then
      fails+=("$CMD missing tier '${tier}' reference")
    fi
  done

  # Must reference the config field being updated.
  if ! grep -qE "parameters\.automation\.level|automation\.level" "$CMD"; then
    fails+=("$CMD missing reference to parameters.automation.level")
  fi
done

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T304 — AC5 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T304 — AC5 /sdd-config supports automation <tier> subcommand (live + template)"
