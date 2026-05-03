#!/usr/bin/env bash
set -uo pipefail
F="templates/.sdd/skeletons/wireframe-ui.html"
[ -f "$F" ] || { echo "FAIL: $F missing" >&2; exit 1; }
head -1 "$F" | grep -q "^<!doctype html>" || { echo "FAIL: not well-formed HTML" >&2; exit 1; }
# Tighter check (CR cycle 1): require an actual heading element wrapping
# the section name. Matches `<h1>...$s...</h1>` through `<h6>...$s...</h6>`
# (Tailwind classes allowed inside the opening tag). Previous fallback
# would pass on incidental text occurrences elsewhere in the file.
for s in "Screens" "Design tokens" "Component states" "Interaction details"; do
  if ! grep -qE "<h[1-6][^>]*>[^<]*$s[^<]*</h[1-6]>" "$F"; then
    echo "FAIL: section heading '$s' missing in $F" >&2; exit 1
  fi
done
echo "PASS: AC6 — UI skeleton exists with all 4 sections"
