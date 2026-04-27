#!/usr/bin/env bash
# pre-commit-touches.sh — SYNC step enforcement for the 4-step inner loop.
#
# When a user commits work for the active sub-action (signaled by
# staging spec.md), this hook reads the active sub-action's frontmatter
# `touches:` declaration and refuses the commit if any declared file
# isn't also staged. This is the SYNC defense from handoff Section 6:
#
#   "If a sub-action declares it must stage data-model.md, the hook
#    enforces it. Forgetting to stage the sync'd file becomes
#    impossible by accident."
#
# Examples of `touches:` declarations from the v0.8 sub-action library:
#   data-contract.md  → [.sdd/data-model.md]      (schema sync)
#   learn-lessons.md  → [.sdd/patterns.md]        (lesson sync)
#   mark-shipped.md   → [.sdd/INDEX.md]           (state sync)
#   wireframe.md      → [.sdd/features/<id>/wireframe.html]
#
# Behavior:
#   - Empty-cmd safe default (Phase A pattern, catastrophic-#4)
#   - Non-commit Bash → exit 0 (silent pass-through)
#   - No spec.md staged → exit 0 (nothing for SYNC to enforce)
#   - Active sub-action unknown → exit 0 (no INDEX.md, no project, etc.)
#   - Sub-action's `touches:` empty/absent → exit 0
#   - Any declared file missing from staged set → BLOCK (exit 2) with
#     plain-English error naming the file + how to fix
#
# This hook runs AFTER pre-commit-block (which catches open `[ ]`) and
# BEFORE pre-commit-stage-verified (the moat). Order matters: scope
# discipline before moat enforcement.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

# Empty-cmd safe default (Phase A pattern).
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[ -z "$cmd" ] && exit 0

# Non-commit Bash → silent pass-through.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Must be in a git repo.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# What's staged?
staged=$(git diff --cached --name-only 2>/dev/null || echo "")
[ -z "$staged" ] && exit 0

# If NO spec.md is staged, this isn't a sub-action commit — pass through.
# The hook only enforces touches: when the agent is committing sub-action
# work. Other commits (typo fixes, README updates, framework upgrades)
# don't need to honor the active sub-action's touches: declaration.
if ! echo "$staged" | grep -qE '(^|/)spec\.md$'; then
  exit 0
fi

# Read INDEX.md to find the active sub-action slug.
[ -f .sdd/INDEX.md ] || exit 0

# Active blocker line format: `**Active blocker:** §<N> (first sub-action: <slug>)`
# OR `**Active blocker:** <slug>` (alternate forms).
active_slug=$(python3 - <<'PYEOF' 2>/dev/null || echo ""
import re, sys
try:
    with open(".sdd/INDEX.md") as f:
        text = f.read()
except OSError:
    sys.exit(0)
# Try parenthesized form: "(... sub-action: <slug>)"
m = re.search(r"sub-action:\s*([a-z][a-z0-9-]*)", text, re.IGNORECASE)
if m:
    print(m.group(1))
    sys.exit(0)
# Try bare slug after **Active blocker:**
m = re.search(r"\*\*Active blocker:\*\*\s*([a-z][a-z0-9-]+)", text, re.IGNORECASE)
if m:
    print(m.group(1))
PYEOF
)

# If we can't determine the active sub-action, pass through silently.
# (User may be mid-/start, or INDEX.md may be hand-edited, or there's
# no active work item.)
[ -z "$active_slug" ] && exit 0

# Read sub-action frontmatter for touches: declaration.
sa_path=".sdd/subactions/${active_slug}.md"
[ -f "$sa_path" ] || exit 0

touches_files=$(SA_PATH="$sa_path" python3 - <<'PYEOF' 2>/dev/null || echo ""
import os, re, sys
sa_path = os.environ["SA_PATH"]
try:
    with open(sa_path) as f:
        text = f.read()
except OSError:
    sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    sys.exit(0)
try:
    import yaml
    fm = yaml.safe_load(m.group(1))
except Exception:
    sys.exit(0)
touches = fm.get("touches", []) or []
if not isinstance(touches, list):
    sys.exit(0)
for t in touches:
    if isinstance(t, str):
        print(t)
PYEOF
)

# No touches declared → nothing to enforce.
[ -z "$touches_files" ] && exit 0

# For each declared file, check it's in the staged set.
missing=""
while IFS= read -r tf; do
  [ -z "$tf" ] && continue
  # Normalize the touches path for matching. Strip leading slash if any.
  tf_clean="${tf#/}"
  # Templated paths (e.g., wireframe's .sdd/features/<id>/wireframe.html)
  # are handled differently — currently passed-through. Phase C will
  # add proper template substitution.
  if echo "$tf_clean" | grep -q '<'; then
    continue
  fi
  if ! echo "$staged" | grep -qxF "$tf_clean"; then
    missing="${missing}${tf_clean}\n"
  fi
done <<< "$touches_files"

if [ -n "$missing" ]; then
  cat >&2 <<EOF

[SDD] sub-action '$active_slug' declares files it MUST also stage,
      but you committed without including all of them.

      Missing from this commit:
$(printf "        - %s\n" $(printf "$missing"))

      The sub-action's frontmatter at $sa_path declares
      \`touches: [...]\`. Each file in that list MUST be staged in the
      same commit as spec.md. Reason: declared sync points keep the
      project state coherent (e.g., schema changes → data-model.md
      stays in lockstep with spec.md).

      Either:
        - Stage the missing file(s):  git add <file>
        - Or undo this sub-action's spec.md change

EOF
  exit 2
fi

exit 0
