#!/usr/bin/env bash
# T208 — AC9 — Wave-task subagent prompt shape.
#
# The prompt passed to each Agent call contains (a) the framework
# brain digest, (b) the active spec.md, AND (c) the single-task
# BUILD instruction (test → code → green discipline). Verified by
# inspecting --print-prompt output.
#
# AC9 is best-effort: Sam at SHIP eye-checks that the captured prompt
# would actually drive a fresh subagent to do the task in the right
# shape. This test just enforces the shape-level scaffolding.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/dispatch-wave.sh"

fails=()

WORK="$(mktemp -d -t sdd-t208.XXXXXX)"
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

prompt="$(bash "$SCRIPT" --print-prompt 1 "$WORK/spec.md" 2>&1)"
prompt_rc=$?
if [ "$prompt_rc" -ne 0 ]; then
  fails+=("--print-prompt exited $prompt_rc — invocation failed before shape assertions could run. out: $prompt")
fi

# (a) Framework brain reference. Either explicit "framework brain"
# string or a `.sdd/CLAUDE.md` / `framework brain digest` phrase.
if ! printf '%s' "$prompt" | grep -qiE "framework brain|\.sdd/CLAUDE\.md|framework instructions"; then
  fails+=("prompt missing framework brain reference")
fi

# (b) Active spec.md injection point.
if ! printf '%s' "$prompt" | grep -qiE "active spec|spec\.md"; then
  fails+=("prompt missing active spec.md reference")
fi

# (c) Single-task BUILD instruction (test → code → green).
if ! printf '%s' "$prompt" | grep -qiE "BUILD-task|test.+code.+green|atomic commit"; then
  fails+=("prompt missing single-task BUILD instruction")
fi

# Reasonable lower bound — a prompt this terse is likely a placeholder
# not a real subagent driver. Real prompt at AC9 SHIP eye-check.
char_count="$(printf '%s' "$prompt" | wc -c | tr -d ' ')"
if [ "$char_count" -lt 100 ]; then
  fails+=("prompt suspiciously short ($char_count chars) — probably a stub, not a real subagent prompt")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T208 — AC9 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T208 — AC9 subagent prompt contains framework brain ref + active spec.md ref + single-task BUILD instruction"
