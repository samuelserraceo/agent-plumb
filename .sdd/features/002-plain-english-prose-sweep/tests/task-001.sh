#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC1 — inventory pass
# Test: lint-action-prose.sh --inventory lists ≥10 qualifying USER-LED/AGENT-LED files

set -euo pipefail

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

# Count qualifying files in output (heuristic: lines containing the path)
count=$(echo "$out" | grep -c "templates/.sdd/actions/" || true)

if [ "$count" -lt 10 ]; then
  echo "FAIL: expected ≥10 qualifying USER-LED/AGENT-LED files, got $count" >&2
  echo "Inventory output was:" >&2
  echo "$out" >&2
  exit 1
fi

echo "PASS: inventory found $count qualifying files (≥10)"
