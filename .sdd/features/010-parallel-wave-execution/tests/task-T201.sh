#!/usr/bin/env bash
# T201 — AC2 — `.sdd/scripts/dispatch-wave.sh` exists with the correct
# shape: shebang + executable bit + accepts <wave-N> <spec-path> args +
# emits structured JSON on stdout.
#
# v1 ships the script as a thin shape-only stub. Real subagent dispatch
# behaviours (pre-commit hooks fire, partial-wave report, trust markers,
# multi-model config, prompt shape) come in T204-T208 via incremental
# additions to the same file.
#
# Folded edge cases from §15 ec-pick:
#   #1 (concurrent wave dispatch) — script accepts a `--lock` mode that
#      refuses if another wave is in flight (lockfile path is well-known).
#   #4 (empty wave — all tasks already GREEN) — script handles a wave
#      number that resolves to zero open tasks; emits a no-op JSON
#      result instead of erroring.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/dispatch-wave.sh"

fails=()

# --- A) Shape: file exists at the framework path ----------------------
if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: T201 — dispatch-wave.sh missing at $SCRIPT"
  exit 1
fi

# --- B) Shape: shebang line is bash ----------------------------------
first_line="$(head -n 1 "$SCRIPT")"
if ! printf '%s' "$first_line" | grep -qE '^#!.*bash'; then
  fails+=("first line is not a bash shebang: '$first_line'")
fi

# --- C) Shape: executable bit ----------------------------------------
if [ ! -x "$SCRIPT" ]; then
  fails+=("dispatch-wave.sh is not executable (chmod +x)")
fi

# --- D) Args: accepts <wave-N> <spec-path> ----------------------------
# Build a fixture spec.md the script can chew on. Wave 1 has 2 tasks;
# wave 2 has 1. Sequential tasks have no marker.
WORK="$(mktemp -d -t sdd-t201.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/spec.md" <<'SPEC'
---
playbook: feature
---

# fixture

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T200 [WAVE: 1]: scaffold endpoint A
- [ ] T201 [WAVE: 1]: scaffold endpoint B
- [ ] T202: integration test (sequential, no wave marker)
- [ ] T203 [WAVE: 2]: docs sweep

## PHASE: BUILD

### action: build-task

(driven by §plan-decompose)

## PHASE: SHIP
SPEC

# Invoke with positional args: wave-N spec-path.
out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$SCRIPT" 1 "$WORK/spec.md" 2>/dev/null)"
rc=$?

if [ "$rc" -ne 0 ]; then
  fails+=("dispatch-wave.sh exited $rc on wave=1 fixture (expected 0 for shape probe)")
fi

# --- E) Output: stdout is valid JSON --------------------------------
if [ -n "$out" ]; then
  if ! printf '%s' "$out" | python3 -c '
import json, sys
try:
    obj = json.loads(sys.stdin.read())
except Exception as e:
    print(f"INVALID_JSON: {e}", file=sys.stderr)
    sys.exit(2)
# Require at least the "wave" + "tasks" keys.
if "wave" not in obj:
    print("missing key: wave", file=sys.stderr); sys.exit(3)
if "tasks" not in obj:
    print("missing key: tasks", file=sys.stderr); sys.exit(4)
# Wave should echo the requested number.
if obj.get("wave") != 1:
    print(f"wave != 1 (got {obj.get(\"wave\")!r})", file=sys.stderr); sys.exit(5)
# Tasks should be a list (may be empty if shape-only stub).
if not isinstance(obj.get("tasks"), list):
    print(f"tasks not a list (got {type(obj.get(\"tasks\")).__name__})", file=sys.stderr); sys.exit(6)
' >/dev/null 2>&1
  then
    fails+=("dispatch-wave.sh stdout not valid JSON or missing required keys (out: $out)")
  fi
else
  fails+=("dispatch-wave.sh produced no stdout on shape probe")
fi

# --- F) Folded EC #4 — empty wave handled cleanly --------------------
# Wave 99 has no tasks in the fixture. Script should exit 0 with a JSON
# result whose tasks list is empty, not error out.
empty_out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$SCRIPT" 99 "$WORK/spec.md" 2>/dev/null)"
empty_rc=$?
if [ "$empty_rc" -ne 0 ]; then
  fails+=("empty wave (wave=99 with 0 tasks) exited $empty_rc — expected 0 with no-op JSON. out: $empty_out")
fi
if [ -n "$empty_out" ]; then
  if ! printf '%s' "$empty_out" | python3 -c '
import json, sys
try: obj = json.loads(sys.stdin.read())
except Exception: sys.exit(2)
sys.exit(0 if obj.get("tasks") == [] else 7)
' >/dev/null 2>&1
  then
    fails+=("empty wave didn't return empty tasks list. out: $empty_out")
  fi
fi

# --- G) Bad args: non-positive wave-N rejected ------------------------
# Folded EC #7 from §15. Script should refuse [WAVE: 0] / [WAVE: foo]
# style invocations.
for bad in 0 foo -1; do
  bad_out="$(CLAUDE_PROJECT_DIR="$FRAMEWORK_ROOT" bash "$SCRIPT" "$bad" "$WORK/spec.md" 2>&1)"
  bad_rc=$?
  if [ "$bad_rc" -eq 0 ]; then
    fails+=("dispatch-wave.sh accepted bad wave-N='$bad' (expected non-zero exit). out: $bad_out")
  fi
done

# --- Report -----------------------------------------------------------
if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T201 — AC2 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T201 — AC2 dispatch-wave.sh exists with shebang + exec bit + structured JSON + empty-wave no-op + rejects bad wave-N"
