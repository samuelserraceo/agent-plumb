#!/usr/bin/env bash
# T210 — AC11 — Pre-commit enforcement at git layer fires deterministically
# when committing through pi.dev, matching the chain Claude Code uses today.
#
# Why this works without pi-extension-specific commit-handling: git's
# pre-commit hook fires regardless of which tool issued `git commit`.
# When core.hooksPath = .claude/hooks (set by /sdd-start's start.sh
# wiring, same path as Claude Code), pi.dev's commits run through the
# same dispatcher shim + chain.
#
# T210 verifies four things:
#
#   A) Templates carry the dispatcher shim + the three required hook
#      scripts — anti-theatre, atomic-step (via the F1 generic
#      pre-commit-rules.sh enforcer), and test-first. These are the
#      canonical chain Claude Code wires today; HRN-01 expects them at
#      .claude/hooks/ on disk for pi.dev users too.
#
#   B) The framework script /sdd-start invokes (start.sh) sets
#      core.hooksPath = .claude/hooks. This is the wiring point that
#      makes pi.dev inherit the same enforcement automatically — the
#      pi extension does not need a separate commit handler because
#      git itself fires the chain.
#
#   C) Pi extension's session-start.sh invokes check-worktree-hookpath.sh
#      so EC #4 (worktree-level core.hooksPath override) is detected
#      at session-start time, not silently bypassed. T201 verified the
#      check script exists with the right actionable command; T210
#      verifies it's actually wired into session_start.
#
#   D) End-to-end smoke: a real `git commit` in a fixture project
#      (real shim + three stub hooks declared in settings.json + shim
#      activated via core.hooksPath) dispatches to ALL three hooks,
#      proving the chain fires deterministically. Same mechanism
#      pi.dev hits when it shells out to git.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOKS="$FRAMEWORK_ROOT/templates/.claude/hooks"
EXT_ROOT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension"

fails=()

# --- A) Template chain present --------------------------------------
[ -f "$HOOKS/pre-commit" ]                  || fails+=("templates/.claude/hooks/pre-commit (dispatcher shim) missing")
[ -f "$HOOKS/pre-commit-no-theatre.sh" ]    || fails+=("templates/.claude/hooks/pre-commit-no-theatre.sh missing (anti-theatre)")
[ -f "$HOOKS/pre-commit-rules.sh" ]         || fails+=("templates/.claude/hooks/pre-commit-rules.sh missing (atomic-step / F1 generic enforcer)")
[ -f "$HOOKS/pre-commit-test-first.sh" ]    || fails+=("templates/.claude/hooks/pre-commit-test-first.sh missing (test-first)")

# --- B) /sdd-start's start.sh wires core.hooksPath = .claude/hooks --
START_SH="$FRAMEWORK_ROOT/templates/.sdd/scripts/start.sh"
if [ ! -f "$START_SH" ]; then
  fails+=("templates/.sdd/scripts/start.sh missing (the wiring point /sdd-start invokes)")
elif ! grep -qF 'core.hooksPath .claude/hooks' "$START_SH"; then
  fails+=("start.sh missing core.hooksPath wiring — pi.dev users won't get the chain via /sdd-start")
fi

# --- C) session-start.sh wires the worktree-hookpath check ----------
SESS="$EXT_ROOT/scripts/session-start.sh"
WTC="check-worktree-hookpath.sh"
if [ ! -f "$SESS" ]; then
  fails+=("extensions/sdd-pi-extension/scripts/session-start.sh missing")
elif ! grep -qF "$WTC" "$SESS"; then
  fails+=("session-start.sh does not invoke $WTC — EC#4 detection not wired into session_start")
fi

# --- D) End-to-end: real git commit dispatches the chain via shim ---
WORK="$(mktemp -d -t sdd-t210.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PROJECT="$WORK/project"
mkdir -p "$PROJECT/.claude/hooks"

# The real shim — this is what fires on git commit.
cp "$HOOKS/pre-commit" "$PROJECT/.claude/hooks/pre-commit"
chmod +x "$PROJECT/.claude/hooks/pre-commit"

MARKER_DIR="$WORK/markers"
mkdir -p "$MARKER_DIR"

# Stub each of the three target hooks; the shim's regex requires the
# pre-commit-<slug>.sh shape. Each stub records that it ran by
# touching a marker file the test inspects after.
for h in pre-commit-no-theatre.sh pre-commit-rules.sh pre-commit-test-first.sh; do
  cat > "$PROJECT/.claude/hooks/$h" <<EOF
#!/usr/bin/env bash
touch "$MARKER_DIR/$h.ran"
exit 0
EOF
  chmod +x "$PROJECT/.claude/hooks/$h"
done

# Settings.json declaring all three hooks under PreToolUse(Bash) — the
# same shape Claude Code's settings.json uses. The shim's Python
# parser reads this and dispatches each command in turn.
cat > "$PROJECT/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"command": ".claude/hooks/pre-commit-no-theatre.sh"},
          {"command": ".claude/hooks/pre-commit-rules.sh"},
          {"command": ".claude/hooks/pre-commit-test-first.sh"}
        ]
      }
    ]
  }
}
EOF

git_out="$(
  cd "$PROJECT" && \
  git init -q && \
  git config core.hooksPath .claude/hooks && \
  git config user.email "t210@test" && \
  git config user.name "T210 Test" && \
  echo "hello" > README.md && \
  git add README.md && \
  git commit -q -m "initial commit" 2>&1
)"
git_rc=$?
if [ "$git_rc" -ne 0 ]; then
  fails+=("git commit in fixture failed (shim or stub errored, exit $git_rc): $git_out")
fi

for h in pre-commit-no-theatre.sh pre-commit-rules.sh pre-commit-test-first.sh; do
  if [ ! -f "$MARKER_DIR/$h.ran" ]; then
    fails+=("hook never ran during git commit: $h (shim didn't dispatch — chain bypassed)")
  fi
done

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T210 — AC11 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T210 — AC11 git pre-commit chain (anti-theatre, atomic-step, test-first) fires on git commit; pi.dev inherits via core.hooksPath wiring"
