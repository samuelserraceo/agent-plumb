#!/usr/bin/env bash
# verify-stack.sh — F027 post-wizard reality check.
#
# /sdd-setup records the user's tool answers in config.md / stack.md
# but never verifies the answers reflect reality. This script runs at
# the end of /sdd-setup (or as a standalone /sdd-verify-stack command)
# and probes each declared tool against actual state:
#
#   1. CodeRabbit App      — `gh api repos/<r>/installation` if review.bot=coderabbit
#   2. Ollama endpoint     — HEAD/GET if mcp.tier3.enabled+provider=ollama
#   3. OpenAI key          — OPENAI_API_KEY env-var presence (followup) if provider=openai
#   4. CI workflow files   — `.github/workflows/*.yml` presence check
#   5. Branch protection   — `gh api repos/<r>/branches/main/protection` if user opted in
#   6. Test runner deps    — runner name in package.json / pyproject.toml (followup)
#
# Each check prints one line: `[verify-stack] <check>: <ok|warn|fail> — <message>`.
# Exit code: 0 if no FAIL entries (warnings allowed); 1 if any FAIL.
# All gh-api calls gracefully skip if `gh` not on PATH.
#
# Usage:
#   verify-stack.sh             — scan active project's config.md, run all checks
#   verify-stack.sh --json      — emit JSON report (one line per check) for tooling
#
# Anti-theatre: every claim this script prints is mechanical (real API
# call OR file-presence check); no judgement-based claims. CR cycle 1
# may surface false positives — the goal is to MAKE the gap visible
# at setup time, not to over-claim correctness.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_DIR/.sdd/config.md"
JSON_MODE=0

if [ "${1:-}" = "--json" ]; then JSON_MODE=1; fi

# Plain-English emit. The check_name + state + message are all
# script-controlled, no user input interpolated.
emit() {
  local check="$1" state="$2" msg="$3"
  if [ "$JSON_MODE" -eq 1 ]; then
    printf '{"check":"%s","state":"%s","message":"%s"}\n' "$check" "$state" "$msg"
  else
    printf '[verify-stack] %s: %s — %s\n' "$check" "$state" "$msg"
  fi
}

# Defensive shorthand: did we manage to read config.md?
if [ ! -f "$CONFIG" ]; then
  emit "config-presence" "fail" "no .sdd/config.md found at $CONFIG"
  exit 1
fi

# Read config keys via inline Python. Same pattern as
# get-injection-budget.sh + check-cr-convergence.sh.
config_get() {
  CONFIG="$CONFIG" KEY="$1" python3 <<'PYEOF' 2>/dev/null || true
import os, re, sys
config_path = os.environ["CONFIG"]
key = os.environ["KEY"]
try:
    with open(config_path, "rb") as f:
        text = f.read().decode("utf-8", errors="replace")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not m:
        sys.exit(0)
    try:
        import yaml
        fm = yaml.safe_load(m.group(1)) or {}
    except ImportError:
        sys.exit(0)
    # Walk dotted key (e.g. parameters.review.bot)
    cur = fm
    for part in key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            sys.exit(0)
        cur = cur[part]
    if cur is None or cur is False:
        sys.exit(0)
    if isinstance(cur, bool):
        print("true" if cur else "false")
    else:
        print(str(cur))
except OSError:
    sys.exit(0)
PYEOF
}

FAILED=0

