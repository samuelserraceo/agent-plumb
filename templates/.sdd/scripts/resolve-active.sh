#!/usr/bin/env bash
# resolve-active.sh — single source of truth for "what's the active feature?"
#
# Why: with multi-feature parallel work (one branch per feature), the
# `**Active:**` line in INDEX.md is shared across worktrees / branches.
# Before this helper, switching branches meant manually editing that
# line. Now the active feature is INFERRED from the current git branch
# whenever the branch name is the framework's standard `sdd/<id>-<slug>`
# shape. INDEX.md's `**Active:**` line becomes the fallback for when
# no SDD branch is checked out (e.g., on `main`).
#
# Resolution order:
#   1. Branch-derived. If the current git branch matches the documented
#      shape `sdd/<id>-<slug>` (digits + hyphen + slug) AND exactly one
#      `.sdd/<top>/<id>-<slug>/spec.md` exists, that's the active.
#      Source label: "branch".
#      If 2+ matches exist (same slug under different work-item roots,
#      e.g. features/001-foo/ AND bugs/001-foo/), the resolver fails
#      closed: active=null, source="none", `ambiguous: true`. Callers
#      should tell the user to rename one of the matching folders.
#   2. INDEX.md fallback. Read the `**Active:**` line; if it points at
#      a real work-item folder (path-shape validated, kept inside
#      .sdd/ via realpath), use it. Source label: "index".
#   3. None of the above → active is null. Source label: "none".
#
# Output: JSON on stdout, one line, sorted keys (deterministic).
#   active        — work-item path relative to .sdd/ (e.g. "features/001-foo"),
#                   or null when nothing resolves
#   source        — "branch" | "index" | "none" — how `active` was derived
#   branch        — current git branch, or null when not in a git repo /
#                   detached HEAD / branch lookup failed
#   index_active  — whatever the **Active:** line in INDEX.md points at
#                   (string), or null when the line is missing /
#                   placeholder / file absent
#   ambiguous     — true when the branch slug matched 2+ work-item
#                   folders (e.g. `sdd/001-foo` with both
#                   `features/001-foo/` AND `bugs/001-foo/` present);
#                   false otherwise. When true, `active` is null and
#                   `source` is "none" — the resolver fails closed
#                   instead of silently picking one. Callers should
#                   tell the user to rename one of the matching folders.
#
# Drift detection: when source=="branch" and index_active is non-null
# and index_active != active, the consumer (e.g. /status) can render a
# "branch active vs INDEX active" notice. resolve-active.sh itself
# doesn't emit a `drift` boolean — it gives the caller the two values
# and lets them decide.
#
# No exit codes other than 0 (always emits JSON, never errors). The
# JSON's `source` field tells callers what happened.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

command -v python3 >/dev/null 2>&1 || {
  echo '{"active":null,"ambiguous":false,"branch":null,"index_active":null,"source":"none"}'
  exit 0
}

PROJECT_DIR="$PROJECT_DIR" python3 <<'PYEOF'
import json, os, re, subprocess, sys

proj = os.environ["PROJECT_DIR"]
sdd_root_real = os.path.realpath(os.path.join(proj, ".sdd"))

# Shape of a legitimate work-item path RELATIVE to .sdd/ —
# `<lowercase-folder>/<slug>` with no parent-up segments, no leading
# slash, no embedded `..`. Same shape post-stop-lint invariant 2 uses
# for `## In flight` row validation. We trust this shape; everything
# else gets rejected before `os.path.join` ever runs.
WORK_ITEM_PATH_RE = re.compile(r"^[a-z][a-z0-9_-]*/[a-zA-Z0-9][a-zA-Z0-9._-]*$")
# Shape of the slug after the `sdd/` prefix in a branch name. CLAUDE.md
# documents the convention as `sdd/<feature-id>-<slug>` — e.g.
# `sdd/001-user-auth`. Anchor the digits + hyphen so non-SDD branches
# like `sdd/release` or `sdd/main` can't accidentally override
# INDEX.md when a folder of that name happens to exist. Also blocks
# `sdd/../etc` since `..` doesn't start with a digit.
BRANCH_SLUG_RE = re.compile(r"^[0-9]+-[A-Za-z0-9][A-Za-z0-9._-]*$")

def is_inside_sdd(rel_path):
    """True iff joining `rel_path` to .sdd/ lands inside .sdd/ on the
    real filesystem. Guards against `..`, absolute paths, and symlink
    escapes — anyone can put text in INDEX.md, so we check before
    we trust the path. Trust-boundary doctrine: project data never
    becomes a directive."""
    full_real = os.path.realpath(os.path.join(sdd_root_real, rel_path))
    try:
        common = os.path.commonpath([sdd_root_real, full_real])
    except ValueError:
        return False  # different drives on Windows etc.
    return common == sdd_root_real and full_real != sdd_root_real

