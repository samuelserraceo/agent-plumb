#!/usr/bin/env bash
# T204 — AC5 — /sdd-start "<title>" invokes bash .sdd/scripts/start.sh
# with $ARGUMENTS, scaffolds .sdd/features/<NNN>-<slug>/spec.md, and
# updates INDEX.md.
#
# The pi extension owns the prompt template; the framework owns
# start.sh. T204 verifies BOTH layers — the contract (template body
# delegates to start.sh with $ARGUMENTS) AND the end-to-end side
# effects when the delegated command runs against framework templates.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROMPT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension/prompts/sdd-start.md"
TPL="$FRAMEWORK_ROOT/templates/.sdd"

if [ ! -f "$PROMPT" ]; then
  echo "FAIL: T204 — prompts/sdd-start.md missing at $PROMPT"
  exit 1
fi
if [ ! -d "$TPL" ]; then
  echo "FAIL: T204 — framework templates dir missing at $TPL"
  exit 1
fi

fails=()

# --- Contract: prompt body delegates to framework's start.sh with $ARGUMENTS ---
CONTRACT='bash .sdd/scripts/start.sh "$ARGUMENTS"'
if ! grep -qF "$CONTRACT" "$PROMPT"; then
  fails+=("prompt missing exact invocation: $CONTRACT")
fi

# --- End-to-end: build a fixture, run start.sh, verify side effects ---
WORK="$(mktemp -d -t sdd-t204.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PROJECT="$WORK/project"
mkdir -p "$PROJECT/.sdd/scripts" "$PROJECT/.sdd/playbooks" "$PROJECT/.sdd/actions" \
  || fails+=("setup: mkdir for fixture failed (rc=$?)")
cp "$TPL/config.md"          "$PROJECT/.sdd/config.md"          || fails+=("setup: cp config.md failed (rc=$?)")
cp "$TPL/playbooks/feature.md" "$PROJECT/.sdd/playbooks/feature.md" || fails+=("setup: cp playbooks/feature.md failed (rc=$?)")
cp "$TPL/actions/"*.md       "$PROJECT/.sdd/actions/"           || fails+=("setup: cp actions/*.md failed (rc=$?)")
cp "$TPL/scripts/start.sh"   "$PROJECT/.sdd/scripts/start.sh"   || fails+=("setup: cp scripts/start.sh failed (rc=$?)")

# Run the command exactly as pi.dev would after substituting $ARGUMENTS.
TITLE='build a test thing'
( cd "$PROJECT" && bash .sdd/scripts/start.sh "$TITLE" ) >"$WORK/out" 2>"$WORK/err"
rc=$?
[ "$rc" -eq 0 ] || fails+=("start.sh failed (exit $rc): $(cat "$WORK/err")")

# AC5 side effect 1: features/NNN-<slug>/spec.md scaffolded.
SPEC=""
for f in "$PROJECT/.sdd/features/"*"build-a-test-thing"/spec.md; do
  [ -f "$f" ] && SPEC="$f" && break
done
if [ -z "$SPEC" ]; then
  fails+=("AC5: spec.md not scaffolded for '$TITLE' under .sdd/features/")
fi

# AC5 side effect 2: INDEX.md updated to reference the new feature.
if ! grep -q "build-a-test-thing" "$PROJECT/.sdd/INDEX.md" 2>/dev/null; then
  fails+=("AC5: INDEX.md missing reference to 'build-a-test-thing' after /sdd-start")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T204 — AC5 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T204 — AC5 /sdd-start prompt delegates to start.sh; scaffolds spec.md + updates INDEX.md"