# ─── Check 1: CodeRabbit App ─────────────────────────────────────────
review_bot="$(config_get parameters.review.bot)"
if [ "$review_bot" = "coderabbit" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    emit "coderabbit-app" "warn" "gh CLI not on PATH; can't verify CR App install — install gh + run again"
  else
    # The actual repo is detected from the working directory's git remote.
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
    if [ -z "$repo" ]; then
      emit "coderabbit-app" "warn" "not inside a GitHub remote; can't probe CR install"
    else
      # Probe the App. 200 = installed; 404 = not installed.
      if gh api "repos/$repo/installation" >/dev/null 2>&1; then
        emit "coderabbit-app" "ok" "CodeRabbit App installed on $repo"
      else
        emit "coderabbit-app" "fail" "CodeRabbit App NOT installed on $repo — install at https://github.com/marketplace/coderabbit"
        FAILED=$((FAILED + 1))
      fi
    fi
  fi
fi

# ─── Check 2: Ollama endpoint (if Tier 3 enabled + ollama provider) ──
tier3_enabled="$(config_get parameters.mcp.tier3.enabled)"
if [ "$tier3_enabled" = "true" ]; then
  tier3_provider="$(config_get parameters.mcp.tier3.provider)"
  tier3_endpoint="$(config_get parameters.mcp.tier3.endpoint)"
  if [ "$tier3_provider" = "ollama-chat" ] || [ "$tier3_provider" = "ollama-native" ]; then
    if [ -z "$tier3_endpoint" ]; then
      emit "ollama-endpoint" "warn" "Tier 3 enabled with Ollama but endpoint is empty — set parameters.mcp.tier3.endpoint"
    elif ! command -v curl >/dev/null 2>&1; then
      emit "ollama-endpoint" "warn" "curl not on PATH; can't probe Ollama at $tier3_endpoint"
    else
      # 2-second connect timeout — don't hang the wizard if Ollama is down.
      if curl --max-time 2 --silent --output /dev/null --head "$tier3_endpoint" 2>/dev/null; then
        emit "ollama-endpoint" "ok" "Ollama reachable at $tier3_endpoint"
      else
        emit "ollama-endpoint" "fail" "Ollama NOT reachable at $tier3_endpoint — start ollama (\`ollama serve\`) or update endpoint"
        FAILED=$((FAILED + 1))
      fi
    fi
  fi
fi

# ─── Check 3: OpenAI key (if Tier 3 enabled + openai provider) ──────
# Extends F027's Tier 3 reality-check to the OpenAI path. Cannot
# validate the key without a paid call; probes env-var presence only.
if [ "$tier3_enabled" = "true" ]; then
  case "$tier3_provider" in
    openai|openai-*)
      if [ -n "${OPENAI_API_KEY:-}" ]; then
        emit "openai-key" "ok" "OPENAI_API_KEY env-var present (key-validity not probed — would need a paid call)"
      else
        emit "openai-key" "fail" "Tier 3 OpenAI declared but OPENAI_API_KEY env-var NOT set — export it in your shell rc"
        FAILED=$((FAILED + 1))
      fi
      ;;
  esac
fi

# ─── Check 4: CI workflow files ──────────────────────────────────────
wf_dir="$PROJECT_DIR/.github/workflows"
if [ -d "$wf_dir" ]; then
  wf_count=$(find "$wf_dir" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) 2>/dev/null | wc -l | tr -d ' ')
  if [ "$wf_count" -gt 0 ]; then
    emit "ci-workflows" "ok" "$wf_count workflow file(s) in .github/workflows/"
  else
    emit "ci-workflows" "warn" ".github/workflows/ exists but contains no .yml/.yaml files"
  fi
else
  emit "ci-workflows" "warn" "no .github/workflows/ directory — CI checks won't fire"
fi

# ─── Check 5: Branch protection (optional, skipped if no gh) ─────────
if command -v gh >/dev/null 2>&1; then
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
  if [ -n "$repo" ]; then
    if gh api "repos/$repo/branches/main/protection" >/dev/null 2>&1; then
      emit "branch-protection" "ok" "main branch protection rule found on $repo"
    else
      emit "branch-protection" "warn" "main branch protection NOT configured on $repo — consider enabling required checks"
    fi
  fi
fi

# ─── Check 6: Test runner deps in package.json / pyproject.toml ─────
# Extends F027 with the test-runner-deps check from issue #165 step 6.
# Reads "Test runner:" line from stack.md, greps the project's
# package manifest for the declared runner name.
stack_file="$PROJECT_DIR/.sdd/stack.md"
if [ -f "$stack_file" ]; then
  # Strict match: requires a colon AND a non-empty value (e.g. "Test runner: Vitest").
  # Plain prose mentions like "nothing about a test runner here" do not match.
  runner=$(grep -iE "[Tt]est[[:space:]]+runner[[:space:]]*:[[:space:]]+[^[:space:]]" "$stack_file" 2>/dev/null \
    | head -1 \
    | sed -E 's/.*[Tt]est[[:space:]]+runner[[:space:]]*:[[:space:]]*//' \
    | awk '{print $1}' \
    | tr -d ',.;:' \
    | tr '[:upper:]' '[:lower:]')
  if [ -n "$runner" ]; then
    found=0
    if [ -f "$PROJECT_DIR/package.json" ] && grep -Fqi "\"$runner\"" "$PROJECT_DIR/package.json"; then
      emit "test-runner-deps" "ok" "test runner '$runner' declared in package.json"
      found=1
    fi
    if [ "$found" -eq 0 ] && [ -f "$PROJECT_DIR/pyproject.toml" ] && grep -Fqi "$runner" "$PROJECT_DIR/pyproject.toml"; then
      emit "test-runner-deps" "ok" "test runner '$runner' declared in pyproject.toml"
      found=1
    fi
    if [ "$found" -eq 0 ]; then
      if [ -f "$PROJECT_DIR/package.json" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
        emit "test-runner-deps" "fail" "test runner '$runner' NOT in package.json / pyproject.toml — npm install --save-dev $runner (or language equivalent)"
        FAILED=$((FAILED + 1))
      else
        emit "test-runner-deps" "warn" "test runner '$runner' declared in stack.md but no package.json / pyproject.toml found"
      fi
    fi
  fi
fi

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
