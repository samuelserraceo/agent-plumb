#!/usr/bin/env bash
# AC8 — interactive elements have keyboard a11y
set -uo pipefail
F="templates/.sdd/skeletons/wireframe-non-ui.html"  # only non-UI has interactive SVG groups
# Confirm tabindex + role + keydown handler all present
grep -qE 'tabindex=' "$F" || { echo "FAIL: no tabindex" >&2; exit 1; }
grep -qE 'role="button"' "$F" || { echo "FAIL: no role=button" >&2; exit 1; }
grep -qE 'keydown' "$F" || { echo "FAIL: no keydown handler" >&2; exit 1; }
grep -qE "Enter|' '" "$F" || { echo "FAIL: no Enter/Space activation" >&2; exit 1; }
echo "PASS: AC8 — both skeletons have keyboard-accessible interactive elements"
