#!/usr/bin/env bash
# pre-commit-cofile-block.sh — Class-based cofile block.
#
# Refuses commits that stage files from BOTH a CLAIM class (verification.json,
# .git/sdd/approvals.jsonl) AND a POLICY class (manifest, playbooks, actions,
# extensions, scripts, hooks, settings, CLAUDE.md).
#
# Each cross-class pair represents "the agent could weaken policy in commit N
# and ship the matching claim in commit N+1." The block forces those
# modifications into separate auditable commits.
#
# Wires up as a Claude Code PreToolUse hook on Bash:
#   { "tool_name": "Bash", "tool_input": { "command": "git commit ..." } }
#
# Exits:
#   0 — allow (no commit, or no cross-class staging)
#   2 — block (cross-class detected; stderr explains)
#
# Phase A patterns inherited:
#   - empty-cmd safe default (catastrophic-#4 fix)
#   - python3 hard requirement (already required by moat)
#   - PROJECT_DIR resolution
#   - plain-English error messages
#
# See SCHEMA.md §16 for the canonical class definitions.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

# Parse stdin from Claude Code.
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Empty-cmd safe default — Phase A pattern.
[ -z "$cmd" ] && exit 0

# Not a git commit? Allow.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Inside a git repo?
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Staged files (one per line; --name-only).
staged=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
[ -z "$staged" ] && exit 0

# Hand off to python3 for class membership testing.
# Python's regex is more readable than bash globs for this many patterns.
# Pass staged files via env var. Cannot pipe to `python3 -` because the
# heredoc already consumes stdin (it's the script source).
result=$(SDD_STAGED="$staged" python3 <<'PYEOF'
import os, re

# Class A — CLAIM files (state about verification)
CLAIM_PATTERNS = [
    re.compile(r"(^|/)verification\.json$"),
    re.compile(r"^\.git/sdd/approvals\.jsonl$"),
]

# Class B — POLICY files (rules being verified against)
POLICY_PATTERNS = [
    re.compile(r"^\.sdd/\.cache/manifest\.json$"),
    re.compile(r"^\.sdd/playbooks/[^/]+\.md$"),
    re.compile(r"^\.sdd/actions/[^/]+\.md$"),
    re.compile(r"^\.sdd/extensions/[^/]+\.md$"),
    re.compile(r"^\.sdd/scripts/[^/]+\.sh$"),
    re.compile(r"^\.claude/hooks/[^/]+\.sh$"),
    re.compile(r"^\.claude/settings\.json$"),
    re.compile(r"^CLAUDE\.md$"),
]

claim_files = []
policy_files = []
for line in os.environ.get("SDD_STAGED", "").splitlines():
    line = line.strip()
    if not line:
        continue
    if any(pat.search(line) for pat in CLAIM_PATTERNS):
        claim_files.append(line)
    if any(pat.search(line) for pat in POLICY_PATTERNS):
        policy_files.append(line)

if claim_files and policy_files:
    print("BLOCK")
    print("CLAIM:")
    for f in claim_files:
        print(f"  {f}")
    print("POLICY:")
    for f in policy_files:
        print(f"  {f}")
else:
    print("ALLOW")
PYEOF
)

# Result is "ALLOW\n..." or "BLOCK\nCLAIM:...\nPOLICY:..."
case "$result" in
  ALLOW*)
    exit 0
    ;;
  BLOCK*)
    cat >&2 <<EOF
[SDD cofile-block] This commit stages files from both classes:

$(printf '%s\n' "$result" | sed -n '2,$p')

Why this is blocked:
  Each cross-class pair lets a tampered policy ship with a matching
  fabricated claim in the same atomic commit. SDD requires policy
  changes and claim changes to be SEPARATE auditable commits.

How to fix (pick one):
  1. Unstage the policy files, commit only the claim:
       git reset HEAD <policy-files-listed-above>
       git commit
     Then commit the policy changes separately.

  2. Unstage the claim, commit only the policy:
       git reset HEAD <claim-files-listed-above>
       git commit
     Then re-run /next so the framework regenerates the claim against
     the new policy, and commit the claim separately.

See SCHEMA.md §16 for the full class definitions.
EOF
    exit 2
    ;;
  *)
    # Unexpected python3 output — fail safe (allow).
    exit 0
    ;;
esac
