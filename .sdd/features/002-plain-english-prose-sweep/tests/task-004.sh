#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC4 — lint script is executable
set -euo pipefail
LINT=".sdd/scripts/lint-action-prose.sh"
[ -x "$LINT" ] || { echo "FAIL: $LINT not executable" >&2; exit 1; }
echo "PASS: AC4 — lint is executable at $LINT"
