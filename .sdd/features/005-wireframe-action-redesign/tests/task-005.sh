#!/usr/bin/env bash
set -uo pipefail
out=$(bash .sdd/scripts/lint-no-theatre.sh templates/.sdd/actions/wireframe.md 2>&1)
ec=$?
if [ "$ec" -ne 0 ]; then
  echo "FAIL: lint-no-theatre flagged wireframe.md: $out" >&2; exit 1
fi
echo "PASS: AC5 — lint-no-theatre passes on rewritten wireframe.md"
