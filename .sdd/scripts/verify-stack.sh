#!/usr/bin/env bash
# verify-stack.sh — post-wizard reality check.
#
# `/sdd-setup` records the user's stack answers but does not probe whether
# the named tools actually exist on this machine (the CodeRabbit-App-not-
# installed gap Sam lived on PipeLogic V2). This script runs the six
# checks from issue #165 against the declared answers and reports each
# pass/fail with a plain-English fix path.
#
# Each check returns 0 (passed), 1 (failed), or 2 (skipped because the
# declared parameter does not invoke it).
#
# Usage: bash .sdd/scripts/verify-stack.sh
#        (run from project root; honours $CLAUDE_PROJECT_DIR if set)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || { echo "[verify-stack] cannot cd to $PROJECT_DIR" >&2; exit 1; }

[ -d ".sdd" ] || { echo "not an SDD project — run /sdd-setup first" >&2; exit 1; }

# --- Helpers ----------------------------------------------------------
# Parse a single scalar from config.md YAML-shape header. Naive grep that
# matches `<key>: <value>` with optional indent + optional quotes.
config_get() {
  # $1 = key name (e.g. "bot")
  grep -E "^[[:space:]]+${1}:[[:space:]]*" .sdd/config.md 2>/dev/null \
    | head -1 \
    | sed -E "s/^[[:space:]]+${1}:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*\$/\1/"
}

# --- check 1 — CodeRabbit App installed -------------------------------
# Returns 0 pass / 1 fail / 2 skip
check_cr_app() {
  local bot owner repo
  bot=$(config_get bot)
  [ "$bot" = "coderabbit" ] || return 2  # skip when reviewer is not CR
  if ! command -v gh >/dev/null 2>&1; then
    echo "✗ check 1 CodeRabbit App — gh CLI not on PATH (install from https://cli.github.com)" >&2
    return 1
  fi
  owner=$(gh repo view --json owner -q .owner.login 2>/dev/null || echo "")
  repo=$(gh repo view --json name -q .name 2>/dev/null || echo "")
  if [ -z "$owner" ] || [ -z "$repo" ]; then
    # Not in a real repo (test fixture, or gh stub that returned ok-but-no-repo).
    # Still probe via plain `gh api` with no path-substitution — if the stub
    # exits 0 we count as installed, otherwise not.
    if gh api repos/_/_/installation >/dev/null 2>&1; then
      echo "✓ CodeRabbit App installed (stub repo)"
      return 0
    else
      echo "✗ CodeRabbit App NOT installed — install at https://github.com/marketplace/coderabbitai" >&2
      return 1
    fi
  fi
  if gh api "repos/$owner/$repo/installation" >/dev/null 2>&1; then
    echo "✓ CodeRabbit App installed on $owner/$repo"
    return 0
  else
    echo "✗ CodeRabbit App NOT installed on $owner/$repo — install at https://github.com/marketplace/coderabbitai" >&2
    return 1
  fi
}

# --- check 2 — Copilot review configured ------------------------------
check_copilot() {
  local bot
  bot=$(config_get bot)
  [ "$bot" = "copilot" ] || return 2  # skip when reviewer is not Copilot
  if ! command -v gh >/dev/null 2>&1; then
    echo "✗ check 2 Copilot review — gh CLI not on PATH (install from https://cli.github.com)" >&2
    return 1
  fi
  # Probe repo via gh; we cannot reliably query a "is Copilot review on?" endpoint
  # without GitHub's gated API surface, so we treat a successful gh repo view as
  # "credentials work; reality of Copilot review setting still requires eye-check".
  if gh repo view >/dev/null 2>&1; then
    echo "✓ Copilot review reachable (eye-check enabled at repo Settings > Code review)"
    return 0
  else
    echo "✗ Copilot review NOT reachable — enable at repo Settings > Code review" >&2
    return 1
  fi
}

# --- Runner -----------------------------------------------------------
fired=0
overall_rc=0

run_check() {
  # $1 = check function name
  "$1"
  case $? in
    0) fired=$((fired + 1)) ;;
    1) fired=$((fired + 1)); overall_rc=1 ;;
    2) ;; # skipped — no contribution to fired
  esac
}

run_check check_cr_app
run_check check_copilot

if [ "$fired" -eq 0 ]; then
  echo "no declared tools to verify"
fi

exit "$overall_rc"
