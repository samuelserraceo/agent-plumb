#!/usr/bin/env bash
# T201 — AC2 — extensions/sdd-pi-extension/prompts/ contains 9 named
# sdd-* prompt templates that pi.dev will surface as slash commands
# after `pi install npm:sdd-pi-adapter`.
#
# Pi auto-discovers slash commands by walking the directory pointed at
# by package.json#pi.prompts. Each *.md file becomes a /<basename>
# slash command. Without the 9 files, the install completes but the
# user sees zero new commands.
#
# Folded edge case #4 — worktree config conflict (extensions.worktreeConfig
# overrides core.hooksPath at the worktree level): assert there is a
# check script that contains the exact actionable git command users
# need to run when the conflict is detected.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
EXT_ROOT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension"
PKG="$EXT_ROOT/package.json"

if [ ! -f "$PKG" ]; then
  echo "FAIL: T201 — package.json missing at $PKG (T200 should have shipped first)"
  exit 1
fi

# Resolve prompts dir from package.json#pi.prompts (no jq dep).
PROMPTS_DIR="$(python3 - "$PKG" "$EXT_ROOT" <<'PY'
import json, os, sys
pkg_path, ext_root = sys.argv[1], sys.argv[2]
with open(pkg_path) as f:
    pkg = json.load(f)
rel = (pkg.get("pi") or {}).get("prompts") or ""
if not rel:
    print("")
else:
    print(os.path.normpath(os.path.join(ext_root, rel)))
PY
)"

if [ -z "$PROMPTS_DIR" ]; then
  echo "FAIL: T201 — package.json#pi.prompts not set"
  exit 1
fi

if [ ! -d "$PROMPTS_DIR" ]; then
  echo "FAIL: T201 — prompts dir missing at $PROMPTS_DIR"
  exit 1
fi

EXPECTED=(
  sdd-start
  sdd-next
  sdd-ship
  sdd-status
  sdd-compress
  sdd-skip
  sdd-bug
  sdd-idea
  sdd-config
)

fails=()
for name in "${EXPECTED[@]}"; do
  f="$PROMPTS_DIR/$name.md"
  if [ ! -f "$f" ]; then
    fails+=("missing: prompts/$name.md")
    continue
  fi
  if [ ! -s "$f" ]; then
    fails+=("empty: prompts/$name.md")
  fi
done

# Tighten to "exactly N" — CR cycle 2 #6. Without this, drift is silent
# (e.g. an extra prompts/sdd-experiment.md sneaks in, AC2 still says
# "9 commands" but reality has 10). Enforces the contract counted in
# §11 AC2 + §13 wireframe + the slash-command surface advertised to
# users.
actual_count=$(find "$PROMPTS_DIR" -maxdepth 1 -type f -name 'sdd-*.md' | wc -l | tr -d ' ')
expected_count=${#EXPECTED[@]}
if [ "$actual_count" -ne "$expected_count" ]; then
  fails+=("count mismatch: prompts/sdd-*.md has $actual_count files, AC2 declares exactly $expected_count")
fi

# Folded EC #4 — worktree config detection script must exist and contain
# the exact actionable git command for the user to run.
WORKTREE_CHECK="$EXT_ROOT/scripts/check-worktree-hookpath.sh"
ACTIONABLE='git config --worktree core.hooksPath .claude/hooks'
if [ ! -f "$WORKTREE_CHECK" ]; then
  fails+=("missing: scripts/check-worktree-hookpath.sh (folded EC #4)")
elif ! grep -qF "$ACTIONABLE" "$WORKTREE_CHECK"; then
  fails+=("scripts/check-worktree-hookpath.sh missing actionable command: $ACTIONABLE")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T201 — AC2 prompts/ + worktree-check shape violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T201 — AC2 prompts/ has 9 sdd-* templates + worktree-conflict check present"
