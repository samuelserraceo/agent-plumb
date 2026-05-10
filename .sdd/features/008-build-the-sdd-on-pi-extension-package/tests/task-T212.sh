#!/usr/bin/env bash
# T212 — JS extension entry exists, is loadable, registers the three
# lifecycle hooks (context / session_start) + the instant command
# (sdd-status) that AC3/AC4/AC7 promise.
#
# Closes the partial-e2e gap discovered post-cycle-2: T200-T211 verified
# mechanical SHAPE (manifest declares X, scripts emit Y) but never
# verified that pi.dev RUNTIME loads the extension and fires hooks.
# Without dist/sdd-pi.js, the bash scripts in extensions/sdd-pi-extension/
# scripts/ are never wired to pi's lifecycle, so the load-bearing
# automatic state injection (AC3) and HRN-01 install (AC4) silently
# no-op. /sdd-status (AC7) falls back to prompt-template mode = LLM
# round-trip = AC7 violation.
#
# What we assert:
#   A) The path declared in package.json#pi.extensions exists on disk.
#   B) The file is loadable as a CommonJS module without throwing.
#   C) The default export is a function.
#   D) Calling that function with a mock pi API registers handlers
#      via pi.on("context", ...) and pi.on("session_start", ...) and
#      pi.registerCommand("sdd-status", ...).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
EXT_ROOT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension"
PKG_JSON="$EXT_ROOT/package.json"

fails=()

# --- A) Path declared in manifest exists ---------------------------
ext_path="$(python3 -c "
import json, sys
with open('$PKG_JSON') as f:
    pkg = json.load(f)
print(pkg.get('pi', {}).get('extensions', ''))
" 2>/dev/null)"

if [ -z "$ext_path" ]; then
  fails+=("manifest pi.extensions is empty — AC1 path unresolvable")
elif [ ! -f "$EXT_ROOT/$ext_path" ]; then
  fails+=("manifest pi.extensions = '$ext_path' but $EXT_ROOT/$ext_path does not exist")
fi

# --- B/C/D) Loadable + registers required hooks --------------------
if [ -f "$EXT_ROOT/$ext_path" ]; then
  if ! command -v node >/dev/null 2>&1; then
    fails+=("node not on PATH — cannot verify the JS extension loads")
  else
    probe="$(mktemp -t sdd-t212.XXXXXX).js"
    cat > "$probe" <<'PROBE'
// Mock pi ExtensionAPI surface and assert the extension registers
// the three required handlers when invoked.
const path = require("path");
const extPath = process.argv[2];

const registered = { context: false, session_start: false, sdd_status_cmd: false };

const pi = {
  on(event, handler) {
    if (event === "context") registered.context = true;
    if (event === "session_start") registered.session_start = true;
  },
  registerCommand(name, def) {
    if (name === "sdd-status") registered.sdd_status_cmd = true;
  },
  ui: {
    notify() {},
    setEditorText() {},
  },
};

let mod;
try {
  mod = require(path.resolve(extPath));
} catch (e) {
  console.error("LOAD_ERROR:", e.message);
  process.exit(2);
}

const factory = mod && (mod.default || mod);
if (typeof factory !== "function") {
  console.error("NOT_A_FUNCTION:", typeof factory);
  process.exit(3);
}

try {
  factory(pi);
} catch (e) {
  console.error("INVOKE_ERROR:", e.message);
  process.exit(4);
}

const missing = Object.entries(registered)
  .filter(([_, v]) => !v)
  .map(([k]) => k);

if (missing.length) {
  console.error("MISSING:", missing.join(","));
  process.exit(5);
}

console.log("OK");
PROBE
    out="$(node "$probe" "$EXT_ROOT/$ext_path" 2>&1)"
    rc=$?
    rm -f "$probe"
    case "$rc" in
      0)  : ;;
      2)  fails+=("dist/sdd-pi.js failed to load: $out") ;;
      3)  fails+=("dist/sdd-pi.js default export is not a function: $out") ;;
      4)  fails+=("dist/sdd-pi.js threw when invoked with pi API: $out") ;;
      5)  fails+=("dist/sdd-pi.js missing required handler registrations: $out") ;;
      *)  fails+=("dist/sdd-pi.js probe exited unexpectedly (rc=$rc): $out") ;;
    esac
  fi
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T212 — JS extension wiring violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T212 — dist/sdd-pi.js loads, registers context+session_start hooks + sdd-status command"
