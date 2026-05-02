#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC8 — CI hook
# Test: test/run-framework-test.sh wires lint-action-prose.sh

set -euo pipefail

if ! grep -q "lint-action-prose.sh" test/run-framework-test.sh; then
  echo "FAIL: test/run-framework-test.sh doesn't reference lint-action-prose.sh" >&2
  exit 1
fi

# Also assert the test runs the lint AND fails-on-violation (the call site
# must be wired, not just commented)
if ! grep -E "bash.*lint-action-prose\.sh" test/run-framework-test.sh > /dev/null; then
  echo "FAIL: test/run-framework-test.sh references but doesn't INVOKE lint-action-prose.sh" >&2
  exit 1
fi

echo "PASS: AC8 — lint-action-prose.sh wired into framework CI"
