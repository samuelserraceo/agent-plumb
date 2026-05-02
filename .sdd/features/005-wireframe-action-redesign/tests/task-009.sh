#!/usr/bin/env bash
# AC9 — existing shipped specs don't break the lints
set -uo pipefail
fails=0
for spec in .sdd/features/00{1,2,3,4}-*/spec.md; do
  out=$(bash .sdd/scripts/lint-no-theatre.sh "$spec" 2>&1)
  ec=$?
  if [ "$ec" -ne 0 ] && [ "$ec" -ne 1 ]; then
    # CR cycle 1: include the captured `out` so the crash diagnostic
    # is visible (not just the exit code).
    echo "FAIL: lint-no-theatre crashed on $spec (ec=$ec): $out" >&2
    fails=$((fails + 1))
  fi
done
if [ "$fails" -eq 0 ]; then
  echo "PASS: AC9 — lints don't crash on shipped specs"
else
  exit 1
fi
