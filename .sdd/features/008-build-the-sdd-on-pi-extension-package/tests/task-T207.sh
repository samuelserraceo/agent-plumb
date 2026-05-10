#!/usr/bin/env bash
# T207 — AC8 — /sdd-ship invokes the ship flow — pushes the branch, opens
# or updates the PR, polls CI per the existing scripts.
#
# Same delegation pattern as T204/T205/T206: the pi extension owns the
# prompt template; the framework owns the actions + scripts. T207 verifies
# BOTH layers — the contract (prompt body delegates to next-action.sh,
# mentions the AC8 verbatim push/PR/CI behaviours, and names mark-shipped
# as the terminal action) AND the end-to-end shape that next-action.sh
# returns when walked against a fixture spec.md sitting in PHASE: SHIP
# (the actual action sequence /sdd-ship downstream relies on to advance
# one ship-phase action per /sdd-next call).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROMPT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension/prompts/sdd-ship.md"
TPL="$FRAMEWORK_ROOT/templates/.sdd"

if [ ! -f "$PROMPT" ]; then
  echo "FAIL: T207 — prompts/sdd-ship.md missing at $PROMPT"
  exit 1
fi
if [ ! -d "$TPL" ]; then
  echo "FAIL: T207 — framework templates dir missing at $TPL"
  exit 1
fi

fails=()

# --- Contract: prompt body delegates to BOTH resolve-active.sh AND
# next-action.sh — same pattern T205 enforces on sdd-next. resolve-active
# first (to learn the active spec path), then next-action.sh against that
# spec to surface the current SHIP-phase action. Without resolve-active
# the prompt has no way to know which spec.md to walk; without
# next-action.sh each ship-phase action can't land as its own commit. ---
if ! grep -qF 'bash .sdd/scripts/resolve-active.sh' "$PROMPT"; then
  fails+=("prompt missing invocation: bash .sdd/scripts/resolve-active.sh")
fi
if ! grep -qF 'bash .sdd/scripts/next-action.sh' "$PROMPT"; then
  fails+=("prompt missing invocation: bash .sdd/scripts/next-action.sh")
fi

# --- Contract: prompt teaches AC8's verbatim push/PR/CI behaviours so the
# downstream agent knows what the ship flow actually does. Without each
# of these terms in the prompt body, AC8's claim travels into the model
# context without any guidance attached. ---
# Token-level matching — `PR`/`CI` could otherwise be embedded in
# unrelated words (e.g. "PRINT", "CICERO") and falsely satisfy the
# check. CR cycle 2 #10. Pattern requires the needle to be flanked
# by non-alphanumeric/underscore boundaries.
for needle in push PR CI; do
  pattern="(^|[^[:alnum:]_])${needle}([^[:alnum:]_]|$)"
  if ! grep -Eqi "$pattern" "$PROMPT"; then
    fails+=("prompt missing AC8 term: $needle")
  fi
done

# --- Contract: prompt names mark-shipped as the terminal SHIP action so
# the agent knows when the walk is complete (matches Claude Code /ship). ---
if ! grep -qF 'mark-shipped' "$PROMPT"; then
  fails+=("prompt missing terminal action reference: mark-shipped")
fi

# --- Framework SHIP-phase actions must exist in templates so HRN-01
# copies them into .pi/sdd/actions/ on session_start. ---
for action in push-pr verify-ci-green mark-shipped; do
  if [ ! -f "$TPL/actions/$action.md" ]; then
    fails+=("framework action missing: $TPL/actions/$action.md")
  fi
done

# --- End-to-end: build a fixture spec.md sitting in PHASE: SHIP and run
# next-action.sh — it should resolve a SHIP-phase action so /sdd-ship has
# something concrete to drive the agent toward. ---
WORK="$(mktemp -d -t sdd-t207.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PROJECT="$WORK/project"
FEATURE="$PROJECT/.sdd/features/001-test-thing"
mkdir -p \
  "$FEATURE" \
  "$PROJECT/.sdd/scripts" \
  "$PROJECT/.sdd/actions" \
  "$PROJECT/.sdd/playbooks"

cp "$TPL/scripts/next-action.sh"        "$PROJECT/.sdd/scripts/next-action.sh"
cp "$TPL/scripts/resolve-parameters.sh" "$PROJECT/.sdd/scripts/resolve-parameters.sh" 2>/dev/null || true
cp "$TPL/playbooks/feature.md"          "$PROJECT/.sdd/playbooks/feature.md"
cp "$TPL/actions/push-pr.md"            "$PROJECT/.sdd/actions/push-pr.md"
cp "$TPL/actions/verify-ci-green.md"    "$PROJECT/.sdd/actions/verify-ci-green.md"
cp "$TPL/actions/mark-shipped.md"       "$PROJECT/.sdd/actions/mark-shipped.md"

cat > "$PROJECT/.sdd/INDEX.md" <<'EOF'
# INDEX

**Active:** features/001-test-thing
**Playbook:** feature
EOF

# Spec at PHASE: SHIP with one open push-pr step row so next-action.sh
# returns a SHIP-phase action — the contract /sdd-ship walks each turn.
cat > "$FEATURE/spec.md" <<'EOF'
# test thing

[PHASE: SHIP]

## PHASE: SHIP

### action: push-pr

- [ ] push: push the branch and open a PR with spec.md as the body
EOF

na_out="$(cd "$PROJECT" && bash .sdd/scripts/next-action.sh "$FEATURE/spec.md" 2>&1)"
na_rc=$?
[ "$na_rc" -eq 0 ] || fails+=("next-action.sh failed (exit $na_rc): $na_out")

# Whitespace-tolerant JSON match — equivalent valid JSON (different
# spacing, indentation, minified) should still pass. CR cycle 2 #11.
for needle in \
  '"phase"[[:space:]]*:[[:space:]]*"SHIP"' \
  '"action"[[:space:]]*:[[:space:]]*"push-pr"' \
  '"step"[[:space:]]*:[[:space:]]*"push"'
do
  if ! printf '%s' "$na_out" | grep -Eq "$needle"; then
    fails+=("next-action.sh JSON missing field pattern: $needle (got: $na_out)")
  fi
done

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T207 — AC8 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T207 — AC8 /sdd-ship prompt delegates to next-action.sh; teaches push/PR/CI/mark-shipped; SHIP-phase walk resolves on fixture spec"
