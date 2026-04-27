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
staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
staged_verifications=$(printf '%s\n' "$staged_files" | grep -E '(^|/)verification\.json$' || true)

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

# === VERIFY-STAGE TRUST GUARD ===
# The moat re-runs verify-stage.sh on the staged spec to compare claimed
# vs. fresh verification. If the verifier itself can be replaced or
# modified in the same commit window, an adversary can ship a shim that
# emits whatever the fabricated verification.json claims, defeating the
# moat's central guarantee. Two layers of defense:
#
#   1. Co-stage block: verify-stage.sh and verification.json cannot be in
#      the same commit. Forces any verifier change to be its own commit.
#   2. Hash pin: the verifier's content hash is embedded below. Hook
#      refuses to run if the on-disk verifier doesn't match. Legitimate
#      updates must also update VERIFY_STAGE_EXPECTED_HASH.
#
# Multi-commit attacks (commit N replaces verifier, commit N+1 stages
# verification.json against the shim) are still possible — the agent
# would need TWO commits, the verifier-change commit is auditable in
# git log, and the hash pin makes legitimate vs. malicious verifier
# changes equally visible. Phase B may add a non-staged canonical copy.

# Co-stage block: refuse if verify-stage.sh AND verification.json are
# both in the staged set.
if printf '%s\n' "$staged_files" | grep -Eq '(^|/)\.sdd/scripts/verify-stage\.sh$'; then
  cat >&2 <<EOF
[moat] verify-stage.sh and verification.json cannot be staged in the same
commit. The verifier is the moat's referee — staging it alongside the
verification it produces breaks the trust assumption. Split the commits:

  1. Commit verify-stage.sh changes alone (with an updated expected hash
     in pre-commit-stage-verified.sh).
  2. Then re-run verify-stage and stage spec.md + verification.json
     separately.
EOF
  exit 2
fi

# Hash pin: refuse if the verifier on disk doesn't match the expected hash.
VERIFY_STAGE_EXPECTED_HASH="ff4b4d0480be3575970d1d7523cfcf6d3737cbbb7cc6080ef7bda7b243c27813"
# Compute hash. Try shasum (macOS default), sha256sum (most Linux), then
# python3 hashlib as a guaranteed fallback (python3 is already required for
# JSON parsing below — if it's missing the hook can't function anyway).
# Reviewer round 3 caught the original silent-disable when neither shasum
# nor sha256sum were on PATH.
if command -v shasum >/dev/null 2>&1; then
  actual_hash=$(shasum -a 256 "$VERIFY_STAGE" 2>/dev/null | cut -d' ' -f1)
elif command -v sha256sum >/dev/null 2>&1; then
  actual_hash=$(sha256sum "$VERIFY_STAGE" 2>/dev/null | cut -d' ' -f1)
elif command -v python3 >/dev/null 2>&1; then
  actual_hash=$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$VERIFY_STAGE" 2>/dev/null)
else
  actual_hash=""
fi
if [ -z "$actual_hash" ]; then
  cat >&2 <<EOF
[moat] no SHA-256 hasher available (shasum, sha256sum, python3 all
absent) — refusing to commit. The hash pin cannot verify
verify-stage.sh's integrity without a hasher.
EOF
  exit 2
fi
if [ "$actual_hash" != "$VERIFY_STAGE_EXPECTED_HASH" ]; then
  cat >&2 <<EOF
[moat] verify-stage.sh hash mismatch — refusing to use it as referee.
  Expected: $VERIFY_STAGE_EXPECTED_HASH
  Actual:   $actual_hash

If you legitimately updated verify-stage.sh, also update
VERIFY_STAGE_EXPECTED_HASH in pre-commit-stage-verified.sh in the same
commit. Otherwise restore the verifier from main:
  git checkout main -- .sdd/scripts/verify-stage.sh
EOF
  exit 2
fi

