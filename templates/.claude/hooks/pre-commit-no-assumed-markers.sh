#!/usr/bin/env bash
# pre-commit-no-assumed-markers.sh — refuse commits that leave assumption
# placeholders in the staged spec.md (closes #72: mechanical never-assume).
#
# Foundation 3 of SDD is "Never assume — always check." The framework
# enforces this in many places (USER-LED tags, multi-choice + free-form
# escape, section-locking moat, edge-case-sweep). But until v0.13.x
# there was no mechanical check that says "you left a placeholder in
# spec.md — go ask the user before committing."
#
# This hook scans staged spec.md content for placeholder tokens that
# indicate the agent silently invented content instead of asking. The
# tokens it refuses:
#
#   - (assumed)        — agent's "I guessed" marker
#   - (TBD)            — "to be decided", left unfilled
#   - (?)              — agent's question to itself
#   - (unclear)        — agent flagged it as ambiguous and proceeded anyway
#   - <FILL IN>        — copy-paste placeholder
#   - <PLACEHOLDER>    — same shape
#   - <TODO>           — same shape
#   - <YOUR_X_HERE>    — common template-leak shape
#
# Plus a heuristic: any `[ ]` row that has been replaced with `[?]` is a
# sign the agent didn't get a confident answer and proceeded.
#
# Wires up as a Claude Code PreToolUse hook on Bash, AND as a pre-commit
# hook for direct git commits.
#
# Exits:
#   0 — allow commit
#   2 — block (placeholder found; stderr explains)
#
# How to bypass legitimately:
# If you genuinely want a placeholder to ship (e.g., as a documented
# follow-up), use a different shape that the hook doesn't refuse:
#   - "to-be-decided in next iteration"  (prose, no parens)
#   - "deferred — see issue #N"
# These read as deliberate; the parenthesised tokens read as accidental.

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

# Find staged spec.md files.
staged_specs=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null \
  | grep -E '(^|/)spec\.md$' || true)
[ -z "$staged_specs" ] && exit 0

# Patterns to refuse. Use grep -E with explicit alternation. Each pattern
# is a literal token the agent might leave when it has assumed.
PATTERNS='\(assumed\)|\(TBD\)|\(\?\)|\(unclear\)|<FILL IN>|<PLACEHOLDER>|<TODO>|<YOUR_[A-Z_]+_HERE>|^\s*-\s*\[\?\]'

found_problems=""
while IFS= read -r spec; do
  [ -z "$spec" ] && continue
  # Read the staged blob (not the working-tree file — what's actually
  # going into the commit). The file IS staged (it came from
  # `git diff --cached --name-only` above), so git show should
  # succeed; if it fails, that's an unexpected condition and we
  # refuse rather than silently skipping a file that might still
  # contain placeholders.
  if ! staged_content=$(git show ":$spec" 2>/dev/null); then
    cat >&2 <<EOF
[no-assumed-markers] could not read staged content for $spec — refusing commit.
This is unexpected (the file is staged but git show failed). Check
git status / git ls-files --stage and re-stage if necessary.
EOF
    exit 2
  fi
  # An intentionally empty staged file passes (nothing to scan).
  [ -z "$staged_content" ] && continue
  matches=$(printf '%s' "$staged_content" | grep -nE "$PATTERNS" || true)
  if [ -n "$matches" ]; then
    found_problems="${found_problems}
${spec}:
${matches}
"
  fi
done <<< "$staged_specs"

if [ -n "$found_problems" ]; then
  cat >&2 <<EOF
[no-assumed-markers] commit refused — placeholder tokens found in staged spec.md.

The framework's "never assume" doctrine (foundation 3) says: if you
don't know the answer with confidence, ASK the user. Don't fill the
blank with (assumed), (TBD), (?), or any of the placeholder tokens
listed below — that ships uncertainty into the audit trail without
flagging it for the user.

Tokens found:
${found_problems}

How to fix:
  - If you have a real answer: replace the placeholder with the actual content.
  - If you don't have a real answer: ask the user. Don't guess.
  - If the placeholder is a deliberate "we'll come back to this":
    use prose without parens, e.g. "deferred to next iteration"
    or "see issue #N". The hook only refuses parenthesised tokens
    and \`<UPPERCASE_TEMPLATE>\` shapes.

This commit is BLOCKED. Re-run after replacing the tokens with real
content (or with a prose deferral).
EOF
  exit 2
fi

exit 0
