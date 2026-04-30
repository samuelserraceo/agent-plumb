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
# Why parse + render in one Python process: avoids fragile bash
# field-splitting on a delimiter that JSON values might contain
# (CodeRabbit cycle-10 minor: a `|` inside a JSON value would shift
# bash `read` assignments). Python parses JSON natively; no
# delimiter games are needed.

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

# Parse + render in a single Python invocation. The banner cases
# mirror the doctrine in CLAUDE.md's "Multi-feature parallel work"
# section. Plain-English messages — non-technical user.
#
# Uses `-c` (not heredoc) so stdin stays the piped JSON. With
# `<<'PYEOF'` bash would redirect stdin to the heredoc body and
# Python would read the script bytes as JSON.
printf '%s' "$json" | python3 -c '
import json, re, sys

# Anchored SDD branch shape — must match BRANCH_SLUG_RE in
# resolve-active.sh end-to-end, otherwise "is SDD-shaped" claims
# would diverge from what the resolver actually accepts. Closes
# CR cycle-16 minor: an unanchored `^sdd/[0-9]+-` would call
# `sdd/001-foo/extra` SDD-shaped while the resolver rejects it.
SDD_BRANCH_RE = re.compile(r"^sdd/[0-9]+-[A-Za-z0-9][A-Za-z0-9._-]*$")

try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
# JSON top-level can legally be a non-dict (null, list, scalar). Guard
# so subsequent .get() calls do not raise AttributeError; the script
# must always exit 0 per its docblock.
if not isinstance(d, dict):
    d = {}

active       = d.get("active") or ""
source       = d.get("source") or ""
branch       = d.get("branch") or ""
index_active = d.get("index_active") or ""
ambiguous    = bool(d.get("ambiguous"))

if ambiguous:
    print(f"Active source: NONE — branch \x27{branch}\x27 slug matched 2+ work-item folders.")
    print("  The resolver refuses to pick one silently. Rename one of the")
    print("  matching folders so the slug is unique, or check out a different")
    print("  branch.")
elif source == "branch":
    print(f"Active source: branch ({branch}) → {active}")
    if index_active and index_active != active:
        print(f"  Note: INDEX.md **Active:** points at {index_active} — drift is OK in")
        print("        multi-worktree work. The branch wins. Switch branches to")
        print("        switch features, no manual INDEX.md edit needed.")
elif source == "index":
    # Three sub-cases on branch:
    #  - SDD-shaped branch but no matching folder → INDEX kicked in,
    #    but the user is on a real SDD branch with a missing folder
    #    (not "wrong branch naming"). Tell them the truth.
    #  - non-SDD branch present → "not an SDD branch" is correct.
    #  - no branch (e.g. detached HEAD) → keep it terse.
    if branch and SDD_BRANCH_RE.match(branch):
        print(f"Active source: INDEX.md → {active}")
        print(f"  Note: current branch \x27{branch}\x27 is SDD-shaped, but no matching")
        print("        work-item folder exists yet. Run /start <one-line title>")
        print("        to scaffold it, or switch branches.")
    elif branch:
        print(f"Active source: INDEX.md (branch \x27{branch}\x27 is not an SDD branch) → {active}")
    else:
        print(f"Active source: INDEX.md → {active}")
else:
    # source = "none" (and ambiguous already handled above). Three
    # sub-cases: broken INDEX pointer, scaffold-pending SDD branch,
    # non-SDD branch / fresh project.
    if index_active and not active:
        # Do not suggest /start here -- there is already an INDEX
        # entry, just stale. Scaffolding a NEW feature would leave
        # the broken pointer in place and create a second one. CR
        # cycle-17 minor.
        print(f"Active source: NONE — INDEX.md **Active:** points at `{index_active}` but")
        print("  the folder doesn\x27t exist (or has no spec.md inside). Either:")
        print("  - edit INDEX.md to point at a real folder, or")
        print("  - check out an SDD-style branch (sdd/<id>-<slug>) whose folder exists.")
    elif branch:
        if SDD_BRANCH_RE.match(branch):
            print(f"Active source: NONE — current branch \x27{branch}\x27 is SDD-shaped, but")
            print("  no matching work-item folder with spec.md exists yet.")
            print("  Run /start <one-line title> to scaffold it, or switch branches.")
        else:
            print(f"Active source: NONE — current branch \x27{branch}\x27 isn\x27t an SDD-shape")
            print("  branch (sdd/<id>-<slug>) and INDEX.md doesn\x27t point at any work item.")
            print("  Run /start <one-line title> to scaffold a new feature.")
    else:
        print("Active source: NONE — no active work item.")
        print("  Run /start <one-line title> to scaffold one.")
'
