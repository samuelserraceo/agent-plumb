#!/usr/bin/env bash
# pre-commit-no-theatre.sh — refuse commits whose staged spec.md
# contains theatre claims without an adjacent verifier annotation.
# Closes #111.
#
# Foundation 3 of SDD is "Never assume — always check." A theatre
# claim is a sentence that LOOKS like an enforced guard but isn't:
#   - "refuses past 1KB" — without a test, what enforces it?
#   - "cost_limit_usd: 0.50" — framework can't price external services
#   - "≥80% correctly" — by what scoring rule, on what test set?
#   - "always verifies in SHIP" — by what named test or fixture?
#
# Sam caught the v1.1 Tier 3 spec drafting this kind of claim FOUR
# times in one feature. The doctrine in CLAUDE.md was necessary but
# not enforcing — this hook is the mechanical layer.
#
# This hook delegates to .sdd/scripts/lint-no-theatre.sh, which scans
# spec.md for token categories (numerical, currency, enforcement,
# quality) and refuses each match unless an adjacent annotation is
# present:
#
#   {verify-by: <test-id>}    — points at a test/fixture/AC
#   {best-effort: <who>}      — judgement-based, named human reviewer
#   {prod-only: <reason>}     — verifiable only against live infra
#
# Wires up as a Claude Code PreToolUse hook on Bash, AND as a pre-
# commit hook for direct git commits.
#
# Exits:
#   0 — allow commit
#   2 — block (theatre found; stderr explains)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

# Parse stdin for git commit command (Claude Code PreToolUse shape).
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Fall back to direct invocation: if no stdin, treat as a real
# pre-commit hook run.
[ -z "$cmd" ] && cmd="git commit"

# Not a git commit? Allow.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Locate the lint script. If absent (e.g. older project that hasn't
# picked up this hook's companion), allow the commit — the user is
# on a pre-#111 framework version. The CI gate will still catch
# theatre on the PR.
LINT="$PROJECT_DIR/.sdd/scripts/lint-no-theatre.sh"
if [ ! -x "$LINT" ]; then
  exit 0
fi

# Find staged spec.md files.
staged_specs=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null \
  | grep -E '(^|/)spec\.md$' || true)
[ -z "$staged_specs" ] && exit 0

# For each staged spec, write its STAGED content (not working-tree)
# to a tempfile and run the lint against it. We use staged content
# because that's what's actually going into the commit; working-tree
# content might have un-staged fixes that don't apply.

found_problems=""
while IFS= read -r spec; do
  [ -z "$spec" ] && continue
  if ! staged_content=$(git show ":$spec" 2>/dev/null); then
    cat >&2 <<EOF
[no-theatre] could not read staged content for $spec — refusing commit.
This is unexpected (the file is staged but git show failed). Check
git status / git ls-files --stage and re-stage if necessary.
EOF
    exit 2
  fi
  [ -z "$staged_content" ] && continue

  tmp=$(mktemp -t sdd-no-theatre.XXXXXX) || exit 2
  printf '%s' "$staged_content" > "$tmp"
  lint_output=$(bash "$LINT" "$tmp" 2>&1)
  lint_ec=$?
  rm -f "$tmp"

  if [ "$lint_ec" -ne 0 ]; then
    # Replace the temp path with the real spec path in the output so
    # the user sees a meaningful location.
    cleaned=$(printf '%s' "$lint_output" | sed -E "s|$tmp|$spec|g")
    found_problems="${found_problems}
${cleaned}
"
  fi
done <<< "$staged_specs"

if [ -n "$found_problems" ]; then
  cat >&2 <<EOF
[no-theatre] commit refused — theatre claims in staged spec.md.

The framework's "everything specced is verifiable" promise (per
CLAUDE.md foundation 3 + the anti-theatre doctrine in #111) says:
if you ship a sentence that LOOKS like an enforced guard, you need
a verifier annotation telling reviewers what proves it.

Three annotation shapes the framework accepts:

  {verify-by: T-NNN}     — points at a test or fixture that
                           mechanically proves the claim
  {best-effort: <who>}   — admits the claim is human-judged
                           (named reviewer, e.g. Sam at SHIP)
  {prod-only: <why>}     — claim is real but only verifiable
                           against live infrastructure

Add the annotation on the same line OR within 3 lines below the
flagged token. Or soften the wording so the claim isn't there.

Findings:
${found_problems}

This commit is BLOCKED. Re-run once you've added annotations or
softened the wording.
EOF
  exit 2
fi

exit 0
