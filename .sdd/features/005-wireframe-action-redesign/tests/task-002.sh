#!/usr/bin/env bash
set -uo pipefail
F="templates/.sdd/actions/wireframe.md"
grep -q "UI feature" "$F" || { echo "FAIL: 'UI feature' missing from $F" >&2; exit 1; }
grep -q "non-UI feature" "$F" || { echo "FAIL: 'non-UI feature' missing from $F" >&2; exit 1; }
echo "PASS: AC2 — UI vs non-UI branching prose lands"
