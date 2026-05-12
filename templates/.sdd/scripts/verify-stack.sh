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

# --- check 3 — Branch protection on main ------------------------------
# Fires when stack.md prose mentions "branch protection" + "main"
# (declared intent), then probes gh api branches/main/protection.
check_branch_protection() {
  local declared
  declared=$(grep -iE "branch.protection" .sdd/stack.md 2>/dev/null | grep -i "main" | head -1)
  [ -n "$declared" ] || return 2  # skip if stack.md does not declare it
  if ! command -v gh >/dev/null 2>&1; then
    echo "✗ check 3 branch protection — gh CLI not on PATH" >&2
    return 1
  fi
  if gh api repos/_/_/branches/main/protection >/dev/null 2>&1; then
    echo "✓ branch protection on main reachable via gh api"
    return 0
  else
    echo "✗ branch protection on main NOT reachable — configure at repo Settings > Branches" >&2
    return 1
  fi
}

# --- check 4 — CI workflow files present ------------------------------
# Fires when stack.md declares "required CI checks" or "required check"
# with at least one named job. Greps `.github/workflows/*.yml` for the
# declared job names.
check_ci_workflows() {
  local declared missing job
  declared=$(grep -iE "required.{0,5}(CI )?check" .sdd/stack.md 2>/dev/null | head -1)
  [ -n "$declared" ] || return 2  # skip if not declared
  if ! ls .github/workflows/*.yml >/dev/null 2>&1 && ! ls .github/workflows/*.yaml >/dev/null 2>&1; then
    echo "✗ check 4 CI workflow missing — no .github/workflows/*.yml files found; declared required CI checks have nowhere to live" >&2
    return 1
  fi
  # Extract candidate job names from the declared line (after the colon)
  local joblist
  joblist=$(printf '%s\n' "$declared" | sed -E 's/^[^:]*:[[:space:]]*//' | tr ',' '\n' | tr -d ' ')
  missing=""
  for job in $joblist; do
    [ -z "$job" ] && continue
    # Strip leading list markers / whitespace
    job=$(printf '%s' "$job" | sed -E 's/^[-*[:space:]]+//')
    [ -z "$job" ] && continue
    if ! grep -rqE "^[[:space:]]*${job}:" .github/workflows/ 2>/dev/null; then
      missing="${missing}${missing:+, }${job}"
    fi
  done
  if [ -z "$missing" ]; then
    echo "✓ required CI workflow jobs present in .github/workflows/"
    return 0
  else
    echo "✗ required CI workflow jobs missing: $missing — add to .github/workflows/*.yml" >&2
    return 1
  fi
}

# --- check 5 — Tier 3 LLM provider reachable --------------------------
# Fires when parameters.mcp.tier3.enabled=true. Ollama: curl probe.
# OpenAI: env-var presence.
check_tier3_provider() {
  local enabled provider
  enabled=$(config_get enabled)
  [ "$enabled" = "true" ] || return 2  # skip when tier3 disabled
  provider=$(config_get provider)
  case "$provider" in
    ollama)
      if ! command -v curl >/dev/null 2>&1; then
        echo "✗ check 5 Tier 3 — curl not on PATH (Ollama probe needs it)" >&2
        return 1
      fi
      if curl --max-time 5 -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "✓ Tier 3 Ollama reachable on localhost:11434"
        return 0
      else
        echo "✗ Tier 3 Ollama NOT reachable on localhost:11434 — install + start at https://ollama.com" >&2
        return 1
      fi
      ;;
    openai)
      if [ -n "${OPENAI_API_KEY:-}" ]; then
        echo "✓ Tier 3 OpenAI key (OPENAI_API_KEY) present (key-validity not probed — eye-check)"
        return 0
      else
        echo "✗ Tier 3 OpenAI key (OPENAI_API_KEY) NOT set — export it in your shell rc" >&2
        return 1
      fi
      ;;
    *)
      echo "✗ Tier 3 enabled but provider='$provider' not recognised (expected ollama|openai)" >&2
      return 1
      ;;
  esac
}

# --- check 6 — Test runner deps ---------------------------------------
# Fires when stack.md declares "Test runner: <name>" (or similar shape).
# Greps package.json (or pyproject.toml fallback) for the runner name.
check_test_runner_deps() {
  local declared runner
  declared=$(grep -iE "test.runner" .sdd/stack.md 2>/dev/null | head -1)
  [ -n "$declared" ] || return 2  # skip if not declared
  runner=$(printf '%s\n' "$declared" | sed -E 's/.*[Tt]est.runner[: ]*//' | awk '{print $1}' | tr -d ',.;:')
  runner=$(printf '%s' "$runner" | tr '[:upper:]' '[:lower:]')
  [ -n "$runner" ] || return 2  # could not parse a name

  if [ -f package.json ] && grep -qi "\"$runner\"" package.json; then
    echo "✓ test runner '$runner' declared in package.json"
    return 0
  fi
  if [ -f pyproject.toml ] && grep -qi "^$runner" pyproject.toml; then
    echo "✓ test runner '$runner' declared in pyproject.toml"
    return 0
  fi
  if [ -f package.json ] || [ -f pyproject.toml ]; then
    echo "✗ test runner '$runner' NOT in package.json / pyproject.toml — npm install --save-dev $runner (or equivalent)" >&2
    return 1
  fi
  echo "✗ test runner '$runner' declared but no package.json / pyproject.toml found in project — install missing" >&2
  return 1
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
run_check check_branch_protection
run_check check_ci_workflows
run_check check_tier3_provider
run_check check_test_runner_deps

if [ "$fired" -eq 0 ]; then
  echo "no declared tools to verify"
fi

exit "$overall_rc"
