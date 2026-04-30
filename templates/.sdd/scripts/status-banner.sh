#!/usr/bin/env bash
# status-banner.sh — render the active-feature banner for /status.
#
# Single source of truth for the parsing + banner logic that /status's
# slash-command body needs. Extracted so both `/status` and the test
# harness exercise the same code path — drift can't hide behind copy-
# pasted shell. (CodeRabbit cycle-7 finding: tests were validating
# duplicated logic, not the shipped command.)
#
# Input:  resolve-active.sh JSON on stdin (or use `--from-resolver`
#         to invoke the resolver internally and read its output).
# Output: 1-N lines of plain-English banner text on stdout.
# Exit:   0 always — the banner is informational, not a gate.
#
# Why a separate script rather than just sourcing a function: keeps
# /status.md trivial to read for a non-technical user (one bash call,
# obvious what it does) and gives the test harness a stable
# invocation surface (`bash status-banner.sh < input.json`).

set -uo pipefail

# Allow `--from-resolver` so `/status` doesn't have to pre-pipe
# resolve-active.sh — the helper can do it itself in the common case.
if [ "${1:-}" = "--from-resolver" ]; then
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  resolver="$PROJECT_DIR/.sdd/scripts/resolve-active.sh"
  if [ -f "$resolver" ]; then
    json=$(bash "$resolver" 2>/dev/null || echo '{}')
  else
    json='{}'
  fi
else
  json=$(cat)
fi

command -v python3 >/dev/null 2>&1 || {
  echo "(status-banner: python3 missing — can't render)"
  exit 0
}

# Parse all 5 fields with a single Python invocation. Pipe-separated
# so empty fields don't get collapsed by bash IFS-whitespace handling.
IFS='|' read -r active source branch index_active ambiguous < <(
  echo "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
fields = [d.get(k) or "" for k in ("active", "source", "branch", "index_active")]
amb = "1" if d.get("ambiguous") else "0"
print("|".join(fields + [amb]))
' 2>/dev/null)

# Render. Mirrors the doctrine in CLAUDE.md's "Multi-feature parallel
# work" section. Keep the messages plain-English — non-technical user.
if [ "$ambiguous" = "1" ]; then
  echo "Active source: NONE — branch '$branch' slug matched 2+ work-item folders."
  echo "  The resolver refuses to pick one silently. Rename one of the"
  echo "  matching folders so the slug is unique, or check out a different"
  echo "  branch."
elif [ "$source" = "branch" ]; then
  echo "Active source: branch ($branch) → $active"
  if [ -n "$index_active" ] && [ "$index_active" != "$active" ]; then
    echo "  Note: INDEX.md **Active:** points at $index_active — drift is OK in"
    echo "        multi-worktree work. The branch wins. Switch branches to"
    echo "        switch features, no manual INDEX.md edit needed."
  fi
elif [ "$source" = "index" ]; then
  if [ -n "$branch" ]; then
    echo "Active source: INDEX.md (branch '$branch' is not an SDD branch) → $active"
  else
    echo "Active source: INDEX.md → $active"
  fi
else
  # source = "none" (and ambiguous already handled above). Three sub-
  # cases: broken INDEX pointer, scaffold-pending SDD branch, non-SDD
  # branch / fresh project.
  if [ -n "$index_active" ] && [ "$active" = "" ]; then
    echo "Active source: NONE — INDEX.md **Active:** points at \`$index_active\` but"
    echo "  the folder doesn't exist (or has no spec.md inside). Either:"
    echo "  - run /start to scaffold a new work item, or"
    echo "  - edit INDEX.md to point at a real folder, or"
    echo "  - check out an SDD-style branch (sdd/<id>-<slug>) whose folder exists."
  elif [ -n "$branch" ]; then
    case "$branch" in
      sdd/[0-9]*-*)
        echo "Active source: NONE — current branch '$branch' is SDD-shaped, but"
        echo "  no matching work-item folder with spec.md exists yet."
        echo "  Run /start <one-line title> to scaffold it, or switch branches."
        ;;
      *)
        echo "Active source: NONE — current branch '$branch' isn't an SDD-shape"
        echo "  branch (sdd/<id>-<slug>) and INDEX.md doesn't point at any work item."
        echo "  Run /start <one-line title> to scaffold a new feature."
        ;;
    esac
  else
    echo "Active source: NONE — no active work item."
    echo "  Run /start <one-line title> to scaffold one."
  fi
fi
