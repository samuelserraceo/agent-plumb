#!/usr/bin/env bash
# check-cr-convergence.sh — F026 SHIP gate (closes #166).
#
# Reads parameters.review.bot + parameters.review.bypass_cr_convergence
# from .sdd/config.md. If a CR bot is configured AND the bypass flag
# is not set, queries gh api for the PR's reviews and refuses (exit 1)
# when the latest review on the latest commit SHA is CHANGES_REQUESTED
# or absent. Closes the silent-ship-past-CR-red failure mode the v1.4.x
# release sequence surfaced (PRs #158 and #161 merged with CR
# CHANGES_REQUESTED via admin-merge with no machine check).
#
# Exit:
#   0 — converged (APPROVED / COMMENTED), or skip (no bot), or bypass
#   1 — refused (CHANGES_REQUESTED at latest SHA, or no review at latest SHA)
#   2 — usage / IO error (no PR number, gh unauthenticated, etc.)
#
# Bash 3.2 compatible. No bashisms beyond bash 3.2's reach.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || { echo "[check-cr-convergence] can't cd to project root" >&2; exit 2; }

CONFIG=".sdd/config.md"
if [ ! -f "$CONFIG" ]; then
  echo "[check-cr-convergence] $CONFIG not found — not an SDD project?" >&2
  exit 2
fi

