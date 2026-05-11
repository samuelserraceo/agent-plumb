#!/usr/bin/env bash
# T204 — AC5 — Pre-commit hooks fire on wave-task commits.
#
# Wave-task subagents commit via the harness's Agent tool, which
# delegates to standard `git commit`. Standard `git commit` runs the
# project's pre-commit hook chain (anti-theatre, atomic-step,
# test-first, append-only). The only way wave dispatch could bypass
# the chain is if dispatch-wave.sh explicitly uses `--no-verify` or
# clobbers `core.hooksPath`.
#
# Two checks:
#   A) Code-shape: dispatch-wave.sh contains NO bypass tokens
#      (`--no-verify`, `GIT_HOOKS_PATH=`, `core.hooksPath=` clobbers).
#   B) Functional: in a fixture git repo with a sentinel pre-commit
#      hook, an ordinary commit invoking the same code path the
#      subagent will use fires the hook. The real Agent-tool flow is
#      verified at SHIP via AC12 (PROD-ONLY).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/dispatch-wave.sh"

fails=()

# Fail fast: a missing/unreadable dispatch-wave.sh would let the
# token-scan loop silently no-op (no findings + AC5 PASS = false green).
if [ ! -r "$SCRIPT" ]; then
  fails+=("missing or unreadable dispatch script: $SCRIPT")
fi

# --- A) Code-shape: no bypass tokens -----------------------------------
# `--no-verify` is the canonical bypass flag for `git commit`.
if grep -nE '\-\-no\-verify' "$SCRIPT" >/dev/null 2>&1; then
  line="$(grep -nE '\-\-no\-verify' "$SCRIPT" | head -1)"
  fails+=("dispatch-wave.sh contains --no-verify (bypasses pre-commit chain): $line")
fi

# `core.hooksPath=` (with `=` to spot config-clobber attempts).
if grep -nE 'core\.hooksPath\s*=' "$SCRIPT" >/dev/null 2>&1; then
  line="$(grep -nE 'core\.hooksPath\s*=' "$SCRIPT" | head -1)"
  fails+=("dispatch-wave.sh sets core.hooksPath (would clobber the hook chain): $line")
fi

# `GIT_HOOKS_PATH=` env clobber.
if grep -nE 'GIT_HOOKS_PATH\s*=' "$SCRIPT" >/dev/null 2>&1; then
  line="$(grep -nE 'GIT_HOOKS_PATH\s*=' "$SCRIPT" | head -1)"
  fails+=("dispatch-wave.sh sets GIT_HOOKS_PATH (bypasses hooks): $line")
fi

# --- B) Functional: standard git commit fires pre-commit -------------
# Build a tiny git repo, install a sentinel pre-commit hook that
# touches a tell-tale file, then `git commit` and verify the file
# appeared. This proves the framework's commit path inherits the hook
# chain — the same path any subagent's `git commit` invocation uses.
WORK="$(mktemp -d -t sdd-t204.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/repo"
cd "$WORK/repo" || { echo "FAIL: T204 — cannot cd to fixture repo $WORK/repo"; exit 1; }
git init -q
git config user.email "t204@test.local"
git config user.name "T204 test"
git config commit.gpgsign false

mkdir -p .git/hooks
# Pin the hooksPath to repo-local so a global `core.hooksPath` in the
# developer's git config doesn't redirect away from our sentinel hook
# (which would make this fixture pass-or-fail for the wrong reason).
git config core.hooksPath .git/hooks
cat > .git/hooks/pre-commit <<HOOK
#!/usr/bin/env bash
touch "$WORK/.hook-fired"
exit 0
HOOK
chmod +x .git/hooks/pre-commit

echo "hello" > sentinel.txt
git add sentinel.txt
git commit -q -m "fire the hook"

if [ ! -f "$WORK/.hook-fired" ]; then
  fails+=("pre-commit hook did NOT fire on standard git commit (means hook-chain integrity is broken on this machine, not a dispatch-wave.sh issue)")
fi

# --- Report ----------------------------------------------------------
if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T204 — AC5 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T204 — AC5 dispatch-wave.sh contains no hook-bypass tokens + standard git commit fires pre-commit (real subagent dispatch verified at SHIP via AC12 PROD-ONLY walk)"
