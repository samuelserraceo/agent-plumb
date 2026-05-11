#!/usr/bin/env bash
# T207 — AC8 — Multi-model wave config respected.
#
# When `parameters.wave.worker_model` is set in .sdd/config.md (or the
# WAVE_WORKER_MODEL env var as a per-invocation override), dispatch-
# wave.sh emits the chosen model in its JSON output. When unset, the
# `worker_model` field is null / empty (defaults to orchestrator's
# model at real-dispatch time).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/dispatch-wave.sh"

fails=()

WORK="$(mktemp -d -t sdd-t207.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/spec.md" <<'SPEC'
---
playbook: feature
---
# fixture

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T200 [WAVE: 1]: scaffold A

## PHASE: BUILD
SPEC

# --- A) With WAVE_WORKER_MODEL set ----------------------------------
out_set="$(WAVE_WORKER_MODEL="claude-haiku-4-x" bash "$SCRIPT" 1 "$WORK/spec.md" 2>/dev/null)"
parsed="$(printf '%s' "$out_set" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception: sys.exit(2)
wm = obj.get("worker_model")
if wm != "claude-haiku-4-x":
    print("worker_model != claude-haiku-4-x, got " + repr(wm)); sys.exit(3)
print("OK")
' 2>&1)"
if ! printf '%s' "$parsed" | grep -q '^OK$'; then
  fails+=("WAVE_WORKER_MODEL set but not echoed: $parsed (raw: $out_set)")
fi

# --- B) Without WAVE_WORKER_MODEL ------------------------------------
out_unset="$(unset WAVE_WORKER_MODEL; bash "$SCRIPT" 1 "$WORK/spec.md" 2>/dev/null)"
parsed_unset="$(printf '%s' "$out_unset" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception: sys.exit(2)
wm = obj.get("worker_model")
# Default: None or empty string both signal "inherit orchestrator".
if wm not in (None, ""):
    print("expected null/empty worker_model on unset, got " + repr(wm)); sys.exit(3)
print("OK")
' 2>&1)"
if ! printf '%s' "$parsed_unset" | grep -q '^OK$'; then
  fails+=("WAVE_WORKER_MODEL unset but field not null/empty: $parsed_unset (raw: $out_unset)")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T207 — AC8 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T207 — AC8 dispatch-wave.sh respects WAVE_WORKER_MODEL config (echo when set, null when unset)"
