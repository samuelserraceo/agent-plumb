#!/usr/bin/env bash
set -uo pipefail
F="templates/.sdd/actions/wireframe.md"
if grep -qE '\bSKIPPABLE\b' "$F"; then
  echo "FAIL: SKIPPABLE tag still in $F" >&2; exit 1
fi
echo "PASS: AC1 — SKIPPABLE tag removed from wireframe.md"