def emit(active, source, branch, index_active, ambiguous=False):
    out = {
        "active": active,
        "ambiguous": ambiguous,
        "branch": branch,
        "index_active": index_active,
        "source": source,
    }
    sys.stdout.write(json.dumps(out, sort_keys=True))
    sys.stdout.write("\n")

# 1. Current git branch (or None if not on a branch / not a repo).
branch = None
try:
    r = subprocess.run(
        ["git", "-C", proj, "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=5,
    )
    if r.returncode == 0:
        candidate = r.stdout.strip()
        # `HEAD` is what git emits in detached-HEAD state — not a branch.
        if candidate and candidate != "HEAD":
            branch = candidate
except (subprocess.TimeoutExpired, OSError, FileNotFoundError, UnicodeError):
    pass

# 2. Read INDEX.md's **Active:** pointer. The raw value is project
# data (anyone can write it), so we shape-check + containment-check
# before trusting it. Reject anything that's:
#   - absolute (/etc/passwd)
#   - path-traversal (../../tmp/evil)
#   - non-canonical (Foo/Bar — mixed case in folder segment)
#   - malformed in any way that doesn't match WORK_ITEM_PATH_RE
index_active = None
index_path = os.path.join(proj, ".sdd", "INDEX.md")
if os.path.isfile(index_path):
    try:
        # `errors="replace"` so a stray invalid UTF-8 byte (rare but
        # possible on Windows checkouts) doesn't crash the script and
        # break the "always emits JSON" contract.
        with open(index_path, encoding="utf-8", errors="replace") as f:
            idx_text = f.read()
    except (OSError, UnicodeError):
        idx_text = ""
    m = re.search(r"^\*\*Active:\*\*\s+(\S+)", idx_text, re.MULTILINE)
    if m:
        raw = m.group(1).strip()
        # Skip placeholders: "_(none)_", "_none_", "(none)" — anything
        # that's parens / underscores / "none" with no real path.
        is_placeholder = bool(re.match(r"^[_()\s]*none[_()\s]*$", raw, re.IGNORECASE))
        if (raw and not is_placeholder
                and WORK_ITEM_PATH_RE.match(raw)
                and is_inside_sdd(raw)):
            index_active = raw

# 3. Branch-derived active. Branch shape `sdd/<slug>` maps to a folder
# `<work-item-folder>/<slug>/` under .sdd/. Scan all top-level subdirs
# of .sdd/ for ALL folders matching `<slug>` with a spec.md inside.
# Slug validated against BRANCH_SLUG_RE so `sdd/../escape` can't be
# used to escape .sdd/ via os.path.join.
#
# Ambiguity handling: if the same `<slug>` exists under multiple top-
# level folders (e.g. `features/001-foo/` AND `bugs/001-foo/`), we
# fail closed — `active` stays None, source becomes "none", and the
# `ambiguous` flag goes true so callers can render a "rename one of
# these folders" warning instead of silently picking by sort order.
branch_active = None
branch_ambiguous = False
if branch:
    m = re.match(r"^sdd/(.+)$", branch)
    if m:
        slug = m.group(1)
        if BRANCH_SLUG_RE.match(slug) and os.path.isdir(sdd_root_real):
            try:
                tops = sorted(os.listdir(sdd_root_real))
            except OSError:
                tops = []
            matches = []
            for top in tops:
                if top.startswith(".") or top.startswith("_"):
                    continue
                candidate_dir = os.path.join(sdd_root_real, top, slug)
                spec_md = os.path.join(candidate_dir, "spec.md")
                if os.path.isfile(spec_md) and is_inside_sdd(f"{top}/{slug}"):
                    matches.append(f"{top}/{slug}")
            if len(matches) == 1:
                branch_active = matches[0]
            elif len(matches) > 1:
                branch_ambiguous = True

# 4. Resolve and emit.
if branch_active:
    emit(branch_active, "branch", branch, index_active)
elif branch_ambiguous:
    # Fail-closed on multi-match: don't pick one silently. Caller
    # (e.g. /status) reads `ambiguous: true` and tells the user to
    # rename one of the matching folders.
    emit(None, "none", branch, index_active, ambiguous=True)
elif index_active:
    # Validate that the INDEX pointer actually exists on disk AND has
    # a spec.md inside. We already shape-checked + containment-checked
    # above, but a non-folder path or a folder without spec.md is
    # still treated as a broken pointer.
    full = os.path.realpath(os.path.join(sdd_root_real, index_active))
    spec_md = os.path.join(full, "spec.md")
    if os.path.isdir(full) and os.path.isfile(spec_md):
        emit(index_active, "index", branch, index_active)
    else:
        # Pointer is broken — surface as none, but keep index_active
        # populated so callers can warn the user.
        emit(None, "none", branch, index_active)
else:
    emit(None, "none", branch, index_active)
PYEOF
