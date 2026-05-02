#!/usr/bin/env bash
set -uo pipefail
F="templates/.sdd/skeletons/wireframe-ui.html"
[ -f "$F" ] || { echo "FAIL: $F missing" >&2; exit 1; }
head -1 "$F" | grep -q "^<!doctype html>" || { echo "FAIL: not well-formed HTML" >&2; exit 1; }
for s in "Screens" "Design tokens" "Component states" "Interaction details"; do
  grep -q ">$s</" "$F" || grep -q "$s" "$F" || { echo "FAIL: section '$s' missing" >&2; exit 1; }
done
echo "PASS: AC6 — UI skeleton exists with all 4 sections"
