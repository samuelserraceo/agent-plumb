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
cd "$PROJECT_DIR" || { echo "[moat] failed to cd into $PROJECT_DIR" >&2; exit 0; }

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

# Find staged verification.json AND staged spec.md paths (one per active
# feature, usually).
staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
staged_verifications=$(printf '%s\n' "$staged_files" | grep -E '(^|/)verification\.json$' || true)
staged_specs=$(printf '%s\n' "$staged_files" | grep -E '(^|/)spec\.md$' || true)

# Neither staged → not a verification-relevant commit → allow.
# (UAT/T64 finding: spec-only commits also need re-checking when HEAD has
# an approved verification.json — see the spec-only-attack block at the
# bottom of this file.)
[ -z "$staged_verifications" ] && [ -z "$staged_specs" ] && exit 0

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

# === VERIFY-STAGE TRUST GUARD (slimmed in C-6) ===
# The moat re-runs verify-stage.sh on the staged spec. If the verifier
# itself can be replaced, an adversary ships a shim that emits whatever
# the fabricated verification.json claims.
#
# Two layers of defense, post-Phase-C-6:
#
#   1. Co-stage block: verify-stage.sh and verification.json cannot be in
#      the same commit. **Now subsumed by F1 generic enforcer's CLAIM ×
#      POLICY rule** (config.md `file_classes:` + `co_stage_block:`).
#      pre-commit-rules.sh blocks the same scenario; the per-file
#      block previously here is removed.
#   2. Hash pin: the verifier's content hash is embedded below. Hook
#      refuses to run if the on-disk verifier doesn't match. Legitimate
#      updates must also update VERIFY_STAGE_EXPECTED_HASH. Stays in the
#      moat — it's the trust anchor for the verifier itself.

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

# === HOOK SELF-TAMPERING GUARD (slimmed in C-6 — subsumed by F1) ===
# Previous version had a per-file block here refusing co-stage of
# pre-commit-stage-verified.sh + verification.json. **Now subsumed by F1
# generic enforcer's CLAIM × POLICY rule** (the hook lives at
# .claude/hooks/[^/]+\.sh which is in POLICY; verification.json is CLAIM).
# pre-commit-rules.sh blocks the same scenario. The per-file block is
# removed; the F1 rule is the single source.

# === MANIFEST HASH-PIN CHECK ===
# When verification.json is staged, every framework file claimed by
# .sdd/.cache/manifest.json must match its expected SHA-256 (normalized
#). Defends against the cross-commit attack:
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
# Uses config.md "Hash normalisation" normalization (LF, strip trailing whitespace,
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

def normalized_sha256_bytes(data):
    """config.md "Hash normalisation": LF line endings, strip trailing ws per line,
    strip blank-line edges. Same algorithm as load-playbook.sh and
    the manifest generator, so hashes always agree.
    Returns 'NUL' on NUL bytes (caller treats as mismatch + names file)."""
    if b"\x00" in data:
        return "NUL"
    text = data.decode("utf-8", errors="replace")
    lines = [ln.rstrip() for ln in
             text.replace("\r\n", "\n").replace("\r", "\n").split("\n")]
    while lines and lines[0] == "": lines.pop(0)
    while lines and lines[-1] == "": lines.pop()
    return hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()

