#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC1 — inventory pass
# Test: lint-action-prose.sh --inventory lists ≥10 qualifying USER-LED/AGENT-LED files

# CR cycle 2: drop -e so the `if [ "$ec" -ne 0 ]` branch can run.
# `-uo pipefail` keeps us strict on undefined vars + pipe failures.
set -uo pipefail

LINT=".sdd/scripts/lint-action-prose.sh"

if [ ! -x "$LINT" ]; then
  echo "RED: $LINT not found or not executable" >&2
  exit 1
fi

out=$(bash "$LINT" --inventory 2>&1)
ec=$?

if [ "$ec" -ne 0 ]; then
  echo "FAIL: lint --inventory exited $ec; output: $out" >&2
  exit 1
fi

# Count qualifying entry lines only — anchored regex that matches each
# per-file inventory line shape `[tag=USER-LED] qualifying` or
# `[tag=AGENT-LED] qualifying`. Excludes the `[inventory] N qualifying / M total`
# summary line (CR cycle 2 catch).
count=$(echo "$out" | grep -cE '\[tag=(USER-LED|AGENT-LED)\][[:space:]]+qualifying$' || true)

if [ "$count" -lt 10 ]; then
  echo "FAIL: expected ≥10 qualifying USER-LED/AGENT-LED files, got $count" >&2
  echo "Inventory output was:" >&2
  echo "$out" >&2
  exit 1
fi

echo "PASS: inventory found $count qualifying files (≥10)"
