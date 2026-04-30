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
# Resolution order (first match wins):
#   1. Branch-derived. If the current git branch matches `sdd/<slug>`
#      AND a work-item folder ending in `<slug>` exists under .sdd/
#      with a spec.md inside, that's the active. Source label: "branch".
#   2. INDEX.md fallback. Read the `**Active:**` line; if it points at
#      a real work-item folder, use it. Source label: "index".
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
  echo '{"active":null,"branch":null,"index_active":null,"source":"none"}'
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
# Shape of the slug after the `sdd/` prefix in a branch name. Must
# match a legitimate folder-name component of the path above so a
# malicious branch like `sdd/../etc` can't escape `.sdd/`.
BRANCH_SLUG_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]*$")

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

def emit(active, source, branch, index_active):
    out = {
        "active": active,
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
        capture_output=True, text=True, timeout=5,
    )
    if r.returncode == 0:
        candidate = r.stdout.strip()
        # `HEAD` is what git emits in detached-HEAD state — not a branch.
        if candidate and candidate != "HEAD":
            branch = candidate
except (subprocess.TimeoutExpired, OSError, FileNotFoundError):
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
        with open(index_path, encoding="utf-8") as f:
            idx_text = f.read()
    except OSError:
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
# of .sdd/ for one matching `<slug>` with a spec.md inside.
# Slug validated against BRANCH_SLUG_RE so `sdd/../escape` can't be
# used to escape .sdd/ via os.path.join.
branch_active = None
if branch:
    m = re.match(r"^sdd/(.+)$", branch)
    if m:
        slug = m.group(1)
        if BRANCH_SLUG_RE.match(slug) and os.path.isdir(sdd_root_real):
            try:
                tops = sorted(os.listdir(sdd_root_real))
            except OSError:
                tops = []
            for top in tops:
                if top.startswith(".") or top.startswith("_"):
                    continue
                candidate_dir = os.path.join(sdd_root_real, top, slug)
                spec_md = os.path.join(candidate_dir, "spec.md")
                if os.path.isfile(spec_md) and is_inside_sdd(f"{top}/{slug}"):
                    branch_active = f"{top}/{slug}"
                    break  # first match wins (deterministic by sort order)

# 4. Resolve and emit.
if branch_active:
    emit(branch_active, "branch", branch, index_active)
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
