#!/usr/bin/env bash
# install-ci-workflow.sh — auto-ship .github/workflows/sdd-ci.yml at /sdd-setup
# (closes #199 — F01 of pipelogic_v2 shipped to PR #1 with only CodeRabbit
# running because there was no CI workflow; the framework's RED→GREEN
# discipline silently didn't carry through to merge).
#
# Called by /sdd-setup after Q4 (browser-tests) is answered, and any time
# /sdd-config 004-browser-tests is re-run. Reads .sdd/stack.md to learn the
# project's test runner, picks the matching template from
# .sdd/scripts/templates/sdd-ci-<stack>.yml.tmpl, and writes
# .github/workflows/sdd-ci.yml.
#
# Idempotent. Plain-English on every error path.
#
# Usage:
#   install-ci-workflow.sh [--force] [--quiet]
#
# Flags:
#   --force   overwrite an existing .github/workflows/sdd-ci.yml. Default is
#             to preserve hand-edits — re-runs of the wizard never clobber
#             customised CI files.
#   --quiet   suppress the "wrote / preserved" stdout line on success. Used
#             when called from the wizard prose so the agent's own one-line
#             confirmation is the user-facing surface.
#
# Exit:
#   0 — workflow installed, preserved, or deferred (Q4 = "Not deciding yet")
#   1 — error (template missing for chosen runner, can't read stack.md)
#   2 — usage error

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FORCE=0
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    --quiet) QUIET=1 ;;
    -h|--help)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *)
      echo "install-ci-workflow.sh: unrecognised flag '$1'" >&2
      exit 2
      ;;
  esac
  shift
done

say() {
  [ "$QUIET" -eq 1 ] || echo "$1"
}

STACK_MD="$PROJECT_DIR/.sdd/stack.md"
WORKFLOW_PATH="$PROJECT_DIR/.github/workflows/sdd-ci.yml"
TEMPLATES_DIR="$PROJECT_DIR/.sdd/scripts/templates"

if [ ! -f "$STACK_MD" ]; then
  echo "[install-ci-workflow] no stack.md at $STACK_MD" >&2
  echo "[install-ci-workflow] run /sdd-setup first to create it." >&2
  exit 1
fi

if [ ! -d "$TEMPLATES_DIR" ]; then
  echo "[install-ci-workflow] no CI templates directory at $TEMPLATES_DIR" >&2
  echo "[install-ci-workflow] this means the framework templates didn't ship correctly." >&2
  echo "[install-ci-workflow] re-run bin/sdd-init.sh or report this as a bug." >&2
  exit 1
fi

# Read the test runner answer from stack.md ## Testing.
# Tolerates "- **Test runner:** Playwright" (bold), "Test runner: Playwright"
# (plain), or "Test runner: _(deferred)_" (Q4 = "Not deciding yet" sentinel).
runner=$(awk '
  /^## Testing/ { in_section=1; next }
  /^## / && in_section { exit }
  in_section && /[Tt]est runner/ {
    line=$0
    # Two markdown shapes are common, plus the plain form:
    #   - **Test runner:** Playwright       (colon inside bold)
    #   - **Test runner**: pure bash...     (colon outside bold)
    #   - Test runner: pytest                (no bold)
    # Strip everything up through the first ":" after the label, then any
    # remaining bold markers + leading/trailing whitespace.
    sub(/.*[Tt]est runner[^:]*:[[:space:]]*/, "", line)
    sub(/^\*\*/, "", line); sub(/\*\*$/, "", line)
    sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
    print line
    exit
  }
' "$STACK_MD")

# Q4 = "Not deciding yet" sentinel handling — exit 0 silently, the user can
# come back via /sdd-config 004-browser-tests once they pick a runner.
if [ -z "$runner" ] || [[ "$runner" =~ ^_\(deferred\)_$ ]] || [[ "$runner" =~ [Nn]ot\ decid ]]; then
  say "[install-ci-workflow] no test runner picked yet (Q4 deferred)."
  say "[install-ci-workflow] run /sdd-config 004-browser-tests once you've decided, then this will fire automatically."
  exit 0
fi

# Map runner → template. Keep the matcher simple and case-tolerant; the
# wizard records "Playwright" / "Vitest" / "pytest" verbatim today.
#
# CR cycle 2 (PR #208): `unittest` and `ruff` were originally bucketed
# into the python template, but that template runs `pytest -v` — so a
# project that picked unittest would get a CI run that crashes on
# missing pytest, and ruff is a linter (not a test runner) that has
# no business mapping to a runner template at all. Both removed; if
# someone picks them they fall through to the "no template yet" path
# which prints a plain-English add-a-template instruction.
shopt -s nocasematch || true
case "$runner" in
  *playwright*|*vitest*|*jest*|*mocha*|*node*|*tsc*|*typescript*) tmpl="sdd-ci-node.yml.tmpl" ;;
  *pytest*|*python*) tmpl="sdd-ci-python.yml.tmpl" ;;
  *)
    echo "[install-ci-workflow] no CI template yet for test runner '$runner'." >&2
    echo "[install-ci-workflow] templates ship for: Playwright/Vitest/Jest (Node) and pytest (Python)." >&2
    echo "[install-ci-workflow] add your stack's template at $TEMPLATES_DIR/sdd-ci-<stack>.yml.tmpl" >&2
    echo "[install-ci-workflow] and re-run /sdd-config 004-browser-tests." >&2
    exit 1
    ;;
esac
shopt -u nocasematch || true

TMPL_PATH="$TEMPLATES_DIR/$tmpl"

if [ ! -f "$TMPL_PATH" ]; then
  echo "[install-ci-workflow] template not found at $TMPL_PATH" >&2
  echo "[install-ci-workflow] this means the framework templates are incomplete." >&2
  exit 1
fi

if [ -f "$WORKFLOW_PATH" ] && [ "$FORCE" -ne 1 ]; then
  say "[install-ci-workflow] $WORKFLOW_PATH already exists — preserving hand-edits."
  say "[install-ci-workflow] re-run with --force to overwrite from the template."
  exit 0
fi

mkdir -p "$(dirname "$WORKFLOW_PATH")"
cp "$TMPL_PATH" "$WORKFLOW_PATH"

say "[install-ci-workflow] wrote $WORKFLOW_PATH (from $tmpl, runner=$runner)."
say "[install-ci-workflow] mark it REQUIRED in your GitHub branch protection if you want PRs blocked until this passes."
exit 0
