#!/usr/bin/env bash
# T305 — AC6 — /next honours parameters.automation.level via a
# 3-way decision tree (full / most / checkpoint) baked into the
# slash command's prose.
#
# /next is a slash command — its prose lives at
# .claude/commands/next.md and templates/.claude/commands/next.md.
# The decision tree describes WHEN to auto-advance vs WHEN to prompt:
#   - full       → auto-advance every AGENT-LED step with
#                  requires_user_approval: false
#   - most       → auto-advance non-destructive AGENT-LED steps;
#                  STILL prompt on destructive actions
#   - checkpoint → today's behaviour, prompt every AGENT-LED step
#
# This test asserts the decision tree is documented in both copies
# of the slash command so the agent reads canonical guidance every
# turn.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

fails=()

for CMD in "$FRAMEWORK_ROOT/.claude/commands/next.md" \
           "$FRAMEWORK_ROOT/templates/.claude/commands/next.md"; do
  if [ ! -f "$CMD" ]; then
    fails+=("missing slash-command file: $CMD")
    continue
  fi

  # Body must reference the config field that drives the behaviour.
  if ! grep -qE "parameters\.automation\.level|automation\.level" "$CMD"; then
    fails+=("$CMD missing reference to parameters.automation.level")
  fi

  # Must mention all 3 tier names.
  for tier in Full Most Checkpoint; do
    if ! grep -qiE "\b${tier}\b" "$CMD"; then
      fails+=("$CMD missing tier '${tier}' reference")
    fi
  done

  # Must describe BOTH auto-advance behaviour AND prompt-for-approval
  # behaviour so the agent knows what each tier does.
  if ! grep -qiE "auto-advance|auto[ -]?advancing" "$CMD"; then
    fails+=("$CMD missing 'auto-advance' behaviour description")
  fi
  if ! grep -qiE "prompt|ask|approve" "$CMD"; then
    fails+=("$CMD missing 'prompt/ask/approve' behaviour description")
  fi

  # Must reference AGENT-LED steps (the scope of automation).
  if ! grep -qE "AGENT-LED" "$CMD"; then
    fails+=("$CMD missing 'AGENT-LED' scope reference")
  fi

  # Must mention 'destructive' so the 'most' tier's safety gate is clear.
  if ! grep -qiE "destructive" "$CMD"; then
    fails+=("$CMD missing 'destructive' reference (needed for 'most' tier behaviour)")
  fi
done

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T305 — AC6 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T305 — AC6 /next ships 3-way decision tree (full/most/checkpoint, AGENT-LED, destructive safety)"
