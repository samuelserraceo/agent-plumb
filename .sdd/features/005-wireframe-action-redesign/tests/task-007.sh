#!/usr/bin/env bash
set -uo pipefail
F="templates/.sdd/skeletons/wireframe-non-ui.html"
[ -f "$F" ] || { echo "FAIL: $F missing" >&2; exit 1; }
head -1 "$F" | grep -q "^<!doctype html>" || { echo "FAIL: not well-formed HTML" >&2; exit 1; }
# Tighter check (CR cycle 1): require actual heading element wrapping
# the section name (same hardening as task-006).
for s in "Example interactions" "Flow" "Architecture" "New vs existing"; do
  if ! grep -qE "<h[1-6][^>]*>[^<]*$s[^<]*</h[1-6]>" "$F"; then
    echo "FAIL: section heading '$s' missing in $F" >&2; exit 1
  fi
done
echo "PASS: AC7 — non-UI skeleton exists with all 4 sections"
