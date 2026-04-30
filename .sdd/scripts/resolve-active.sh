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

# 2. Read INDEX.md's **Active:** pointer.
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
        if raw and not is_placeholder and "/" in raw:
            index_active = raw

# 3. Branch-derived active. Branch shape `sdd/<slug>` maps to a folder
# `<work-item-folder>/<slug>/` under .sdd/. Scan all top-level subdirs
# of .sdd/ for one matching `<slug>` with a spec.md inside.
branch_active = None
if branch:
    m = re.match(r"^sdd/(.+)$", branch)
    if m:
        slug = m.group(1)
        sdd_root = os.path.join(proj, ".sdd")
        if os.path.isdir(sdd_root):
            try:
                tops = sorted(os.listdir(sdd_root))
            except OSError:
                tops = []
            for top in tops:
                if top.startswith(".") or top.startswith("_"):
                    continue
                candidate_dir = os.path.join(sdd_root, top, slug)
                spec_md = os.path.join(candidate_dir, "spec.md")
                if os.path.isfile(spec_md):
                    branch_active = f"{top}/{slug}"
                    break  # first match wins (deterministic by sort order)

# 4. Resolve and emit.
if branch_active:
    emit(branch_active, "branch", branch, index_active)
elif index_active:
    # Validate that the INDEX pointer actually exists on disk.
    full = os.path.join(proj, ".sdd", index_active)
    if os.path.isdir(full):
        emit(index_active, "index", branch, index_active)
    else:
        # Pointer is broken — surface as none, but keep index_active
        # populated so callers can warn the user.
        emit(None, "none", branch, index_active)
else:
    emit(None, "none", branch, index_active)
PYEOF
