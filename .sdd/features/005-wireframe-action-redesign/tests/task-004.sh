#!/usr/bin/env bash
set -uo pipefail
out=$(bash .sdd/scripts/lint-action-prose.sh templates/.sdd/actions/wireframe.md 2>&1)
ec=$?
if [ "$ec" -ne 0 ]; then
  echo "FAIL: lint-action-prose flagged wireframe.md: $out" >&2; exit 1
fi
echo "PASS: AC4 — lint-action-prose passes on rewritten wireframe.md"
