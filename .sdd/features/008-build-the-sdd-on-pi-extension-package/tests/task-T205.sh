#!/usr/bin/env bash
# T205 — AC6 — /sdd-next invokes the /next flow via prompt template;
# resolves the active blocker via next-action.sh; asks/proposes per
# the action's tag (USER-LED / AGENT-LED / BUILD-TASK).
#
# Same delegation pattern as T204 (sdd-start → start.sh): the pi
# extension owns the prompt template; the framework owns the scripts.
# T205 verifies BOTH layers — the contract (prompt body delegates to
# resolve-active.sh + next-action.sh and teaches the three tag routes)
# AND the end-to-end JSON shape next-action.sh emits when run against
# a fixture spec.md (the actual contract /sdd-next downstream relies
# on to ask/propose per tag).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROMPT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension/prompts/sdd-next.md"
TPL="$FRAMEWORK_ROOT/templates/.sdd"

if [ ! -f "$PROMPT" ]; then
  echo "FAIL: T205 — prompts/sdd-next.md missing at $PROMPT"
  exit 1
fi
if [ ! -d "$TPL" ]; then
  echo "FAIL: T205 — framework templates dir missing at $TPL"
  exit 1
fi

fails=()

# --- Contract: prompt body delegates to BOTH resolve-active.sh AND
# next-action.sh. resolve-active first (to learn `active`), then
# next-action.sh against the resolved spec path. Without both, the
# prompt can't distinguish "no active feature" from "active feature
# with phase done". ---
if ! grep -qF 'bash .sdd/scripts/resolve-active.sh' "$PROMPT"; then
  fails+=("prompt missing invocation: bash .sdd/scripts/resolve-active.sh")
fi
if ! grep -qF 'bash .sdd/scripts/next-action.sh' "$PROMPT"; then
  fails+=("prompt missing invocation: bash .sdd/scripts/next-action.sh")
fi

# --- Contract: prompt teaches all three tag routes. AC6 names them
# verbatim — without each present in the prompt body the agent cannot
# pick the right EXECUTE shape (ask vs propose vs test→code→green). ---
for tag in USER-LED AGENT-LED BUILD-TASK; do
  if ! grep -qF "$tag" "$PROMPT"; then
    fails+=("prompt missing tag route: $tag")
  fi
done

# --- End-to-end: build a fixture project, run next-action.sh, verify
# the JSON shape downstream consumers (the prompt's agent) need. ---
WORK="$(mktemp -d -t sdd-t205.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PROJECT="$WORK/project"
FEATURE="$PROJECT/.sdd/features/001-test-thing"
mkdir -p \
  "$FEATURE" \
  "$PROJECT/.sdd/scripts" \
  "$PROJECT/.sdd/actions" \
  "$PROJECT/.sdd/playbooks"

# Framework brain — copy the real scripts so we exercise the same
# resolver logic /sdd-next will run downstream.
cp "$TPL/scripts/resolve-active.sh"     "$PROJECT/.sdd/scripts/resolve-active.sh"
cp "$TPL/scripts/next-action.sh"        "$PROJECT/.sdd/scripts/next-action.sh"
cp "$TPL/scripts/resolve-parameters.sh" "$PROJECT/.sdd/scripts/resolve-parameters.sh" 2>/dev/null || true
cp "$TPL/playbooks/feature.md"          "$PROJECT/.sdd/playbooks/feature.md"
cp "$TPL/actions/problem.md"            "$PROJECT/.sdd/actions/problem.md"

# Minimal INDEX.md — index-fallback path (the fixture isn't a git repo,
# so resolve-active.sh's branch-derived path returns null and falls back
# to **Active:** here).
cat > "$PROJECT/.sdd/INDEX.md" <<'EOF'
# INDEX

**Active:** features/001-test-thing
**Playbook:** feature
EOF

# Spec with one open USER-LED step row (problem/who) so next-action.sh
# can resolve action+step+tag+prompt — the four fields the prompt body
# routes on.
cat > "$FEATURE/spec.md" <<'EOF'
# test thing

[PHASE: SPEC]

## PHASE: SPEC

### action: problem

- [ ] who: Who specifically has this problem? (real persona, not 'users')
- [ ] why-now: Why is it worth solving now?
- [ ] what-breaks: What breaks (concretely) if it isn't solved?
EOF

# 1. resolve-active.sh — should pick up the INDEX **Active:** line.
ra_out="$(cd "$PROJECT" && bash .sdd/scripts/resolve-active.sh 2>&1)"
ra_rc=$?
[ "$ra_rc" -eq 0 ] || fails+=("resolve-active.sh failed (exit $ra_rc): $ra_out")
# Whitespace-tolerant JSON match — equivalent valid JSON (different
# spacing, indentation) should still pass. CR cycle 2 #8.
if ! printf '%s' "$ra_out" | grep -Eq '"active"[[:space:]]*:[[:space:]]*"features/001-test-thing"'; then
  fails+=("resolve-active.sh did not return active=features/001-test-thing (got: $ra_out)")
fi

# 2. next-action.sh — should return the first open step's action/step/
#    tag/prompt so the agent can ask the user the right question.
na_out="$(cd "$PROJECT" && bash .sdd/scripts/next-action.sh "$FEATURE/spec.md" 2>&1)"
na_rc=$?
[ "$na_rc" -eq 0 ] || fails+=("next-action.sh failed (exit $na_rc): $na_out")

for needle in \
  '"phase"[[:space:]]*:[[:space:]]*"SPEC"' \
  '"action"[[:space:]]*:[[:space:]]*"problem"' \
  '"step"[[:space:]]*:[[:space:]]*"who"' \
  '"tag"[[:space:]]*:[[:space:]]*"USER-LED"'
do
  if ! printf '%s' "$na_out" | grep -Eq "$needle"; then
    fails+=("next-action.sh JSON missing field pattern: $needle (got: $na_out)")
  fi
done

# AC6 names the tag triplet — confirm the prompt field carries the
# action's question text so downstream "ask the user" actually has
# something to ask.
case "$na_out" in
  *'real persona'*) : ;;
  *) fails+=("next-action.sh missing prompt text from action frontmatter (got: $na_out)") ;;
esac

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T205 — AC6 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T205 — AC6 /sdd-next prompt delegates to resolve-active.sh + next-action.sh; tag routing taught for USER-LED / AGENT-LED / BUILD-TASK"
