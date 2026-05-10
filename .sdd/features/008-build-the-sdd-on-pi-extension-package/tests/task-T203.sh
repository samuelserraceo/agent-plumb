#!/usr/bin/env bash
# T203 — AC4 — first-run session_start copies framework files from the
# package into the project's .pi/sdd/ via the HRN-01 copy-on-first-run
# pattern; second run is a no-op for user-edited files. Folded EC #6
# (old pi version): the script refuses with a plain-English message
# when the host's pi version is below the extension's declared minimum.
#
# The actual TypeScript extension's pi.on("session_start") handler
# delegates the work to scripts/session-start.sh so the contract can
# be exercised deterministically from tests without booting pi.dev.
# This mirrors how the prompt templates delegate to bash .sdd/scripts/*.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension/scripts/session-start.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: T203 — scripts/session-start.sh missing at $SCRIPT"
  exit 1
fi

WORK="$(mktemp -d -t sdd-t203.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PROJECT="$WORK/project"
PKG_TEMPLATE="$WORK/pkg-template"
mkdir -p \
  "$PROJECT" \
  "$PKG_TEMPLATE/scripts" \
  "$PKG_TEMPLATE/actions" \
  "$PKG_TEMPLATE/playbooks"

echo "framework: next-action" > "$PKG_TEMPLATE/scripts/next-action.sh"
echo "action: who"            > "$PKG_TEMPLATE/actions/problem-who.md"
echo "playbook: feature"      > "$PKG_TEMPLATE/playbooks/feature.md"

fails=()

# --- EC #6: pi version below declared minimum should refuse ---
out="$(PI_VERSION=0.1.0 bash "$SCRIPT" \
  --project "$PROJECT" \
  --from "$PKG_TEMPLATE" \
  --min-pi-version 0.5.0 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  fails+=("EC #6: PI_VERSION=0.1.0 (< min 0.5.0) should refuse — got exit 0")
fi
case "$out" in
  *version*) : ;;
  *) fails+=("EC #6: refusal output should mention 'version' (got: $out)") ;;
esac
if [ -d "$PROJECT/.pi/sdd" ]; then
  fails+=("EC #6: refusal must not have written .pi/sdd/")
fi

# --- First-run copy: framework files land in .pi/sdd/ ---
PI_VERSION=0.5.0 bash "$SCRIPT" \
  --project "$PROJECT" \
  --from "$PKG_TEMPLATE" \
  --min-pi-version 0.5.0 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] || fails+=("first-run exited non-zero ($rc) on valid PI_VERSION")
[ -f "$PROJECT/.pi/sdd/scripts/next-action.sh" ]   || fails+=("first-run did not copy scripts/next-action.sh")
[ -f "$PROJECT/.pi/sdd/actions/problem-who.md" ]   || fails+=("first-run did not copy actions/problem-who.md")
[ -f "$PROJECT/.pi/sdd/playbooks/feature.md" ]     || fails+=("first-run did not copy playbooks/feature.md")

# --- HRN-01 idempotence: user-edited file survives second run ---
USER_EDIT='USER EDIT: do not overwrite'
echo "$USER_EDIT" > "$PROJECT/.pi/sdd/actions/problem-who.md"

PI_VERSION=0.5.0 bash "$SCRIPT" \
  --project "$PROJECT" \
  --from "$PKG_TEMPLATE" \
  --min-pi-version 0.5.0 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] || fails+=("second-run exited non-zero ($rc)")

content="$(cat "$PROJECT/.pi/sdd/actions/problem-who.md" 2>/dev/null || echo MISSING)"
if [ "$content" != "$USER_EDIT" ]; then
  fails+=("HRN-01 violation: second run overwrote user-edited file (got: $content)")
fi

# --- HRN-01 fill-in: a framework file deleted between runs is restored ---
rm -f "$PROJECT/.pi/sdd/scripts/next-action.sh"
PI_VERSION=0.5.0 bash "$SCRIPT" \
  --project "$PROJECT" \
  --from "$PKG_TEMPLATE" \
  --min-pi-version 0.5.0 >/dev/null 2>&1
[ -f "$PROJECT/.pi/sdd/scripts/next-action.sh" ] || fails+=("HRN-01 fill-in: deleted framework file should be re-copied")

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T203 — AC4 + EC #6 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T203 — AC4 first-run copy + HRN-01 idempotence + EC #6 pi version check"
