#!/usr/bin/env bash
# AC8 — CI gate wired
set -uo pipefail
if ! grep -q "T141" test/run-framework-test.sh; then
  echo "FAIL: T141 not in test/run-framework-test.sh" >&2; exit 1
fi
if ! grep -qE "lint-no-theatre.sh" test/run-framework-test.sh; then
  echo "FAIL: lint-no-theatre.sh not invoked" >&2; exit 1
fi
echo "PASS: AC8 — T141 wired into framework CI"
