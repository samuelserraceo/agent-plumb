#!/usr/bin/env bash
# T200 — AC1 — extensions/sdd-pi-extension/package.json contains a "pi"
# field with both "extensions:" (path to compiled JS) and "prompts:"
# (path to prompts directory).
#
# This is the manifest contract the host (pi.dev) reads to discover
# the extension entry point + prompt templates. Without it the package
# is invisible to pi after `pi install npm:sdd-pi-adapter`.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PKG="$FRAMEWORK_ROOT/extensions/sdd-pi-extension/package.json"

fails=()

if [ ! -f "$PKG" ]; then
  echo "FAIL: T200 — package.json missing at $PKG"
  exit 1
fi

# Parse + assert with python3 (jq isn't a framework dep).
python3 - "$PKG" <<'PY'
import json, sys
path = sys.argv[1]
errs = []
try:
    with open(path) as f:
        pkg = json.load(f)
except Exception as e:
    print(f"FAIL: T200 — package.json not parseable as JSON: {e}")
    sys.exit(1)

pi = pkg.get("pi")
if not isinstance(pi, dict):
    errs.append('"pi" field missing or not an object')
else:
    ext = pi.get("extensions")
    if not isinstance(ext, str) or not ext.strip():
        errs.append('"pi.extensions" missing or not a non-empty string')
    elif not ext.endswith(".js"):
        errs.append(f'"pi.extensions" should point to compiled JS (got: {ext!r})')

    prm = pi.get("prompts")
    if not isinstance(prm, str) or not prm.strip():
        errs.append('"pi.prompts" missing or not a non-empty string')

if errs:
    print("FAIL: T200 — AC1 package.json#pi shape violations:")
    for e in errs:
        print(f"  - {e}")
    sys.exit(1)

print("PASS: T200 — AC1 package.json#pi has extensions + prompts")
PY
