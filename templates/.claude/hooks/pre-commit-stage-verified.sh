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

# CodeRabbit cycle 1 finding (PR #31): the moat USED to silently
# allow any commit when python3 was missing or stdin parsing failed
# — both branched to "$cmd is empty" → exit 0. The moat exists
# precisely to refuse commits in unclear states; defense-in-depth
# means failing CLOSED, not failing OPEN.
if ! command -v python3 >/dev/null 2>&1; then
  echo "[moat] python3 is required by the moat (manifest hash + stdin parse). Refusing commit." >&2
  echo "[moat] Install python3 (most systems already have it) and retry." >&2
  exit 2
fi

# Parse stdin from Claude Code.
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Empty-cmd safe default. Prevents the hook from firing on every Bash
# call when stdin is genuinely empty (legitimate non-Bash hook
# invocation). NOT a python3-missing fallback — that's caught above.
[ -z "$cmd" ] && exit 0

# Not a git commit? Allow.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Inside a git repo?
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Find staged verification.json AND staged spec.md paths (one per active
# feature, usually). ALSO check whether the manifest itself is being staged
# — UAT v0.10.1 finding (#48): a commit that staged ONLY the manifest
# bypassed the hash-pin check because the moat exited early below. The
# attacker's recipe was: tamper a framework file in commit N (no manifest
# update, no verification.json staged), then stage manifest.json with
# matching tampered hashes in commit N+1 to "legitimise" the tamper. Both
# commits would slip through. Now: manifest staging ALSO fires the
# manifest hash-pin check, with the strict semantics that every entry's
# `expected_sha256` must match the on-disk file's normalised hash. So if
# a user updates the manifest to match tampered files, the check fires
# with both the file AND the manifest itself reported as mismatched (the
# manifest's pin can't be self-validating, but the underlying file is).
staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
staged_verifications=$(printf '%s\n' "$staged_files" | grep -E '(^|/)verification\.json$' || true)
staged_specs=$(printf '%s\n' "$staged_files" | grep -E '(^|/)spec\.md$' || true)
staged_manifest=$(printf '%s\n' "$staged_files" | grep -E '^\.sdd/\.cache/manifest\.json$' || true)

# Phase B (heavy testing) finding: tampering ANY framework file
# (e.g. .sdd/playbooks/feature.md, .sdd/scripts/advance.sh) IN ISOLATION
# previously slipped past the moat because none of {verification.json,
# spec.md, manifest.json} was staged. The earlier UAT #48 fix only
# closed the manifest-staging case. Now: detect any staged change
# (Add/Modify/Delete) whose path matches a manifest-tracked entry and
# include in the gate. The manifest hash-pin check below then catches
# the tamper (or surfaces "missing on disk" for the delete case).
#
# CR cycle-1 (PR #106): the original Phase B fix re-used the ACM-
# filtered $staged_files which excludes deletions, AND silently treated
# manifest-parse failures as "no tracked files" (collapsing to allow).
# Both shapes reopened the tamper bypass.
#
# CR cycle-2 (PR #106): switch to --name-status to capture deletes (D),
# renames (R*), and copy/type-change (C*, T) — checking BOTH the source
# AND destination path on R/C against the manifest. Treat manifest-parse
# failure as triggering the gate (sentinel _PARSE_ERR_) so check_manifest_pins
# below still runs (and surfaces the parse error there in plain English)
# instead of allowing past the early-exit.
staged_framework_files=""
manifest_path="$PROJECT_DIR/.sdd/.cache/manifest.json"
if [ -f "$manifest_path" ]; then
  staged_status=$(git diff --cached --name-status --diff-filter=ACMRDT 2>/dev/null || true)
  staged_framework_files=$(MANIFEST="$manifest_path" \
                            STATUS="$staged_status" python3 <<'PYEOF' 2>/dev/null || echo '_PARSE_ERR_'
import json, os, sys
mp = os.environ["MANIFEST"]
status_lines = [ln for ln in os.environ["STATUS"].splitlines() if ln]
try:
    m = json.load(open(mp))
except Exception:
    # CR cycle-2: manifest-parse failure must NOT be silenced. Emit a
    # non-empty sentinel so the gate fires and check_manifest_pins
    # surfaces the parse error in its own (plain-English) flow.
    print("_PARSE_ERR_")
    sys.exit(0)
tracked = set()
for sec in ("playbooks", "actions", "extensions", "scripts"):
    for entry in (m.get(sec) or {}).values():
        p = entry.get("path", "")
        if p:
            tracked.add(p)
# --name-status emits one line per change. Format:
#   M\tpath                    (modify; 1 path)
#   A\tpath                    (add)
#   D\tpath                    (delete)
#   T\tpath                    (typechange)
#   C100\tsrc\tdst             (copy with similarity score; 2 paths)
#   R100\tsrc\tdst             (rename with similarity score; 2 paths)
# For renames/copies, BOTH paths matter — moving a tracked file out of
# its expected path is exactly the bypass shape this gate must catch.
for line in status_lines:
    parts = line.split("\t")
    if not parts:
        continue
    status = parts[0]
    paths = parts[1:]
    for p in paths:
        if p and p in tracked:
            print(p)
            break  # one match per status line is enough to fire the gate
PYEOF
)
fi

# Nothing staged that triggers manifest checks → allow.
[ -z "$staged_verifications" ] && [ -z "$staged_specs" ] && [ -z "$staged_manifest" ] && [ -z "$staged_framework_files" ] && exit 0

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
#
# CodeRabbit cycle 9 (v0.9.1 fix): unified the hash algorithm with the
# manifest pin. Earlier this hook used RAW SHA-256 (shasum/sha256sum
# default), but the manifest pin below uses NORMALIZED SHA-256 (LF
# line endings + strip trailing whitespace + strip blank-line edges).
# Two algorithms in the same security boundary made the trust model
# fragile: a CRLF flip would force a re-pin here while the manifest
# stayed silent. Now both layers use the same normalised algorithm.
VERIFY_STAGE_EXPECTED_HASH="d51d3e16f31d72f8a78be721711a94f345b33b75bde1077ba2d59159ed9b9c8b"
# Note: python3 existence already verified at the top of this hook
# (the moat fails-closed if python3 is missing). CodeRabbit cycle 2
# (PR #31): removed the duplicated `command -v python3` check that
# used to live here — single source of truth for the dependency.
actual_hash=$(VERIFY_STAGE="$VERIFY_STAGE" python3 -c '
import hashlib, os, sys
path = os.environ["VERIFY_STAGE"]
try:
    with open(path, "rb") as f: data = f.read()
except OSError:
    sys.exit(0)  # empty stdout → caller treats as missing hasher
if b"\x00" in data:
    print("NUL"); sys.exit(0)
text = data.decode("utf-8", errors="replace")
lines = [ln.rstrip() for ln in text.replace("\r\n","\n").replace("\r","\n").split("\n")]
while lines and lines[0] == "": lines.pop(0)
while lines and lines[-1] == "": lines.pop()
print(hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest())
' 2>/dev/null)
if [ -z "$actual_hash" ]; then
  cat >&2 <<EOF
[moat] could not hash verify-stage.sh — refusing to commit. The
script may be unreadable or python3 may have failed. Check that
$VERIFY_STAGE exists and is readable.
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

  # CodeRabbit cycle-4 PR #53: when manifest.json is itself staged, the
  # commit will use the index (staged) blob, not the working tree. The
  # earlier code always read the WT manifest, so an attacker could stage
  # a clean manifest while leaving a tampered one in WT — the moat saw
  # the tampered hashes (matching tampered WT framework files) and let
  # the commit through, but the COMMITTED state would mix a clean
  # manifest with tampered files. Now: read the staged blob when staged.
  #
  # PR #61 (closes #55): trust-baseline check. When the manifest is staged
  # AND has hash CHANGES versus HEAD's manifest, treat the commit as a
  # repin and refuse it unless the commit message carries the marker
  # `[SDD] manifest: repin`. This blocks the within-commit attack where an
  # attacker tampers a framework file, recomputes its hash, and stages
  # both file + manifest in the same commit. HEAD's manifest is the
  # trusted baseline; legitimate repins (e.g. via update.sh) must
  # explicitly opt in via the marker.
  #
  # #138 fix: the marker check inside this pre-commit hook fires only
  # when GIT_COMMIT_CMD is non-empty (i.e. PreToolUse path with the
  # actual `git commit` line visible). When empty (native-git pre-commit
  # path — synthetic stdin from the shim), the message text isn't
  # readable here, so the marker check is deferred to the commit-msg
  # hook which DOES receive the message file path. Either path
  # eventually enforces the marker — defence in depth.
  MANIFEST="$manifest_path" PROJ="$PROJECT_DIR" \
    STAGED_MANIFEST_PATH="$staged_manifest" \
    GIT_COMMIT_CMD="$cmd" \
    STAGED_FILES="$staged_files" \
    python3 <<'PYEOF'
import hashlib, json, os, re, shlex, subprocess, sys

manifest_path = os.environ["MANIFEST"]
# bugs/002 Bug B fix: parse staged-file list so the per-file HEAD check
# below can skip files that ARE being legitimately updated in this
# commit. The cross-commit attack the HEAD check defends against is
# exactly "HEAD has tampered content + WT reverted to clean" — in that
# shape the file is NOT in the staged set, so skipping the HEAD check
# on staged files preserves the defence. See .sdd/bugs/002 for repro.
staged_files_set = set(
    line.strip() for line in os.environ.get("STAGED_FILES", "").split("\n") if line.strip()
)
proj = os.environ["PROJ"]
staged_manifest_path = os.environ.get("STAGED_MANIFEST_PATH", "")
git_commit_cmd = os.environ.get("GIT_COMMIT_CMD", "")

try:
    if staged_manifest_path:
        # Manifest is staged — read the staged blob (what's actually
        # going into HEAD) for the per-file hash check below.
        result = subprocess.run(
            ["git", "show", ":" + staged_manifest_path],
            capture_output=True, cwd=proj, timeout=10,
        )
        if result.returncode != 0:
            print("[moat] cannot extract staged manifest blob from index",
                  file=sys.stderr)
            sys.exit(1)
        manifest = json.loads(result.stdout.decode("utf-8", errors="replace"))
    else:
        with open(manifest_path) as f:
            manifest = json.load(f)
except Exception as e:
    print(f"[moat] manifest.json malformed: {e}", file=sys.stderr)
    sys.exit(1)

# (Trust-baseline diff + repin-marker check moved to commit-msg hook —
# see comment block above. The per-file WT/HEAD hash-pin check below is
# still the pre-commit defence against tampered file content.)
#
# The marker pattern is `[SDD] manifest: repin` (case-sensitive). The
# `update.sh` migration script writes commits with this prefix. The
# user (or update.sh) can also add it manually for one-off framework
# upgrades.
#
# #138 fix: skip this whole block when git_commit_cmd is empty —
# that's the native-git pre-commit path where the message isn't yet
# readable. The commit-msg hook will run the same trust-baseline diff
# with full message access. When git_commit_cmd is non-empty
# (PreToolUse path), this block runs as the early gate.
#
# bugs/002 Bug D fix: also require a message-flag to be present in the
# cmd. The native-git shim at .claude/hooks/pre-commit sends synthetic
# stdin {"tool_input":{"command":"git commit"}} — non-empty but no -m
# / -F visible. The #138 fix gated this block behind `git_commit_cmd`
# truthy, but the synthetic is truthy too, so legitimate terminal
# repins via the shim still got refused. With this guard, when the
# message is unreadable (no -m / -F / --message / --file in cmd) the
# block defers to commit-msg which DOES receive the message file path.
_msg_flag_re = re.compile(r"(^|\s)(-m|-F|--message|--file)([=\s]|$)")
_has_msg_flag = bool(_msg_flag_re.search(git_commit_cmd))
if staged_manifest_path and git_commit_cmd and _has_msg_flag:
    # Step 1 (PR #61 cycle-3 refactor): parse the actual commit message
    # FIRST — before any trust-baseline gate runs — so the same parsed
    # `marker_present` can be reused in:
    #   (a) the unreadable-HEAD path (allow a repair commit through)
    #   (b) the repin-detected path (allow legitimate repins through)
    # This closes the cycle-3 critical: the previous code's marker parse
    # only ran inside the repin-detected branch, so a staged repair of a
    # malformed HEAD manifest with the marker was still refused (CR's
    # cycle-3 finding "the suggested repair commit is still blocked").
    #
    # The parser is ALSO scoped to the actual `git commit` segment of a
    # possibly-compound shell command (e.g. `tool -m "[SDD] ..." && git
    # commit -m unrelated`). Without this, an upstream segment's -m/-F
    # could smuggle the marker into the gate.
    # (shlex already imported at module level — CR cycle-8 nitpick)
    try:
        cmd_argv = shlex.split(git_commit_cmd) if git_commit_cmd else []
    except ValueError:
        cmd_argv = []

    shell_connectors = {"&&", "||", ";", "|"}
    segments = []
    current = []
    for tok in cmd_argv:
        if tok in shell_connectors:
            if current:
                segments.append(current)
            current = []
            continue
        current.append(tok)
    if current:
        segments.append(current)

    env_var_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
    # git options that take an argument (need to skip both the flag AND
    # its value when walking past them to find the `commit` subcommand).
    _git_opts_with_arg = {
        "-C", "-c", "--git-dir", "--work-tree", "--namespace",
    }

    def _git_commit_args(seg):
        """If seg invokes `git ... commit ...`, return the args TO commit
        (i.e. seg minus env-var prefixes minus `git` minus git's own
        pre-subcommand options minus the `commit` token). Else None."""
        j = 0
        while j < len(seg) and env_var_re.match(seg[j]):
            j += 1
        if j >= len(seg) or seg[j] != "git":
            return None
        j += 1  # past "git"
        # Walk past git's pre-subcommand options.
        while j < len(seg) and seg[j] != "commit":
            opt = seg[j]
            if opt in _git_opts_with_arg:
                j += 2
                continue
            if opt.startswith("-"):
                j += 1
                continue
            # Positional arg before `commit` — not a `git commit` segment.
            return None
        if j >= len(seg) or seg[j] != "commit":
            return None
        return seg[j + 1:]

    commit_message_parts = []
    for seg in segments:
        args = _git_commit_args(seg)
        if args is None:
            continue
        i = 0
        while i < len(args):
            a = args[i]
            if a in ("-m", "--message") and i + 1 < len(args):
                commit_message_parts.append(args[i + 1])
                i += 2
                continue
            if a.startswith("--message="):
                commit_message_parts.append(a[len("--message="):])
            elif a.startswith("-m="):
                commit_message_parts.append(a[len("-m="):])
            elif a in ("-F", "--file") and i + 1 < len(args):
                f = args[i + 1]
                full_f = f if os.path.isabs(f) else os.path.join(proj, f)
                try:
                    with open(full_f, encoding="utf-8") as fh:
                        commit_message_parts.append(fh.read())
                except (OSError, UnicodeDecodeError):
                    pass
                i += 2
                continue
            elif a.startswith("--file="):
                f = a[len("--file="):]
                full_f = f if os.path.isabs(f) else os.path.join(proj, f)
                try:
                    with open(full_f, encoding="utf-8") as fh:
                        commit_message_parts.append(fh.read())
                except (OSError, UnicodeDecodeError):
                    pass
            i += 1
        break  # only one `git commit` per command

    commit_message = "\n".join(commit_message_parts)
    marker_re = re.compile(r"\[SDD\]\s+manifest:\s+repin", re.IGNORECASE)
    marker_present = bool(marker_re.search(commit_message))

    # Step 2: fetch HEAD's manifest as the trust baseline.
    head_manifest = None
    head_manifest_unreadable = False  # HEAD has the blob but we can't parse it
    try:
        head_result = subprocess.run(
            ["git", "show", f"HEAD:{staged_manifest_path}"],
            capture_output=True, cwd=proj, timeout=10,
        )
        if head_result.returncode == 0:
            # HEAD has the file. Try to parse it. If the parse fails, the
            # baseline is unreadable — fail-closed (unless the user is
            # repairing, see below).
            try:
                head_manifest = json.loads(
                    head_result.stdout.decode("utf-8", errors="replace")
                )
            except Exception:
                head_manifest = None
                head_manifest_unreadable = True
        # else: HEAD doesn't have the manifest yet (legitimate first-time
        # add). Leave both flags as None / False so the gate is skipped.
    except Exception:
        # git unavailable / timeout / etc. — skip gate (better than blocking
        # all commits when git is broken). The per-file WT hash check below
        # still runs as the primary defence against tampered files.
        head_manifest = None
        head_manifest_unreadable = False

    # Step 3: handle malformed HEAD baseline. PR #61 cycle-3 fix: allow
    # the marker-bearing repair commit through (otherwise the user has no
    # in-band recovery path — the previous fail-closed exited before the
    # marker check ever ran). With the marker present, fall through; the
    # per-file WT hash check below verifies the staged manifest content.
    if head_manifest_unreadable:
        if not marker_present:
            print("[moat] HEAD manifest.json exists but is malformed —", file=sys.stderr)
            print("       refusing the commit. The trust baseline cannot be", file=sys.stderr)
            print("       evaluated against an unreadable HEAD manifest.", file=sys.stderr)
            print("", file=sys.stderr)
            print("To recover: stage a valid manifest.json and commit it with", file=sys.stderr)
            print("the marker:", file=sys.stderr)
            print("", file=sys.stderr)
            print("    git commit -m '[SDD] manifest: repin — repair HEAD'", file=sys.stderr)
            print("", file=sys.stderr)
            print("(case-insensitive, parsed only from -m / --message= / -F /", file=sys.stderr)
            print("--file= on the actual `git commit` segment.)", file=sys.stderr)
            sys.exit(1)
        # Marker present → user is repairing. Fall through; the per-file
        # WT hash check below validates the staged manifest's claims.

    # If HEAD has no manifest (e.g. very early in project life), there's
    # nothing to compare against — skip the trust-baseline check. The
    # per-file hash check below still runs.
    if head_manifest is not None:
        # Path-keyed detection (PR #61 cycle-1 fix): we compare paths, not
        # slugs. This catches three bypass shapes that slug-keyed walking
        # missed:
        #   (a) hash change under same slug
        #   (b) slug removed (path silently drops out of trust coverage)
        #   (c) same path re-keyed under a fresh slug with a new hash
        def _collect_paths(m):
            out = {}
            for sec in ("playbooks", "actions", "extensions", "scripts"):
                for _slug, entry in (m.get(sec) or {}).items():
                    p = entry.get("path", "")
                    h = entry.get("expected_sha256", "")
                    if p:
                        out[p] = (sec, h)
            return out

        head_paths = _collect_paths(head_manifest)
        staged_paths = _collect_paths(manifest)

        repins = []  # list of (path, head_hash, staged_hash_or_REMOVED)
        for path, (head_sec, head_hash) in head_paths.items():
            staged = staged_paths.get(path)
            if staged is None:
                # Path removed entirely from the manifest. This drops trust
                # coverage of an existing framework file — gate it.
                repins.append((path, head_hash, "<removed>"))
                continue
            staged_sec, staged_hash = staged
            if head_hash and staged_hash and head_hash != staged_hash:
                repins.append((path, head_hash, staged_hash))
        # Additions (paths in staged but not HEAD) are allowed; the
        # per-file WT hash check below still verifies them.

        if repins:
            # Repin detected — require the [SDD] manifest: repin marker.
            # The marker has already been parsed at the top of this block
            # (segment-scoped to the actual `git commit`, with env-var
            # prefixes and git's own pre-subcommand options handled).
            if not marker_present:
                print("[moat] manifest repin refused — no approval marker.",
                      file=sys.stderr)
                print("", file=sys.stderr)
                print("This commit changes the manifest's trust coverage for the",
                      file=sys.stderr)
                print("following framework files (HEAD baseline → staged):",
                      file=sys.stderr)
                for path, head_hash, staged_hash in repins:
                    if staged_hash == "<removed>":
                        print(f"  {path}: pin removed (no longer enforced)",
                              file=sys.stderr)
                    else:
                        print(f"  {path}: {head_hash[:12]}... → {staged_hash[:12]}...",
                              file=sys.stderr)
                print("", file=sys.stderr)
                print("Repinning or removing entries changes the trust baseline.",
                      file=sys.stderr)
                print("To prevent a tampered file being silently legitimised by",
                      file=sys.stderr)
                print("a co-staged manifest edit, the moat refuses the commit",
                      file=sys.stderr)
                print("unless the commit message contains the marker:",
                      file=sys.stderr)
                print("", file=sys.stderr)
                print("    [SDD] manifest: repin", file=sys.stderr)
                print("", file=sys.stderr)
                print("(case-insensitive, parsed from -m / --message= / -F /",
                      file=sys.stderr)
                print("--file= only — not from env vars or argv text).",
                      file=sys.stderr)
                print("", file=sys.stderr)
                print("If this is a legitimate repin (e.g. you ran scripts/update.sh",
                      file=sys.stderr)
                print("or you intentionally edited a framework file), commit with:",
                      file=sys.stderr)
                print("", file=sys.stderr)
                print("    git commit -m '[SDD] manifest: repin — <reason>'",
                      file=sys.stderr)
                print("", file=sys.stderr)
                print("Editor commits (no -m/-F) are not yet supported for repins;",
                      file=sys.stderr)
                print("use -m or -F so the moat can read the message ahead of time.",
                      file=sys.stderr)
                print("", file=sys.stderr)
                print("If you didn't expect this commit to repin, inspect with",
                      file=sys.stderr)
                print("`git diff --cached` — a tampered file may be hiding here.",
                      file=sys.stderr)
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
        #
        # bugs/002 Bug B fix: skip the HEAD check ONLY when the manifest
        # is also being repinned in this commit AND the file is staged.
        # That's the signature of a legitimate repin — file content +
        # manifest hash both updated together. Without the manifest-
        # staged condition, T45's cross-commit attack scenario (HEAD
        # tampered, WT-revert staged, manifest unchanged) would slip
        # past — its staged file is not paired with a manifest repin,
        # so the HEAD check still fires there.
        if staged_manifest_path and rel in staged_files_set:
            continue
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
    # B1 (stress-test) — plain-English first, technical detail below.
    # Most users hitting this haven't tampered; they've edited a framework
    # file by accident (find-and-replace across the repo, IDE auto-format)
    # or are upgrading SDD on purpose. Both cases need different actions;
    # spell them out instead of dumping hex hashes.
    print("[moat] One or more SDD framework files have changed since SDD's", file=sys.stderr)
    print("       last sealed version. The commit is refused until that's resolved.", file=sys.stderr)
    print("", file=sys.stderr)
    file_list = "\n".join(f"         {rel}" for rel, _kind, _a, _e in mismatches)
    print(f"  Files that changed:\n{file_list}", file=sys.stderr)
    print("", file=sys.stderr)

    # CR cycle-2 Major — split recovery suggestions by mismatch kind.
    # Working-tree mismatches: WT has the bad copy → restore from HEAD.
    # HEAD-only mismatches: WT is already clean, HEAD has the bad copy →
    #   `git checkout HEAD --` would OVERWRITE the clean WT with the bad
    #   blob and re-create the failure; the right path is to amend HEAD.
    wt_mismatches = [m for m in mismatches if "HEAD" not in m[1]]
    head_mismatches = [m for m in mismatches if "HEAD" in m[1]]

    if wt_mismatches:
        print("  If you didn't change these on purpose (e.g. an editor auto-formatted", file=sys.stderr)
        print("  them, or a find-and-replace ran across the repo), restore them from HEAD:", file=sys.stderr)
        print("", file=sys.stderr)
        for rel, _kind, _a, _e in wt_mismatches:
            print(f"      git checkout HEAD -- {shlex.quote(rel)}", file=sys.stderr)
        print("", file=sys.stderr)

    if head_mismatches:
        print("  Some files have a mismatch in HEAD (committed earlier) but the", file=sys.stderr)
        print("  current working tree IS clean. Restoring with `git checkout HEAD`", file=sys.stderr)
        print("  would overwrite your clean copy with the bad blob — DON'T do that.", file=sys.stderr)
        print("  Instead, the bad commit needs to be replaced. The safest path:", file=sys.stderr)
        print("  re-stage the working-tree copy and amend the offending commit", file=sys.stderr)
        print("  (or re-pin the manifest if that's the intended state):", file=sys.stderr)
        print("", file=sys.stderr)
        for rel, _kind, _a, _e in head_mismatches:
            print(f"      git add {shlex.quote(rel)} && git commit --amend --no-edit", file=sys.stderr)
        print("", file=sys.stderr)
        print("  If multiple commits sit between HEAD and the tamper, an", file=sys.stderr)
        print("  interactive rebase (`git rebase -i`) targeting the bad commit", file=sys.stderr)
        print("  is the safer route.", file=sys.stderr)
        print("", file=sys.stderr)

    print("  If you DID change them on purpose (e.g. upgrading SDD or applying", file=sys.stderr)
    print("  a framework patch), ask the agent to re-seal the manifest before", file=sys.stderr)
    print("  committing — the commit message must include the marker", file=sys.stderr)
    print("  '[SDD] manifest: repin — <reason>'.", file=sys.stderr)
    print("", file=sys.stderr)
    print("  Why this fires: the framework hashes its own files into a manifest", file=sys.stderr)
    print("  and re-checks them at commit time. This catches accidental edits,", file=sys.stderr)
    print("  IDE auto-formats, and a class of attack where one commit tampers", file=sys.stderr)
    print("  with a framework file and a later commit uses the tamper to slip", file=sys.stderr)
    print("  past safety checks. (Technical: hash mismatch detail below.)", file=sys.stderr)
    print("", file=sys.stderr)
    print("  Technical detail (for debugging):", file=sys.stderr)
    for rel, kind, actual_h, expected_h in mismatches:
        a = (actual_h[:12] + "...") if len(actual_h) > 12 else actual_h or "(none)"
        e = (expected_h[:12] + "...") if len(expected_h) > 12 else expected_h or "(none)"
        print(f"    {rel}", file=sys.stderr)
        print(f"      kind:     {kind}", file=sys.stderr)
        print(f"      expected: {e}", file=sys.stderr)
        print(f"      actual:   {a}", file=sys.stderr)
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
