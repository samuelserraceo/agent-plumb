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

# === FILE_CLASSES + CO_STAGE_BLOCK enforcement ===
# Read config.md `file_classes:` (named regex pattern lists) and
# `co_stage_block:` (pairs of class names that cannot co-stage). Refuse
# any commit that stages files from both classes of any blocked pair.
# Subsumes pre-commit-cofile-block.sh's hardcoded CLAIM/POLICY rule
# while keeping the schema extensible: projects can declare more
# classes + pairs without changing this hook.
#
# Runs on EVERY commit with staged files (not gated on spec.md) — the
# cofile-block defends the framework against tampered-policy + fabricated-
# claim pairs regardless of whether the agent is doing action work.
class_block_result=$(STAGED="$staged" python3 - <<'PYEOF' 2>/dev/null || echo "ALLOW"
import os, re, sys
try:
    import yaml
except Exception:
    print("ALLOW"); sys.exit(0)

try:
    with open(".sdd/config.md") as f:
        text = f.read()
except OSError:
    print("ALLOW"); sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    print("ALLOW"); sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    print("ALLOW"); sys.exit(0)

classes = fm.get("file_classes") or {}
blocks  = fm.get("co_stage_block") or []
if not classes or not blocks:
    print("ALLOW"); sys.exit(0)

compiled = {}
for name, pats in classes.items():
    if not isinstance(pats, list): continue
    compiled[name] = [re.compile(p) for p in pats if isinstance(p, str)]

buckets = {name: [] for name in compiled}
for line in os.environ.get("STAGED", "").splitlines():
    line = line.strip()
    if not line: continue
    for name, pats in compiled.items():
        if any(p.search(line) for p in pats):
            buckets[name].append(line)

for pair in blocks:
    if not isinstance(pair, list) or len(pair) != 2: continue
    a, b = pair
    if buckets.get(a) and buckets.get(b):
        print("BLOCK")
        print(f"PAIR: {a} × {b}")
        print(f"{a}:")
        for f in buckets[a]: print(f"  {f}")
        print(f"{b}:")
        for f in buckets[b]: print(f"  {f}")
        sys.exit(0)
print("ALLOW")
PYEOF
)

# === FILE_RULES enforcement (per-file append_only / size cap / etc.) ===
# Read config.md `file_rules:` (path → rules map) and apply each rule
# handler against the matching staged file. Today's handlers:
#
#   append_only: true   — staged blob must start with HEAD blob byte-for-byte
#                          (subsumes pre-commit-decisions-append-only.sh)
#   reset_phrase: "<s>" — if commit message contains this string, rules are
#                          bypassed for this commit (escape hatch)
#
# Future Phase C-5 handlers: size_warn, size_block, managed_section.
file_rules_result=$(STAGED="$staged" CMD="$cmd" python3 - <<'PYEOF' 2>/dev/null || echo "ALLOW"
import os, re, subprocess, sys
try:
    import yaml
except Exception:
    print("ALLOW"); sys.exit(0)

try:
    text = open(".sdd/config.md").read()
except OSError:
    print("ALLOW"); sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    print("ALLOW"); sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    print("ALLOW"); sys.exit(0)

rules = fm.get("file_rules") or {}
if not rules:
    print("ALLOW"); sys.exit(0)

cmd = os.environ.get("CMD", "")
staged_lines = [ln.strip() for ln in os.environ.get("STAGED","").splitlines() if ln.strip()]

for path, rule in rules.items():
    if not isinstance(rule, dict): continue
    if path not in staged_lines: continue

    # Reset phrase bypass.
    reset = rule.get("reset_phrase")
    if reset and reset in cmd:
        continue  # skip enforcement for this commit

    # append_only handler.
    if rule.get("append_only"):
        try:
            head = subprocess.run(
                ["git", "show", f"HEAD:{path}"],
                capture_output=True, check=False,
            )
        except Exception:
            continue
        if head.returncode != 0:
            # Not in HEAD — first creation, allow.
            continue
        try:
            staged_blob = subprocess.run(
                ["git", "show", f":{path}"],
                capture_output=True, check=False,
            )
        except Exception:
            continue
        if staged_blob.returncode != 0:
            print("BLOCK")
            print(f"PATH: {path}")
            print("REASON: could not read staged blob")
            sys.exit(0)
        if b"\x00" in staged_blob.stdout or b"\x00" in head.stdout:
            print("BLOCK")
            print(f"PATH: {path}")
            print("REASON: NUL bytes in file content")
            sys.exit(0)
        if not staged_blob.stdout.startswith(head.stdout):
            print("BLOCK")
            print(f"PATH: {path}")
            print("REASON: append_only — staged blob does not start with HEAD blob")
            print(f"RESET_PHRASE: {reset or '(none configured)'}")
            sys.exit(0)

print("ALLOW")
PYEOF
)

case "$file_rules_result" in
  ALLOW*) ;;
  BLOCK*)
    cat >&2 <<EOF

[SDD rules / file_rules] A per-file rule blocked this commit.

$(printf '%s\n' "$file_rules_result" | sed -n '2,$p')

The framework's audit trail relies on append_only files staying
immutable — modifying or removing prior content breaks the trust
model. To fix: revert your edits to existing entries and APPEND your
new entry instead:

    git restore --staged <path>
    git checkout <path>
    # then append the new entry, re-stage, re-commit

If you genuinely need to rebuild the whole file (e.g., recovering
from corruption), use the configured reset phrase in your commit
message — that's the documented escape hatch.

The file_rules definitions live in .sdd/config.md \`file_rules:\`.
EOF
    exit 2
    ;;
esac

case "$class_block_result" in
  ALLOW*) ;;
  BLOCK*)
    cat >&2 <<EOF

[SDD rules / cofile-block] This commit stages files from two classes
that the framework refuses to mix in one commit.

$(printf '%s\n' "$class_block_result" | sed -n '2,$p')

Why this is blocked:
  Each cross-class pair lets a tampered policy ship with a matching
  fabricated claim in the same atomic commit. SDD requires policy
  changes and claim changes to be SEPARATE auditable commits.

How to fix (pick one):
  1. Unstage one class, commit the other:
       git reset HEAD <files-from-one-class>
       git commit
     Then commit the other class separately.

  2. If you genuinely need both, run /next first so the framework
     regenerates the claim against the new policy, then commit each
     class on its own.

The class definitions live in .sdd/config.md \`file_classes:\` and
\`co_stage_block:\`. Project owners can extend them.
EOF
    exit 2
    ;;
esac

# === TOUCHES: enforcement (action-step gated) ===
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

# If no touches: declared, the cofile-block above was the only check; allow.
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
