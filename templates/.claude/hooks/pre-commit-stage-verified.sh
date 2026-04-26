#!/usr/bin/env bash
# pre-commit-stage-verified.sh — THE MOAT.
#
# Blocks `git commit` when a staged `verification.json` claims pass-state
# that does not match a fresh re-run of `verify-stage.sh` on the staged
# spec.md. Compares full (id, result) sets — not just pass-counts — so
# count-preserving identity swaps are also caught.
#
# Wires up as a Claude Code PreToolUse hook on Bash:
#   { "tool_name": "Bash", "tool_input": { "command": "git commit ..." } }
#
# Exits:
#   0 — allow commit (not a verification commit, or claims match fresh run)
#   2 — block commit (fabrication detected; stderr explains)
#
# Catastrophic #4 fix: explicit empty-cmd guard so a parse failure (no
# python3 / future Claude Code input change / manual invocation) defaults
# to ALLOW, not block-on-every-Bash-call.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

# Parse stdin from Claude Code.
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Empty-cmd safe default. Prevents the hook from firing on every Bash call
# when stdin parsing fails.
[ -z "$cmd" ] && exit 0

# Not a git commit? Allow.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Inside a git repo?
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Find staged verification.json paths (one per active feature, usually).
staged_verifications=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null \
                       | grep -E '(^|/)verification\.json$' || true)

# No staged verification.json → not a verification commit → allow.
[ -z "$staged_verifications" ] && exit 0

# Locate verify-stage.sh. Search project-relative first (real installed
# project), then framework template (for in-tree tests).
locate_verify_stage() {
  local candidates=(
    "$PROJECT_DIR/.sdd/scripts/verify-stage.sh"
    "$PROJECT_DIR/templates/.sdd/scripts/verify-stage.sh"
  )
  for p in "${candidates[@]}"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

VERIFY_STAGE=$(locate_verify_stage) || {
  # Cannot verify; default to allow (better than blocking on a config gap).
  exit 0
}

# Compare two verification.json blobs by (id, result) set. Returns 0 if
# identical, 1 if different. Uses python3 for robust JSON parsing.
compare_sets() {
  local claimed="$1" fresh="$2"
  python3 - "$claimed" "$fresh" <<'PY' 2>/dev/null || return 1
import sys, json
# Strict shape: claimed must have EXACTLY {phase, checks}, each check
# must have EXACTLY {id, result}. No extras anywhere. Per failure-mode
# reviewer: lax shape lets nested-JSON / extra-root-key pollution slip
# into committed verification.json without claiming false pass-state,
# but pollutes git history and hides future schema additions.
def load_strict(blob):
    try:
        d = json.loads(blob)
    except Exception:
        return None
    if not isinstance(d, dict) or set(d.keys()) != {"phase", "checks"}:
        return None
    checks = d["checks"]
    if not isinstance(checks, list): return None
    s = set()
    for c in checks:
        if not isinstance(c, dict) or set(c.keys()) != {"id", "result"}:
            return None
        s.add((str(c["id"]), str(c["result"])))
    return s
a = load_strict(sys.argv[1])
b = load_strict(sys.argv[2])
if a is None or b is None:
    sys.exit(1)  # shape failure → treat as mismatch (block)
sys.exit(0 if a == b else 1)
PY
}

# Process each staged verification.json.
while IFS= read -r vpath; do
  [ -z "$vpath" ] && continue

  feature_dir=$(dirname "$vpath")
  spec_path="$feature_dir/spec.md"

  # Read staged spec.md (not working tree — they may differ).
  staged_spec=$(mktemp)
  if ! git show ":$spec_path" > "$staged_spec" 2>/dev/null; then
    rm -f "$staged_spec"
    cat >&2 <<EOF
[moat] cannot read staged $spec_path — block.
Stage spec.md alongside verification.json, or re-run verify-stage.sh.
EOF
    exit 2
  fi

  # Read claimed verification.json from the staged blob.
  claimed=$(git show ":$vpath" 2>/dev/null) || claimed=""
  if [ -z "$claimed" ]; then
    rm -f "$staged_spec"
    continue
  fi

  # Extract phase from the claimed JSON.
  phase=$(printf '%s' "$claimed" | python3 -c "import sys,json;print(json.load(sys.stdin).get('phase',''))" 2>/dev/null || echo "")
  if [ -z "$phase" ]; then
    rm -f "$staged_spec"
    cat >&2 <<EOF
[moat] $vpath has no \"phase\" field — block.
verification.json must declare {"phase":"X","checks":[...]}.
EOF
    exit 2
  fi

  # Re-run verify-stage on the staged spec, in an isolated temp dir.
  fresh_dir=$(mktemp -d)
  cp "$staged_spec" "$fresh_dir/spec.md"
  if ! bash "$VERIFY_STAGE" "$fresh_dir/spec.md" "$phase" >/dev/null 2>&1; then
    rm -rf "$fresh_dir"; rm -f "$staged_spec"
    cat >&2 <<EOF
[moat] verify-stage.sh failed on staged spec — block.
Run: bash $VERIFY_STAGE <spec> $phase
to see the underlying error.
EOF
    exit 2
  fi
  fresh_path="$fresh_dir/verification.json"
  if [ ! -f "$fresh_path" ]; then
    rm -rf "$fresh_dir"; rm -f "$staged_spec"
    cat >&2 <<EOF
[moat] verify-stage.sh produced no output for phase $phase — block.
EOF
    exit 2
  fi
  fresh=$(cat "$fresh_path")
  rm -rf "$fresh_dir"
  rm -f "$staged_spec"

  # Compare claimed vs. fresh by (id, result) set.
  if ! compare_sets "$claimed" "$fresh"; then
    cat >&2 <<EOF
[moat] verification fabrication detected for $vpath (phase $phase).

Claimed in your commit:
$(printf '%s' "$claimed" | python3 -c "import sys,json;d=json.load(sys.stdin);print('\n'.join(sorted(f'  {c[\"id\"]}: {c[\"result\"]}' for c in d.get('checks',[]))))" 2>/dev/null)

Fresh re-run produced:
$(printf '%s' "$fresh" | python3 -c "import sys,json;d=json.load(sys.stdin);print('\n'.join(sorted(f'  {c[\"id\"]}: {c[\"result\"]}' for c in d.get('checks',[]))))" 2>/dev/null)

These must match exactly. Re-run verify-stage.sh, or fix the spec so
honest checks pass — do not edit verification.json by hand.
EOF
    exit 2
  fi
done <<< "$staged_verifications"

exit 0