def normalized_sha256(path):
    """File-path variant. Returns None on read error."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return None
    return normalized_sha256_bytes(data)

def head_normalized_sha256(rel_path, project_dir):
    """Fetch file content from HEAD via `git show HEAD:<path>` and hash it
    using the same normalization as on-disk files. Returns:
      - hash hex string if HEAD has the file
      - 'NUL' if HEAD content has NUL bytes
      - None if HEAD doesn't have the file (e.g., new file in this commit
        that isn't yet in HEAD), git unavailable, or any other error
    Skipping the check on missing-from-HEAD is correct: a brand-new file
    can't have a HEAD tamper. The WT check covers the new file's hash.
    The HEAD check exists specifically to catch the cross-commit attack:
    file IS in HEAD with tampered content; agent has reverted WT to clean
    so the WT pin sees nothing."""
    import subprocess
    try:
        result = subprocess.run(
            ["git", "show", f"HEAD:{rel_path}"],
            capture_output=True, cwd=project_dir, timeout=10,
        )
        if result.returncode != 0:
            return None  # File not in HEAD (legitimate new file)
        return normalized_sha256_bytes(result.stdout)
    except Exception:
        return None  # Best-effort: if git is unavailable, skip HEAD check

mismatches = []
for section in ("playbooks", "actions", "extensions", "scripts"):
    for slug, entry in (manifest.get(section) or {}).items():
        rel = entry.get("path", "")
        expected = entry.get("expected_sha256", "")
        full = os.path.join(proj, rel)
        if not os.path.isfile(full):
            mismatches.append((rel, "missing on disk", "", expected))
            continue
        actual = normalized_sha256(full)
        if actual == "NUL":
            mismatches.append((rel, "contains NUL bytes (working tree)", "NUL", expected))
            continue
        if actual is None:
            mismatches.append((rel, "unreadable (working tree)", "?", expected))
            continue
        if actual != expected:
            mismatches.append((rel, "hash mismatch — working tree (tampered)", actual, expected))
            continue  # WT already mismatched; HEAD check is redundant
        # NEW: HEAD content check (Round 1 reality-vs-theory finding #2).
        # Catches cross-commit attack: HEAD has tampered content, agent
        # ran `git checkout HEAD^ -- <file>` to revert WT to clean.
        # WT pin saw nothing; HEAD pin catches the lurking tamper.
        head_actual = head_normalized_sha256(rel, proj)
        if head_actual is None:
            continue  # File not in HEAD (legitimate new file), skip
        if head_actual == "NUL":
            mismatches.append((rel, "contains NUL bytes (HEAD)", "NUL", expected))
            continue
        if head_actual != expected:
            mismatches.append((rel,
                "hash mismatch — HEAD (cross-commit attack? working tree "
                "looks clean but HEAD has tampered content)",
                head_actual, expected))

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

# === THEME 1.6 — APPROVED-SECTION HASH CHECK ===
# Closes Codex finding #2: agent's cheapest cheat is editing the user-
# approved section content (e.g., §11 ACs) to soften criteria, then
# "honestly" passing the now-trivial check. Manifest-pin doesn't catch
# this (the playbook isn't tampered; spec.md is). The fabrication check
# doesn't catch this (the agent can re-run verify-stage; if checks like
# "≥1 AC exists" still pass against the weakened content, claimed and
# fresh agree).
#
# Defense: when the user approves a action, framework writes a
# normalized SHA-256 of the section content to verification.json's
# approved_sections.<slug>. On phase-advance commit, this check
# re-extracts the section from the staged spec.md, recomputes the
# hash via hash-section.sh (single source of truth), and compares to
# the claim. Mismatch → block.
#
# Inputs: claimed verification.json blob (string), staged spec.md
#         path (temp file), path to hash-section.sh.
# Returns: 0 if all entries match (or approved_sections empty/absent),
#          1 if any mismatch / schema error / hash failure.
check_approved_sections() {
  local claimed="$1" staged_spec="$2" hash_script="$3"

  # If hash-section.sh isn't available (template not installed yet),
  # skip — preserves Phase A test compatibility (those scaffolds don't
  # ship hash-section.sh).
  [ -x "$hash_script" ] || [ -f "$hash_script" ] || return 0

  CLAIMED_BLOB="$claimed" STAGED_SPEC="$staged_spec" PROJ="$PROJECT_DIR" \
    HASH_SCRIPT="$hash_script" python3 <<'PYEOF'
import json, os, re, subprocess, sys

claimed = os.environ["CLAIMED_BLOB"]
staged_spec = os.environ["STAGED_SPEC"]
proj = os.environ["PROJ"]
hash_script = os.environ["HASH_SCRIPT"]

try:
    d = json.loads(claimed)
except Exception:
    # Malformed JSON; let compare_sets handle the shape error.
    sys.exit(0)

approved = d.get("approved_sections")
# Field absent (v0.7.5 verification.json) → no Theme 1.6 enforcement.
# This preserves Phase A backward compat — a verification.json without
# approved_sections is a v0.7.5 artifact, not a v0.8 lock-bypass attempt.
if approved is None:
    sys.exit(0)
if not isinstance(approved, dict):
    print("[moat] approved_sections must be a JSON object, got "
          + type(approved).__name__, file=sys.stderr)
    sys.exit(1)

# === COVERAGE CHECK (Theme 1.6 — closes Round 1 failure-mode A.1) ===
# Even with approved_sections present-but-empty, a v0.8 verification.json
# MUST include a hash entry for every action in the active phase that
# declares `requires_user_approval: true` in its frontmatter. Otherwise an
# adversarial agent can write `approved_sections: {}` alongside a tampered
# spec.md and the moat silently skips the check (since no entries to check).
#
# Read the active playbook (B-1 default: 'feature') + each action's
# frontmatter to determine which slugs require coverage in this phase.
# Block if any required slug is absent from claimed.approved_sections.

phase = d.get("phase", "")
# Read the active playbook from INDEX.md's `**Playbook:** <slug>` line so the
# coverage check honors whichever playbook the project is using. Fallback to
# 'feature' (the only B-1 playbook) when INDEX.md is absent, malformed, or
# the slug fails the safe-format check. Preserves Phase A test compat where
# mkproj() doesn't scaffold INDEX.md.
#
# R3 Failure-mode F1 fix: an unvalidated slug accepts path-traversal
# (`../attacker/evil`) which would let the moat read an attacker-controlled
# file as the "playbook" — section-locking bypass via empty required_slugs.
# The regex below restricts slugs to lowercase + digits + hyphens (the same
# closed-enum config.md "Closed enums" declares). Anything outside falls back silently
# to 'feature' (more strict than fail-open: "feature"'s required_slugs are
# non-empty, so an empty approved_sections still gets caught).
SAFE_PLAYBOOK_SLUG_RE = re.compile(r"^[a-z][a-z0-9-]*$")
playbook_slug = "feature"
# R3 Failure-mode F3 fix: read INDEX.md from the staged blob, not the
# working tree. An agent could blank out the working-tree INDEX.md to
# hide the active playbook from the moat, then commit a tampered spec.
# Match pre-commit-block.sh's pattern (it already does this correctly).
index_text = ""
try:
    _r = subprocess.run(
        ["git", "show", ":.sdd/INDEX.md"],
        capture_output=True, cwd=proj, timeout=5,
    )
    if _r.returncode == 0:
        index_text = _r.stdout.decode("utf-8", errors="replace")
except Exception:
    pass
if not index_text:
    # Fallback to working tree only if staged blob isn't available
    # (early bootstrap, or test scaffolding without git).
    index_path_wt = os.path.join(proj, ".sdd", "INDEX.md")
    if os.path.isfile(index_path_wt):
        try:
            with open(index_path_wt) as _f:
                index_text = _f.read()
        except OSError:
            pass
for _line in index_text.split("\n"):
    _m = re.match(r"^\*\*Playbook:\*\*\s+(\S+)\s*$", _line)
    if _m and SAFE_PLAYBOOK_SLUG_RE.match(_m.group(1)):
        playbook_slug = _m.group(1)
        break
playbook_path = os.path.join(proj, ".sdd", "playbooks", f"{playbook_slug}.md")

required_slugs = set()
if phase and os.path.isfile(playbook_path):
    try:
        with open(playbook_path) as f:
            pb_text = f.read()
        pb_fm_match = re.match(r"^---\n(.*?)\n---", pb_text, re.DOTALL)
        if pb_fm_match:
            try:
                import yaml
                pb_fm = yaml.safe_load(pb_fm_match.group(1))
            except (ImportError, ModuleNotFoundError):
                # No PyYAML → skip coverage check. Soft-fail rather than
                # block (preserves Phase A test compatibility on minimal
                # python installs).
                pb_fm = None
            except Exception:
                pb_fm = None
            if isinstance(pb_fm, dict):
                stage_actions = []
                for stage in pb_fm.get("stages", []) or []:
                    if stage.get("id") == phase:
                        stage_actions = stage.get("actions", []) or []
                        break
                for slug in stage_actions:
                    sa_path = os.path.join(proj, ".sdd", "actions",
                                           f"{slug}.md")
                    if not os.path.isfile(sa_path):
                        continue
                    try:
                        with open(sa_path) as f:
                            sa_text = f.read()
                        sa_fm_match = re.match(r"^---\n(.*?)\n---",
                                               sa_text, re.DOTALL)
                        if sa_fm_match:
                            sa_fm = yaml.safe_load(sa_fm_match.group(1))
                            if (isinstance(sa_fm, dict) and
                                sa_fm.get("requires_user_approval") is True):
                                required_slugs.add(slug)
                    except Exception:
                        continue
    except Exception:
        pass  # Coverage check is best-effort; never let it break the moat.

# Coverage only requires approval for sections that ALREADY EXIST in
# spec.md. Otherwise the moat would block at scaffold time when the
# user hasn't reached that action yet. Test "section exists" by
# probing hash-section.sh — exit 0 = present, non-zero = absent or
# malformed (skip from coverage requirement either way).
sections_present = set()
for slug in required_slugs:
    sa_path = os.path.join(proj, ".sdd", "actions", f"{slug}.md")
    if not os.path.isfile(sa_path):
        continue
    try:
        probe = subprocess.run(
            ["bash", hash_script, staged_spec, sa_path],
            capture_output=True, text=True, timeout=10,
        )
        if probe.returncode == 0:
            sections_present.add(slug)
    except Exception:
        pass

claimed_slugs = set(approved.keys())
# Only the intersection (required AND already drafted) must be covered.
missing_required = (required_slugs & sections_present) - claimed_slugs
if missing_required:
    print("[moat] approved_sections coverage check failed — refusing to commit.",
          file=sys.stderr)
    print("", file=sys.stderr)
    print("This is the Round-1-failure-mode-A.1 fix: even when",
          file=sys.stderr)
    print("approved_sections is an empty dict {}, actions that declare",
          file=sys.stderr)
    print("`requires_user_approval: true` in their frontmatter MUST have",
          file=sys.stderr)
    print("hash entries. Otherwise an adversary could ship a tampered spec",
          file=sys.stderr)
    print("alongside an empty approved_sections and bypass section locking.",
          file=sys.stderr)
    print("", file=sys.stderr)
    print("Missing required entries:", file=sys.stderr)
    for slug in sorted(missing_required):
        print(f"  - {slug}: run /re-approve {slug} to lock the current",
              file=sys.stderr)
        print(f"           §{slug} content", file=sys.stderr)
    sys.exit(1)

# Empty dict (after coverage passes) → no entries to compare against.
if not approved:
    sys.exit(0)

HEX64 = re.compile(r"^[0-9a-f]{64}$")
errors = []

SLUG_RE = re.compile(r"^[a-z][a-z0-9_-]*$")
for slug, expected in sorted(approved.items()):
    # Slug shape validation BEFORE any os.path.join — slugs come from
    # user-controlled JSON; values like "../../../tmp/evil" must not
    # escape .sdd/actions/. Closed-enum shape per v0.9 action library.
    if not isinstance(slug, str) or not SLUG_RE.match(slug):
        errors.append(
            f"approved_sections key {slug!r} is not a valid action slug "
            f"— must match ^[a-z][a-z0-9_-]*$"
        )
        continue
    # Schema validation: hash must be 64-char lowercase hex SHA-256.
    if not isinstance(expected, str) or not HEX64.match(expected):
        errors.append(
            f"approved_sections.{slug} = {expected!r} is not a 64-char "
            f"lowercase hex SHA-256"
        )
        continue

    # Resolve action file. By convention, .sdd/actions/<slug>.md.
    sa_path = os.path.join(proj, ".sdd", "actions", f"{slug}.md")
    if not os.path.isfile(sa_path):
        errors.append(
            f"approved_sections.{slug} references unknown action "
            f"— no file at .sdd/actions/{slug}.md"
        )
        continue

    # Compute actual hash of the staged section via hash-section.sh.
    try:
        result = subprocess.run(
            ["bash", hash_script, staged_spec, sa_path],
            capture_output=True, text=True, timeout=10,
        )
    except Exception as e:
        errors.append(f"hash-section.sh failed for §{slug}: {e}")
        continue

    if result.returncode != 0:
        errors.append(
            f"could not extract §{slug} from staged spec.md: "
            f"{result.stderr.strip() or 'unknown error'}"
        )
        continue

    actual = result.stdout.strip()
    if actual != expected:
        errors.append(
            f"section §{slug} CHANGED since you approved it:\n"
            f"        approved hash: {expected[:12]}...\n"
            f"        staged hash:   {actual[:12]}...\n"
            f"        Either revert your edits to §{slug}, or run\n"
            f"        /re-approve {slug} to lock in the new content."
        )

if errors:
    print("[moat] approved_sections check failed — refusing to commit.",
          file=sys.stderr)
    print("", file=sys.stderr)
    print("This is v0.8's central new defense (Codex finding #2). It catches",
          file=sys.stderr)
    print("the silent-criteria-softening attack: agent edits a user-approved",
          file=sys.stderr)
    print("section to weaken the content, then claims verification 'honestly'",
          file=sys.stderr)
    print("against the trivially-easy now-version.", file=sys.stderr)
    print("", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

sys.exit(0)
PYEOF
}

# Locate hash-section.sh — same pattern as VERIFY_STAGE locate above.
locate_hash_section() {
  local candidates=(
    "$PROJECT_DIR/.sdd/scripts/hash-section.sh"
    "$PROJECT_DIR/templates/.sdd/scripts/hash-section.sh"
  )
  for p in "${candidates[@]}"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  echo ""
}
HASH_SECTION=$(locate_hash_section)

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

  # Theme 1.6 — verify approved_sections re-hash matches staged spec.md.
  # Runs BEFORE compare_sets (per audit recommendation): structural
  # integrity of approvals comes before per-check fabrication detection.
  # No-op when approved_sections is absent (v0.7.5 verification.json) or
  # empty (v0.8 with no requires_user_approval actions).
  if [ -n "$HASH_SECTION" ]; then
    if ! check_approved_sections "$claimed" "$staged_spec" "$HASH_SECTION"; then
      rm -f "$staged_spec"
      exit 2
    fi
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

# === SPEC-ONLY ATTACK PATH (UAT / T64 finding) ===
# Combined `git add spec.md && git commit` stages ONLY spec.md, leaving
# the existing verification.json (with hashes for the now-softened
# section content) sitting in HEAD. The original early-exit above
# treated "no staged verification.json" as "nothing to verify" — but
# that's exactly what the spec-only attack relies on.
#
# For every staged spec.md whose sibling verification.json is NOT in
# the staged set (already covered by the loop above), pull verification
# from HEAD and re-run check_approved_sections. Mismatch → block.
# No HEAD verification.json (legitimate new-feature mid-SPEC) → skip.
# No hash-section.sh available (Phase A scaffold) → skip.
if [ -n "$HASH_SECTION" ] && [ -n "$staged_specs" ]; then
  while IFS= read -r spath; do
    [ -z "$spath" ] && continue
    feature_dir=$(dirname "$spath")
    vpath="$feature_dir/verification.json"
    # Skip if verification.json is also staged — already handled above.
    if printf '%s\n' "$staged_verifications" | grep -qFx "$vpath"; then
      continue
    fi
    # Pull HEAD's verification.json. If absent (new feature, no prior
    # commit), skip — there's nothing to compare the staged spec against.
    head_claim=$(git show "HEAD:$vpath" 2>/dev/null) || continue
    [ -z "$head_claim" ] && continue
    # Read the staged spec.md blob from the index.
    staged_spec=$(mktemp)
    if ! git show ":$spath" > "$staged_spec" 2>/dev/null; then
      rm -f "$staged_spec"
      continue
    fi
    if ! check_approved_sections "$head_claim" "$staged_spec" "$HASH_SECTION"; then
      rm -f "$staged_spec"
      exit 2
    fi
    rm -f "$staged_spec"
  done <<< "$staged_specs"
fi

exit 0