# === HOOK SELF-TAMPERING GUARD ===
# An adversary could stage a no-op replacement of THIS hook alongside a
# fabricated verification.json. The (modified) hook fires, allows. Block
# co-staging of pre-commit-stage-verified.sh + verification.json. This is
# a partial defense — the agent could also modify the hook in a separate
# commit, then commit fabrications later. Phase B's `core.hooksPath`
# proposal (move hooks out of the working tree) is the structural fix.
if printf '%s\n' "$staged_files" | grep -Eq '(^|/)\.claude/hooks/pre-commit-stage-verified\.sh$'; then
  cat >&2 <<EOF
[moat] pre-commit-stage-verified.sh and verification.json cannot be
staged in the same commit. The hook is the moat itself; staging a
modification of it alongside the verification it gates breaks the
trust assumption. Split the commits:

  1. Commit hook changes alone.
  2. Then re-run verify-stage and stage spec.md + verification.json
     separately.
EOF
  exit 2
fi

# === MANIFEST HASH-PIN CHECK ===
# When verification.json is staged, every framework file claimed by
# .sdd/.cache/manifest.json must match its expected SHA-256 (normalized
# per SCHEMA.md §11.1). Defends against the cross-commit attack:
#
#   Commit N: agent tampers a playbook (no claim staged → cofile-block
#             doesn't fire because there's no cross-class staging).
#   Commit N+1: agent stages verification.json (no policy staged →
#             cofile-block doesn't fire). Without this check, the
#             tampered playbook would silently affect future /next.
#
# Manifest hash-pin in the moat closes this — the pin compares on-disk
# files to the manifest's expected hashes regardless of what's staged.
#
# Uses SCHEMA.md §11.1 normalization (LF, strip trailing whitespace,
# strip blank-line edges). NOT raw bytes (which would force re-pinning
# on every CRLF flip in editors).
#
# Manifest absent → allow (preserves Phase A's 26 tests, which don't
# scaffold a manifest). Manifest malformed JSON → block.
check_manifest_pins() {
  local manifest_path="$PROJECT_DIR/.sdd/.cache/manifest.json"
  [ -f "$manifest_path" ] || return 0

  MANIFEST="$manifest_path" PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import hashlib, json, os, sys

manifest_path = os.environ["MANIFEST"]
proj = os.environ["PROJ"]

try:
    with open(manifest_path) as f:
        manifest = json.load(f)
except Exception as e:
    print(f"[moat] manifest.json malformed: {e}", file=sys.stderr)
    sys.exit(1)

def normalized_sha256(path):
    """SCHEMA.md §11.1: LF line endings, strip trailing ws per line,
    strip blank-line edges. Same algorithm as load-playbook.sh and
    the manifest generator, so hashes always agree."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return None
    if b"\x00" in data:
        return "NUL"  # caller treats as mismatch + names file
    text = data.decode("utf-8", errors="replace")
    lines = [ln.rstrip() for ln in
             text.replace("\r\n", "\n").replace("\r", "\n").split("\n")]
    while lines and lines[0] == "": lines.pop(0)
    while lines and lines[-1] == "": lines.pop()
    return hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()

mismatches = []
for section in ("playbooks", "subactions", "extensions", "scripts"):
    for slug, entry in (manifest.get(section) or {}).items():
        rel = entry.get("path", "")
        expected = entry.get("expected_sha256", "")
        full = os.path.join(proj, rel)
        if not os.path.isfile(full):
            mismatches.append((rel, "missing on disk", "", expected))
            continue
        actual = normalized_sha256(full)
        if actual == "NUL":
            mismatches.append((rel, "contains NUL bytes", "NUL", expected))
            continue
        if actual is None:
            mismatches.append((rel, "unreadable", "?", expected))
            continue
        if actual != expected:
            mismatches.append((rel, "hash mismatch (tampered)", actual, expected))

if mismatches:
    print("[moat] manifest hash-pin failed — file(s) tampered or out of date.",
          file=sys.stderr)
    print("", file=sys.stderr)
    print("This catches the cross-commit attack: tamper in one commit (no",
          file=sys.stderr)
    print("claim staged), then verification.json in a separate commit. Either",
          file=sys.stderr)
    print("revert the tamper, or regenerate the manifest if the change is a",
          file=sys.stderr)
    print("legitimate framework upgrade (admin repin in a policy-only commit).",
          file=sys.stderr)
    print("", file=sys.stderr)
    for rel, kind, actual_h, expected_h in mismatches:
        a = (actual_h[:12] + "...") if len(actual_h) > 12 else actual_h or "(none)"
        e = (expected_h[:12] + "...") if len(expected_h) > 12 else expected_h or "(none)"
        print(f"  {rel}", file=sys.stderr)
        print(f"    kind:     {kind}", file=sys.stderr)
        print(f"    expected: {e}", file=sys.stderr)
        print(f"    actual:   {a}", file=sys.stderr)
    sys.exit(1)

sys.exit(0)
PYEOF
}

if ! check_manifest_pins; then
  exit 2
fi

# Compare two verification.json blobs by (id, result) set. Returns 0 if
# identical, 1 if different. Uses python3 for robust JSON parsing.
compare_sets() {
  local claimed="$1" fresh="$2"
  python3 - "$claimed" "$fresh" <<'PY' 2>/dev/null || return 1
import sys, json
# Strict shape (v0.7.5 / v0.8): claimed must have EXACTLY {phase, checks}
# OR EXACTLY {phase, checks, approved_sections}. Each check must have
# EXACTLY {id, result}. approved_sections (if present) must be a dict.
# No extras anywhere — lax shape lets nested-JSON / extra-root-key
# pollution slip into committed verification.json without claiming false
# pass-state, polluting git history and hiding schema additions.
#
# This function compares the (id, result) tuples in `checks`; it does
# NOT compare approved_sections (Theme 1.6's section-locking check
# handles that separately, BEFORE this function is called). Including
# approved_sections in the strict-shape allowed-set lets v0.8
# verification.json pass through without being rejected as malformed.
ALLOWED_V07 = {"phase", "checks"}
ALLOWED_V08 = {"phase", "checks", "approved_sections"}
def load_strict(blob):
    try:
        d = json.loads(blob)
    except Exception:
        return None
    if not isinstance(d, dict):
        return None
    keys = set(d.keys())
    if keys != ALLOWED_V07 and keys != ALLOWED_V08:
        return None
    if "approved_sections" in keys and not isinstance(d["approved_sections"], dict):
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

  # NUL-byte guard: a NUL byte in spec.md truncates awk parsing — exit-check
  # lines containing \0 are silently dropped, fresh re-run produces an empty
  # checks array, and a fabricated `{"checks":[]}` matches the empty fresh
  # set, bypassing the moat. Reject any spec.md containing NUL bytes.
  # Using `od -An -c` because bash strips literal \x00 from variable
  # expansions, breaking the more obvious `grep -q $'\x00'` approach.
  if od -An -c "$staged_spec" 2>/dev/null | grep -q '\\0'; then
    rm -f "$staged_spec"
    cat >&2 <<EOF
[moat] staged $spec_path contains NUL bytes — refusing to verify.
A NUL byte in an exit-check line silently drops that check from
verify-stage.sh's output. Remove the binary content from spec.md.
EOF
    exit 2
  fi

  # Read claimed verification.json from the staged blob.
  claimed=$(git show ":$vpath" 2>/dev/null) || claimed=""
  if [ -z "$claimed" ]; then
    # Round 4 finding: previously this silently `continue`d, treating an
    # empty staged verification.json as "nothing to verify". That's a
    # potential bypass — an attacker stages an empty file to skip
    # verification entirely. Block instead.
    rm -f "$staged_spec"
    cat >&2 <<EOF
[moat] staged $vpath is empty — refusing to commit.
verification.json must be a valid JSON object with phase + checks.
Re-run verify-stage.sh to regenerate it.
EOF
    exit 2
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