# ─── Read parameters.review.bot / .bypass_cr_convergence ─────────
# YAML is in the frontmatter (between the two `---` markers). awk to
# extract the frontmatter body, then read the two keys with a simple
# nested awk that respects 2-space + 4-space indentation under
# `parameters:` → `review:`.
BOT_RAW=$(awk '
  /^---$/ { fm = fm + 1; next }
  fm == 1
' "$CONFIG" | awk '
  /^parameters:/        { in_params = 1; next }
  in_params && /^[^ ]/  { in_params = 0; in_review = 0 }
  in_params && /^  review:/ { in_review = 1; next }
  in_params && in_review && /^  [^ ]/ { in_review = 0 }
  in_params && in_review && /^    bot:/ {
    line = $0
    sub(/^    bot:[[:space:]]*/, "", line)
    print line
    exit
  }
')
BYPASS_RAW=$(awk '
  /^---$/ { fm = fm + 1; next }
  fm == 1
' "$CONFIG" | awk '
  /^parameters:/        { in_params = 1; next }
  in_params && /^[^ ]/  { in_params = 0; in_review = 0 }
  in_params && /^  review:/ { in_review = 1; next }
  in_params && in_review && /^  [^ ]/ { in_review = 0 }
  in_params && in_review && /^    bypass_cr_convergence:/ {
    line = $0
    sub(/^    bypass_cr_convergence:[[:space:]]*/, "", line)
    print line
    exit
  }
')

# Strip surrounding quotes + whitespace from the raw values (bash 3.2 way).
strip_quotes() {
  local s="$1"
  # Trim leading/trailing whitespace
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  # Trim surrounding double quotes
  if [ "${s#\"}" != "$s" ] && [ "${s%\"}" != "$s" ]; then
    s="${s#\"}"
    s="${s%\"}"
  fi
  # Trim surrounding single quotes
  if [ "${s#\'}" != "$s" ] && [ "${s%\'}" != "$s" ]; then
    s="${s#\'}"
    s="${s%\'}"
  fi
  echo "$s"
}

BOT=$(strip_quotes "$BOT_RAW")
BYPASS=$(strip_quotes "$BYPASS_RAW")

# ─── Skip path: no bot configured ───────────────────────────────
if [ -z "$BOT" ]; then
  echo "[verify-cr-convergence] skipped — parameters.review.bot is empty (no CR bot configured)." >&2
  exit 0
fi

# ─── Bypass path: operator opted out ────────────────────────────
if [ "$BYPASS" = "true" ]; then
  echo "[verify-cr-convergence] bypassed — parameters.review.bypass_cr_convergence is true. Record the rationale in .sdd/decisions.md." >&2
  exit 0
fi

# ─── Resolve PR number ──────────────────────────────────────────
# Try .sdd/<active>/.pr-number first (written by push-pr action).
PR=""
if [ -f .sdd/INDEX.md ]; then
  ACTIVE=$(awk '/^\*\*Active:\*\*/{print $2; exit}' .sdd/INDEX.md 2>/dev/null)
  if [ -n "$ACTIVE" ] && [ -f ".sdd/$ACTIVE/.pr-number" ]; then
    PR=$(tr -d '[:space:]' <".sdd/$ACTIVE/.pr-number")
  fi
fi
# Fallback: gh pr view --json number against the current branch.
if [ -z "$PR" ]; then
  PR=$(gh pr view --json number -q .number 2>/dev/null || true)
  PR=$(echo "$PR" | tr -d '[:space:]')
fi
if [ -z "$PR" ]; then
  echo "[verify-cr-convergence] could not find a PR number — looked at .sdd/<active>/.pr-number and 'gh pr view --json number'. Run /ship's push-pr first." >&2
  exit 2
fi

# ─── Resolve owner/repo + latest SHA ────────────────────────────
REPO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name' 2>/dev/null || true)
if [ -z "$REPO" ]; then
  # The script's stub-gh test path returns owner/name on `gh repo view`
  # without `--json` (simpler shape). Try the simple form as fallback.
  REPO=$(gh repo view 2>/dev/null | head -1 | tr -d '[:space:]' || true)
fi
if [ -z "$REPO" ]; then
  echo "[verify-cr-convergence] could not resolve owner/repo via gh — is gh authenticated?" >&2
  exit 2
fi

SHA=$(git rev-parse HEAD 2>/dev/null || true)
if [ -z "$SHA" ]; then
  echo "[verify-cr-convergence] could not read latest commit SHA via 'git rev-parse HEAD'." >&2
  exit 2
fi

# ─── Fetch reviews ──────────────────────────────────────────────
REVIEWS_JSON=$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate 2>/dev/null || true)
if [ -z "$REVIEWS_JSON" ]; then
  echo "[verify-cr-convergence] no review data returned by gh api repos/$REPO/pulls/$PR/reviews — refusing on absent review." >&2
  exit 1
fi

# ─── Find latest review on the latest SHA from the configured bot ──
# Match the bot's login both as the configured name (`coderabbit`) and
# as the canonical GitHub form (`coderabbitai[bot]`). Reviewers post as
# `<name>[bot]` for app integrations.
#
# Implementation: python3 ships with bash everywhere SDD runs (other
# scripts in templates/.sdd/scripts/ use it). One-pass parser keeps the
# script readable and the parse robust.
LATEST_STATE=$(BOT="$BOT" SHA="$SHA" REVIEWS_JSON="$REVIEWS_JSON" python3 <<'PYEOF' 2>/dev/null || echo ""
import json, os, sys
bot = os.environ["BOT"].lower()
sha = os.environ["SHA"]
try:
    data = json.loads(os.environ["REVIEWS_JSON"])
except Exception:
    sys.exit(0)
if not isinstance(data, list):
    sys.exit(0)
# Bot login matches if the configured name is a substring (case-fold)
# of the review user's login. `coderabbit` matches `coderabbitai`,
# `coderabbitai[bot]`, etc. Keeps the check honest without forcing
# downstream projects to know the canonical login format.
candidates = []
for r in data:
    user = ((r.get("user") or {}).get("login") or "").lower()
    if bot in user:
        if r.get("commit_id") == sha:
            candidates.append(r)
if not candidates:
    sys.exit(0)
# Latest by submitted_at; if tied / missing, fall back to id.
def key(r):
    return (r.get("submitted_at") or "", r.get("id") or 0)
latest = sorted(candidates, key=key)[-1]
print(latest.get("state", ""))
PYEOF
)

# ─── Decide ─────────────────────────────────────────────────────
case "$LATEST_STATE" in
  APPROVED|COMMENTED)
    echo "[verify-cr-convergence] CR review state $LATEST_STATE on commit $SHA — converged." >&2
    exit 0
    ;;
  CHANGES_REQUESTED)
    cat >&2 <<EOF
[verify-cr-convergence] CodeRabbit review state CHANGES_REQUESTED on commit $SHA (PR #$PR).
Either push a fix that resolves the findings (re-run /next after pushing — the gate reads HEAD at runtime), or set parameters.review.bypass_cr_convergence: true in .sdd/config.md and record the override in .sdd/decisions.md.
EOF
    exit 1
    ;;
  "")
    cat >&2 <<EOF
[verify-cr-convergence] no CR review found from "$BOT" on commit $SHA (PR #$PR). The gate refuses on absent reviews — comment '@coderabbitai full review' on the PR, wait for the review, then re-run /next.
EOF
    exit 1
    ;;
  *)
    echo "[verify-cr-convergence] unexpected CR review state '$LATEST_STATE' on $SHA — refusing." >&2
    exit 1
    ;;
esac
