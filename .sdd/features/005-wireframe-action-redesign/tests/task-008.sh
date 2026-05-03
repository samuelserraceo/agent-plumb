#!/usr/bin/env bash
# AC8 — non-UI skeleton's interactive SVG groups have keyboard a11y.
# (UI skeleton's controls are native <button>/<input> + <label>, which
# get keyboard a11y from the user agent — no JS handler needed there.)
set -uo pipefail
F="templates/.sdd/skeletons/wireframe-non-ui.html"
grep -qE 'tabindex=' "$F" || { echo "FAIL: no tabindex on $F" >&2; exit 1; }
grep -qE 'role="button"' "$F" || { echo "FAIL: no role=button on $F" >&2; exit 1; }
grep -qE 'keydown' "$F" || { echo "FAIL: no keydown handler on $F" >&2; exit 1; }
# CR cycle 1: require BOTH Enter AND Space (both keyboard activations are
# expected per WAI-ARIA button pattern). Single `Enter|' '` would pass
# even if only one was wired.
grep -qE "'Enter'" "$F" || { echo "FAIL: no Enter-key activation" >&2; exit 1; }
grep -qE "' '|'Spacebar'" "$F" || { echo "FAIL: no Space-key activation" >&2; exit 1; }
echo "PASS: AC8 — non-UI skeleton has keyboard-accessible SVG interactive groups (tabindex + role + keydown + Enter + Space)"
