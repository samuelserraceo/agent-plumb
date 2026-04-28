#!/usr/bin/env bash
# pre-commit-rules.sh — F1 generic rule-enforcer.
#
# Single hook reading frontmatter + config to enforce framework rules
# at commit time. Designed to subsume 6+ specific hooks one by one as
# Phase-C progresses. **Phase C-5 (2/N) base scope:**
#
#   1. Action frontmatter `touches:` — every declared file must be
#      staged when the action's spec.md is staged. (Was:
#      pre-commit-touches.sh — runs in parallel for now; retired in
#      C-5 (3/N).)
#   2. Path safety — every declared `touches:` path is validated
#      against validate-sdd-path.sh before enforcement. Refuses
#      absolute paths, `..` segments, and paths outside `.sdd/`.
#
# Future scope (later C-5 commits):
#   3. Action `requires_user_approval:` — block phase advance if a
#      required-approval section's hash is stale.
#   4. Config `file_classes:` (POLICY vs CLAIM) — block cross-class
#      co-staging. (Subsumes pre-commit-cofile-block.sh.)
#   5. Config `file_rules:` (append-only, size cap, claude-md-managed) —
#      generalised. (Subsumes pre-commit-decisions-append-only.sh,
#      pre-commit-size-cap.sh, pre-commit-claude-md-managed.sh.)
#   6. Config `events:` — fire-time validation that staged files match
#      the event's declared actions. (Subsumes pre-commit-learn-sync.sh,
#      pre-commit-schema-sync.sh.)
#   7. Config `state_rules:` — phase advance with open `[ ]`. (Subsumes
#      pre-commit-block.sh — last to retire, highest leverage.)
#
# Behaviour:
#   - Empty-cmd safe default (exit 0)
#   - Non-commit Bash → exit 0
#   - No spec.md staged → exit 0 (nothing for SYNC to enforce yet)
#   - Active action unknown → exit 0
#   - Action `touches:` empty/absent → exit 0
#   - Any declared file missing OR unsafe path → BLOCK (exit 2)
#
# Wires up as a Claude Code PreToolUse hook on Bash. Parallel-fires
# with pre-commit-touches.sh until C-5 (3/N) retires that hook.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

# Parse stdin (Claude Code PreToolUse Bash payload).
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[ -z "$cmd" ] && exit 0

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

staged=$(git diff --cached --name-only 2>/dev/null || echo "")
[ -z "$staged" ] && exit 0

# Touches: enforcement only fires when an action's spec.md is staged.
# Other commits (typo fixes, README updates, framework upgrades) don't
# need to honour the active action's touches: declaration.
if ! echo "$staged" | grep -qE '(^|/)spec\.md$'; then
  exit 0
fi

[ -f .sdd/INDEX.md ] || exit 0

# Resolve active action slug from INDEX.md.
active_slug=$(python3 - <<'PYEOF' 2>/dev/null || echo ""
import re, sys
try:
    text = open(".sdd/INDEX.md").read()
except OSError:
    sys.exit(0)
m = re.search(r"action:\s*([a-z][a-z0-9-]*)", text, re.IGNORECASE)
if m:
    print(m.group(1)); sys.exit(0)
m = re.search(r"\*\*Active blocker:\*\*\s*([a-z][a-z0-9-]+)", text, re.IGNORECASE)
if m:
    print(m.group(1))
PYEOF
)
[ -z "$active_slug" ] && exit 0

action_path=".sdd/actions/${active_slug}.md"
[ -f "$action_path" ] || exit 0

# Read the action's `touches:` list.
touches_files=$(SA_PATH="$action_path" python3 - <<'PYEOF' 2>/dev/null || echo ""
import os, re, sys
try:
    text = open(os.environ["SA_PATH"]).read()
except OSError:
    sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m: sys.exit(0)
try:
    import yaml
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    sys.exit(0)
for t in (fm.get("touches") or []):
    if isinstance(t, str):
        print(t)
PYEOF
)

[ -z "$touches_files" ] && exit 0

# Path-safety check: every declared `touches:` path must pass
# validate-sdd-path.sh. Catches drift in the action library where a
# malicious or buggy edit declares a path outside .sdd/ — F1 audit A1.
unsafe=""
while IFS= read -r tf; do
  [ -z "$tf" ] && continue
  # Skip placeholder-templated paths (handled per-action in older code;
  # F1's full template substitution lands in a future commit).
  if echo "$tf" | grep -q '<'; then
    continue
  fi
  if ! bash .sdd/scripts/validate-sdd-path.sh "$tf" >/dev/null 2>&1; then
    unsafe="${unsafe}${tf}\n"
  fi
done <<< "$touches_files"

if [ -n "$unsafe" ]; then
  cat >&2 <<EOF

[SDD] action '$active_slug' declares 'touches:' paths that are unsafe:

$(printf "        - %s\n" $(printf "$unsafe"))

      The framework refuses paths that are absolute, contain '..'
      segments, or sit outside '.sdd/'. Edit the action's
      $action_path frontmatter to use a path under '.sdd/'.

EOF
  exit 2
fi

# Touches-staged check: every declared file (sans templated paths)
# must be in the staged set.
missing=""
while IFS= read -r tf; do
  [ -z "$tf" ] && continue
  tf_clean="${tf#/}"
  if echo "$tf_clean" | grep -q '<'; then
    continue
  fi
  if ! echo "$staged" | grep -qxF "$tf_clean"; then
    missing="${missing}${tf_clean}\n"
  fi
done <<< "$touches_files"

if [ -n "$missing" ]; then
  cat >&2 <<EOF

[SDD] action '$active_slug' declares files it MUST also stage,
      but you committed without including all of them.

      Missing from this commit:
$(printf "        - %s\n" $(printf "$missing"))

      The action's frontmatter at $action_path declares
      \`touches: [...]\`. Each file in that list MUST be staged in the
      same commit as spec.md. Reason: declared sync points keep the
      project state coherent (e.g., schema changes → data-model.md
      stays in lockstep with spec.md).

      Either:
        - Stage the missing file(s):  git add <file>
        - Or undo this action's spec.md change

EOF
  exit 2
fi

exit 0
