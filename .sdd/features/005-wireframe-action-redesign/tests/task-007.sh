#!/usr/bin/env bash
set -uo pipefail
F="templates/.sdd/skeletons/wireframe-non-ui.html"
[ -f "$F" ] || { echo "FAIL: $F missing" >&2; exit 1; }
head -1 "$F" | grep -q "^<!doctype html>" || { echo "FAIL: not well-formed HTML" >&2; exit 1; }
for s in "Example interactions" "Flow" "Architecture" "New vs existing"; do
  grep -q "$s" "$F" || { echo "FAIL: section '$s' missing" >&2; exit 1; }
done
echo "PASS: AC7 — non-UI skeleton exists with all 4 sections"
