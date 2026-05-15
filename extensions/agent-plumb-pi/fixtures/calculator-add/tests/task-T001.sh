#!/usr/bin/env bash
# T001 — calculator-add fixture: lib/add.js must export (a, b) => a + b.
# Used by AC9 / T208 to prove a model can follow SDD's atomic-step
# rule across model families on pi.dev.

set -uo pipefail

# Anchor paths to the script's own location so the test works regardless
# of where the operator runs it from (CR finding #7).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ADD="$ROOT_DIR/lib/add.js"

if [ ! -f "$ADD" ]; then
  echo "FAIL: T001 — $ADD missing"
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "FAIL: T001 — node not on PATH; install Node.js to run the discipline fixture"
  exit 1
fi

out="$(node -e 'const add = require(process.argv[1]); console.log(add(2, 3))' "$ADD" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: T001 — node failed loading $ADD: $out"
  exit 1
fi

if [ "$out" != "5" ]; then
  echo "FAIL: T001 — add(2, 3) returned '$out', expected '5'"
  exit 1
fi

echo "PASS: T001 — add(a, b) returns a + b"
