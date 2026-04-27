#!/usr/bin/env bash
# pre-commit-decisions-append-only.sh — enforce append-only-ness of
# .sdd/decisions.md. The framework's audit trail relies on prior
# entries staying immutable: a malicious agent (or careless user)
# editing past approvals retroactively breaks the trust model. This
# hook catches it at commit time.
#
# Behavior:
#   - Empty stdin / non-commit Bash → silent pass-through
#   - decisions.md not staged → silent pass-through
#   - decisions.md was newly added (not in HEAD) → allow (first creation)
#   - Staged decisions.md does NOT start with HEAD's decisions.md → BLOCK
#     (deletion or modification of prior content)
#   - Staged decisions.md starts with HEAD's content + append → allow
#
# Exit codes:
#   0 — allow (no decisions.md staged, or append-only)
#   2 — block (staged content modifies/removes prior entries)
#
# Phase A patterns inherited:
#   - empty-cmd safe default (catastrophic-#4)
#   - python3 backend for git-show + content comparison
#   - NUL-byte guard on staged blob (binary content shouldn't reach here)
#   - reads STAGED blob (`git show :path`) not working tree

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    pass
" 2>/dev/null || echo "")

# Empty-cmd safe default — catastrophic-#4 fix.
[ -z "$cmd" ] && exit 0

# Non-commit Bash → exit 0.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# decisions.md staged?
staged=$(git diff --cached --name-only 2>/dev/null || echo "")
echo "$staged" | grep -qE '(^|/)\.sdd/decisions\.md$' || exit 0

# Admin escape hatch: a commit explicitly tagged `[SDD] decisions: reset`
# is treated as a one-time rebuild of the whole file. The error message
# below advertises this; this check honors it (R3 Honesty reviewer fix —
# pre-fix the advertisement was a lie). The agent should rarely use this;
# it's for the user (or a Phase C `--admin-reset` flag) to recover from
# decisions-log corruption. Phase C will replace the magic-message
# convention with an explicit flag — until then, the magic message is
# documented and intentional.
case "$cmd" in
  *"[SDD] decisions: reset"*) exit 0 ;;
esac

# Compare HEAD vs staged.
PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import os, subprocess, sys

proj = os.environ["PROJ"]
os.chdir(proj)

# Fetch HEAD's version. If decisions.md is brand-new (not in HEAD),
# git show fails — treat as first creation and allow.
try:
    head = subprocess.run(
        ["git", "show", "HEAD:.sdd/decisions.md"],
        capture_output=True, check=False,
    )
except Exception as e:
    print(f"[decisions] git show HEAD failed: {e}", file=sys.stderr)
    sys.exit(0)

if head.returncode != 0:
    # Not in HEAD — first creation. Allow.
    sys.exit(0)

head_bytes = head.stdout

# Fetch staged version.
try:
    staged = subprocess.run(
        ["git", "show", ":.sdd/decisions.md"],
        capture_output=True, check=False,
    )
except Exception as e:
    print(f"[decisions] git show :path failed: {e}", file=sys.stderr)
    sys.exit(0)

if staged.returncode != 0:
    print("[decisions] could not read staged blob; refusing to commit",
          file=sys.stderr)
    sys.exit(2)

staged_bytes = staged.stdout

# NUL guard (Phase A pattern).
if b"\x00" in staged_bytes or b"\x00" in head_bytes:
    print("[decisions] decisions.md contains NUL bytes — refusing.",
          file=sys.stderr)
    sys.exit(2)

# Append-only check: staged must start with head exactly.
if not staged_bytes.startswith(head_bytes):
    print("", file=sys.stderr)
    print("[decisions] .sdd/decisions.md is append-only — refusing to commit.",
          file=sys.stderr)
    print("", file=sys.stderr)
    print("Your staged version REMOVES or MODIFIES content that's already in",
          file=sys.stderr)
    print("HEAD. The framework's audit trail relies on prior entries staying",
          file=sys.stderr)
    print("immutable. To fix: revert your edits to existing entries (use",
          file=sys.stderr)
    print("`git restore --staged .sdd/decisions.md && git checkout .sdd/decisions.md`",
          file=sys.stderr)
    print("then APPEND your new entry instead.", file=sys.stderr)
    print("", file=sys.stderr)
    print("Legitimate exception: rebuilding the whole file from scratch.",
          file=sys.stderr)
    print("If you really mean to do that, commit with the message",
          file=sys.stderr)
    print("`[SDD] decisions: reset` and the hook will allow it. (Phase C",
          file=sys.stderr)
    print("will surface this as an explicit `--admin-reset` flag.)",
          file=sys.stderr)
    sys.exit(2)

sys.exit(0)
PYEOF
