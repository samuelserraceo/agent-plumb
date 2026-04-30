#!/usr/bin/env bash
# post-stop-lint.sh — tier-3 invariant health check at turn boundary
# (closes #86: Karpathy "compile" check between commits).
#
# The framework's other safety hooks fire on commit (pre-commit-rules.sh,
# pre-commit-stage-verified.sh, pre-commit-no-assumed-markers.sh). They
# catch what's about to land in a commit. But there's a gap BETWEEN
# commits — a turn that edits files but doesn't commit yet — where
# invariants can quietly drift without anything noticing.
#
# This Stop hook closes that gap. It runs at the end of every Claude Code
# turn, walks 7 framework invariants, and blocks the stop with a plain-
# English fix path if any drifted. Foundation 3 (never assume — always
# check) applied at turn boundary, not just commit boundary.
#
# The 9 invariants checked:
#   1. .sdd/INDEX.md has exactly one **Active:** line
#   2. .sdd/INDEX.md ## In flight lines all point at existing feature folders
#   3. Active feature's spec.md has a single [PHASE: X] line
#   4. spec.md has no duplicate task / AC IDs (T<n> or AC<n>)
#   5. .sdd/decisions.md is append-only relative to HEAD (no historical
#      entries mutated)
#   6. .sdd/.cache/manifest.json parses as JSON
#   7. Every [x] row in spec.md has a non-empty answer after the colon
#   8. Wiki-links [[slug]] in .sdd/ markdown all resolve to known nodes
#      (v1.0 graph layer; opt-in via the MCP server extension)
#   9. No NUL bytes in any tracked .sdd/ file (binary contamination)
#
# Wires up as a Claude Code Stop hook in settings.json. Stop hooks
# receive a JSON payload on stdin describing the session state, but
# this hook's invariants are filesystem-only — stdin is read and
# discarded so the hook plays nicely with the protocol.
#
# Exits:
#   0 — allow the stop (invariants intact OR no .sdd directory yet)
#   2 — block the stop (one or more invariants drifted; stderr explains)
#
# All checks run; violations collect into one report. Fail-fast would
# only show the user the first issue when the cause might be three
# unrelated drifts — better to surface the whole picture in one pass.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Drain stdin so Claude Code's Stop-hook protocol stays clean even
# though we don't use the payload.
cat >/dev/null 2>&1 || true

# No .sdd directory → not an SDD project; nothing to lint.
[ -d .sdd ] || exit 0

# Collect violations as one big stderr block at the end. Each entry is
# a self-contained block: "[stop-lint] <one-line headline>" then
# indented "Fix: <plain-English action>" lines.
violations=""
add_violation() {
  if [ -z "$violations" ]; then
    violations="$1"
  else
    violations="${violations}

$1"
  fi
}

# ============================================================
# Invariant 1 — INDEX.md has exactly one **Active:** line
# ============================================================
check_active_line() {
  local index=".sdd/INDEX.md"
  [ -f "$index" ] || return 0  # No INDEX.md → nothing to check
  local count
  # `grep -c` outputs the count AND exits 1 on zero matches, so `|| echo 0`
  # would append an extra "0" line, leaving count="0\n0" which breaks the
  # arithmetic test below. Use `|| true` to swallow the exit code without
  # touching stdout.
  count=$(grep -cE '^\*\*Active:\*\*' "$index" 2>/dev/null || true)
  if [ "$count" -eq 0 ]; then
    add_violation "[stop-lint] .sdd/INDEX.md has no **Active:** line.
  Fix: add one line at the top of INDEX.md in this shape:
       \`**Active:** _(none)_\`  (when nothing is in flight)
       \`**Active:** features/<id>-<slug>   [PHASE]   blocker: §<N>\`  (when working on something)"
  elif [ "$count" -gt 1 ]; then
    local lines
    lines=$(grep -nE '^\*\*Active:\*\*' "$index" 2>/dev/null | head -3 || true)
    add_violation "[stop-lint] .sdd/INDEX.md has $count **Active:** lines (must be exactly one).
  Found at:
$(echo "$lines" | sed 's/^/    /')
  Fix: keep only the line that points at the feature you're actually working on.
       Delete the others. The Active line is the single pointer for hooks and /next."
  fi
}

# ============================================================
# Invariant 2 — every line under ## In flight points at an existing
# folder under .sdd/features/ (or .sdd/<other-playbook>/).
# ============================================================
check_in_flight_paths() {
  local index=".sdd/INDEX.md"
  [ -f "$index" ] || return 0
  # Extract the body of the ## In flight section (lines from
  # "## In flight" up to the next "##" heading). Then pull paths
  # that look like "features/<id>" or "<playbook>/<id>" out of any
  # bullet line, and confirm each path resolves to an existing
  # folder under .sdd/.
  local result
  result=$(INDEX="$index" PROJECT_DIR="$PROJECT_DIR" python3 <<'PYEOF' 2>/dev/null || true
import os, re, sys

index = os.environ["INDEX"]
project_dir = os.environ["PROJECT_DIR"]

try:
    with open(index, encoding="utf-8") as f:
        text = f.read()
except OSError:
    sys.exit(0)

# Find the ## In flight section body.
m = re.search(r"^##\s+In flight\s*\n(.*?)(?=^##\s+|\Z)",
              text, re.MULTILINE | re.DOTALL)
if not m:
    sys.exit(0)
body = m.group(1)

# Path shape we accept: <playbook-slug>/<feature-id-slug>
# Both segments are lowercase / digits / hyphens / underscores.
# Matches "features/001-test", "bugs/004-broken", etc.
path_re = re.compile(r"\b([a-z][a-z0-9_-]*/[a-zA-Z0-9][a-zA-Z0-9._-]*)\b")
paths = set()
for line in body.split("\n"):
    s = line.strip()
    if not s or s.startswith("<!--"):
        continue
    if s.startswith("_(") and s.endswith(")_"):
        continue  # placeholder like "_(none yet)_"
    for m2 in path_re.finditer(line):
        p = m2.group(1)
        # Skip URLs (http://...), Git refs, backtick code spans the
        # regex catches incidentally.
        if p.startswith("http"):
            continue
        paths.add(p)

missing = []
for p in sorted(paths):
    full = os.path.join(project_dir, ".sdd", p)
    if not os.path.isdir(full):
        missing.append(p)

if missing:
    print("MISSING:" + ",".join(missing))
PYEOF
)
  if [ -n "$result" ] && [[ "$result" == MISSING:* ]]; then
    local missing_list
    missing_list="${result#MISSING:}"
    local pretty
    pretty=$(echo "$missing_list" | tr ',' '\n' | sed 's|^|    .sdd/|')
    add_violation "[stop-lint] .sdd/INDEX.md ## In flight references folders that don't exist:
$pretty
  Fix: either create the missing feature folder (.sdd/<playbook>/<id>/),
       or remove the orphan line from ## In flight in INDEX.md."
  fi
}

# ============================================================
# Helper — find the active feature folder. Pure path resolution: reads
# the **Active:** line and validates shape. Echoes the absolute path on
# stdout (or empty string if no active feature exists / shape invalid /
# folder missing).
#
# This is called from $(...) command-substitution by every per-feature
# check. Subshells discard variable changes — so this function MUST
# stay side-effect free. Drift on the Active pointer (broken shape,
# missing folder) is surfaced by `check_active_pointer_target` below,
# which runs in the main shell where add_violation persists.
# ============================================================
locate_active_feature_dir() {
  local index=".sdd/INDEX.md"
  [ -f "$index" ] || { echo ""; return 0; }
  local active_path
  active_path=$(awk '/^\*\*Active:\*\*/{print $2; exit}' "$index" 2>/dev/null || echo "")
  # Empty / placeholder → silent empty.
  if [ -z "$active_path" ] || echo "$active_path" | grep -qE '^[_()[:space:]]+$|^_\(none\)_$'; then
    echo ""
    return 0
  fi
  # Malformed shape → silent empty (check_active_pointer_target catches it).
  echo "$active_path" | grep -qE '^[a-z][a-z0-9_-]*/[a-zA-Z0-9][a-zA-Z0-9._-]*$' || { echo ""; return 0; }
  local full="$PROJECT_DIR/.sdd/$active_path"
  # Missing folder → silent empty (check_active_pointer_target catches it).
  [ -d "$full" ] || { echo ""; return 0; }
  echo "$full"
}

# ============================================================
# Invariant 1b — when **Active:** is non-empty AND not a placeholder,
# the value must match `<playbook>/<id-slug>` AND the folder must
# exist. Closes the silent-swallow bug flagged by CR on PR #93 cycle-1
# (`locate_active_feature_dir` was returning empty for both "not yet
# started" and "broken pointer", indistinguishable to invariants 3-7).
#
# Runs in the main shell (NOT via $()), so add_violation persists.
# ============================================================
check_active_pointer_target() {
  local index=".sdd/INDEX.md"
  [ -f "$index" ] || return 0
  local active_path
  active_path=$(awk '/^\*\*Active:\*\*/{print $2; exit}' "$index" 2>/dev/null || echo "")
  # Empty / placeholder → legitimate "nothing in flight"; no violation.
  if [ -z "$active_path" ] || echo "$active_path" | grep -qE '^[_()[:space:]]+$|^_\(none\)_$'; then
    return 0
  fi
  # Malformed shape.
  if ! echo "$active_path" | grep -qE '^[a-z][a-z0-9_-]*/[a-zA-Z0-9][a-zA-Z0-9._-]*$'; then
    add_violation "[stop-lint] .sdd/INDEX.md **Active:** value is malformed: '$active_path'.
  Expected shape: \`<playbook>/<id-slug>\` (e.g. \`features/001-auth\`).
  Or use the placeholder \`**Active:** _(none)_\` when nothing is in flight.
  Fix: edit the **Active:** line at the top of INDEX.md to one of those shapes."
    return 0
  fi
  # Shape valid but folder missing.
  local full="$PROJECT_DIR/.sdd/$active_path"
  if [ ! -d "$full" ]; then
    add_violation "[stop-lint] .sdd/INDEX.md **Active:** points at \`$active_path\` but \`.sdd/$active_path/\` does not exist.
  This usually means the folder was deleted, renamed, or the Active line
  was edited to point at a feature that was never created.
  Fix: either restore the folder, rename the Active value to match the
  current folder, or set \`**Active:** _(none)_\` if nothing is in flight."
  fi
}

# ============================================================
# Invariant 3 — active feature's spec.md has exactly one [PHASE: X] line
# ============================================================
check_phase_line() {
  local active_dir
  active_dir=$(locate_active_feature_dir)
  [ -z "$active_dir" ] && return 0  # No active feature → nothing to check
  local spec="$active_dir/spec.md"
  [ -f "$spec" ] || return 0  # spec not yet created
  local count
  # See note on the matching pattern in check_active_line: `|| true` not `|| echo 0`.
  count=$(grep -cE '^\[PHASE:[[:space:]]+[A-Z]+\]' "$spec" 2>/dev/null || true)
  if [ "$count" -eq 0 ]; then
    add_violation "[stop-lint] active spec.md has no [PHASE: X] line.
  Spec: ${spec#$PROJECT_DIR/}
  Fix: every spec.md needs a [PHASE: SPEC] / [PHASE: BUILD] / [PHASE: SHIP] /
       [PHASE: SHIPPED] line at the top. If you reverted a phase advance,
       restore the line to the correct phase."
  elif [ "$count" -gt 1 ]; then
    local lines
    lines=$(grep -nE '^\[PHASE:[[:space:]]+[A-Z]+\]' "$spec" 2>/dev/null | head -3 || true)
    add_violation "[stop-lint] active spec.md has $count [PHASE: X] lines (must be exactly one).
  Spec: ${spec#$PROJECT_DIR/}
  Found at:
$(echo "$lines" | sed 's/^/    /')
  Fix: keep one phase line at the top. Phase advance happens by EDITING the
       single line, not by adding a second one."
  fi
}

# ============================================================
# Invariant 4 — spec.md has no duplicate task / AC IDs.
# Catches AC1 listed twice, T003 listed twice, etc. Duplicates make
# verify-stage's checkbox accounting silently inconsistent.
# ============================================================
check_duplicate_ids() {
  local active_dir
  active_dir=$(locate_active_feature_dir)
  [ -z "$active_dir" ] && return 0
  local spec="$active_dir/spec.md"
  [ -f "$spec" ] || return 0
  local result
  result=$(SPEC="$spec" python3 <<'PYEOF' 2>/dev/null || true
import os, re, sys

spec = os.environ["SPEC"]
try:
    with open(spec, encoding="utf-8") as f:
        text = f.read()
except OSError:
    sys.exit(0)

# Match either "AC<n>" or "T<n>" / "T<NNN>" at the start of a checkbox
# line's content. Examples we want to catch:
#   - [ ] AC1: Form ...
#   - [x] T003: write test ...
# Don't match prose mentions of "T1" mid-sentence — only when
# they sit right after the checkbox + colon.
id_re = re.compile(r"^\s*-\s*\[[xX ]\]\s+(T\d+|AC\d+)\b", re.MULTILINE)
ids = id_re.findall(text)

dups = {}
for tid in ids:
    dups[tid] = dups.get(tid, 0) + 1
duplicates = sorted(t for t, c in dups.items() if c > 1)
if duplicates:
    print("DUPS:" + ",".join(duplicates))
PYEOF
)
  if [ -n "$result" ] && [[ "$result" == DUPS:* ]]; then
    local dup_list="${result#DUPS:}"
    local pretty
    pretty=$(echo "$dup_list" | tr ',' '\n' | sed 's/^/    /')
    add_violation "[stop-lint] active spec.md has duplicate task / AC IDs:
$pretty
  Spec: ${spec#$PROJECT_DIR/}
  Fix: every AC and task ID must be unique. Renumber the duplicates
       (e.g. two AC3 rows → AC3 and AC4). Duplicates make verify-stage's
       count inconsistent and silently miss work."
  fi
}

# ============================================================
# Invariant 5 — .sdd/decisions.md is append-only relative to HEAD.
# Fetches the HEAD blob and confirms it's a strict prefix of the
# working-tree file (modulo the trailing newline). If working-tree
# bytes diverge from the HEAD prefix, an existing entry has been
# mutated.
# ============================================================
check_decisions_append_only() {
  local dec=".sdd/decisions.md"
  [ -f "$dec" ] || return 0
  # Need a git repo for this check.
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  local result
  result=$(DEC="$dec" PROJECT_DIR="$PROJECT_DIR" python3 <<'PYEOF' 2>/dev/null || true
import os, subprocess, sys

dec = os.environ["DEC"]
proj = os.environ["PROJECT_DIR"]

# Read the working-tree file.
try:
    with open(os.path.join(proj, dec), "rb") as f:
        wt = f.read()
except OSError:
    sys.exit(0)

# Fetch HEAD's blob. If decisions.md isn't yet in HEAD (e.g. brand-new
# project), nothing to check — exit silently.
try:
    r = subprocess.run(
        ["git", "show", f"HEAD:{dec}"],
        capture_output=True, cwd=proj, timeout=10,
    )
except Exception:
    sys.exit(0)
if r.returncode != 0:
    sys.exit(0)
head = r.stdout

# Append-only means: HEAD bytes are a prefix of WT bytes. We allow the
# user to add a trailing newline at the end of HEAD content (very common
# editor behaviour) — strip a single trailing \n from HEAD before the
# prefix check so a benign final-newline addition doesn't fire.
head_stripped = head.rstrip(b"\n") + (b"\n" if head.endswith(b"\n") else b"")
if wt.startswith(head_stripped) or wt.startswith(head):
    sys.exit(0)
# Try the lenient form: HEAD with possibly different trailing newlines.
if wt.startswith(head.rstrip(b"\n")):
    sys.exit(0)
# Working tree diverges from HEAD prefix → an existing entry was changed.
print("MUTATED")
PYEOF
)
  if [ "$result" = "MUTATED" ]; then
    add_violation "[stop-lint] .sdd/decisions.md was edited above the append line.
  decisions.md is the framework's append-only audit trail. Existing entries
  must never be modified — they are the project's history.
  Fix: \`git checkout HEAD -- .sdd/decisions.md\` to restore the file, then
       add your new entry by appending (with \`>>\`, never \`>\`)."
  fi
}

# ============================================================
# Invariant 6 — .sdd/.cache/manifest.json parses as JSON.
# A corrupt manifest silently disables the moat's hash-pin check.
# ============================================================
check_manifest_json() {
  local mf=".sdd/.cache/manifest.json"
  [ -f "$mf" ] || return 0  # Manifest absent (e.g. early bootstrap) → skip
  if ! python3 -c "import json,sys; json.load(open('$mf'))" >/dev/null 2>&1; then
    local err
    err=$(python3 -c "import json,sys
try: json.load(open('$mf'))
except Exception as e: print(str(e))" 2>&1 | head -1)
    add_violation "[stop-lint] .sdd/.cache/manifest.json is not valid JSON.
  Parser said: $err
  The manifest is the moat's trust anchor — corruption disables the
  framework's tampering check.
  Fix: \`git checkout HEAD -- .sdd/.cache/manifest.json\` to restore the
       file. If you legitimately edited it, run the framework's manifest
       regenerator instead of hand-editing."
  fi
}

# ============================================================
# Invariant 7 — every [x] row in spec.md has a non-empty answer.
# Catches the shape "- [x] who: " (ticked but blank) — the agent
# claimed it answered the prompt but the answer is empty.
# ============================================================
check_ticked_rows_have_answers() {
  local active_dir
  active_dir=$(locate_active_feature_dir)
  [ -z "$active_dir" ] && return 0
  local spec="$active_dir/spec.md"
  [ -f "$spec" ] || return 0
  local result
  result=$(SPEC="$spec" python3 <<'PYEOF' 2>/dev/null || true
import os, re, sys

spec = os.environ["SPEC"]
try:
    with open(spec, encoding="utf-8") as f:
        text = f.read()
except OSError:
    sys.exit(0)

# Match a checked checkbox row. Two shapes the framework writes:
#   - [x] <step-id>: <answer>
#   - [x] <heading text>
# We only flag the first shape (with a colon) when the answer
# after the colon is empty / whitespace. The second shape (no colon)
# is fine — `- [x] §1 Problem` from the rubric is legitimately bare.
empty_re = re.compile(r"^(\s*-\s*\[[xX]\]\s+[^:\n]+:)(\s*)$", re.MULTILINE)
lines_offending = []
for i, line in enumerate(text.split("\n"), start=1):
    m = empty_re.match(line)
    if m:
        lines_offending.append((i, line.rstrip()))

if lines_offending:
    print("EMPTY:" + str(len(lines_offending)))
    for i, ln in lines_offending[:5]:
        print(f"  line {i}: {ln}")
PYEOF
)
  if [ -n "$result" ] && [[ "$result" == EMPTY:* ]]; then
    local first_line
    first_line=$(echo "$result" | head -1)
    local count="${first_line#EMPTY:}"
    local samples
    samples=$(echo "$result" | tail -n +2 | head -5)
    add_violation "[stop-lint] active spec.md has $count ticked-but-blank rows.
  Spec: ${spec#$PROJECT_DIR/}
  Sample:
$samples
  Fix: either fill the answer after the colon, or revert the row to \`[ ]\`.
       A row marked [x] but blank means the agent claimed an answer that
       isn't actually written down — never assume, always check."
  fi
}

# ============================================================
# Invariant 8 — every wiki-link in .sdd/ markdown resolves to a real node.
#
# v1.0 graph layer: cross-references between markdown atoms become
# first-class via `[[slug]]` syntax. A broken link means a node was
# renamed/deleted without updating its citers, OR a citer assumed a
# pattern/entity exists that doesn't.
#
# Foundation 3 ("never assume — always check") applied to retrieval:
# don't trust that wiki-links are honest; verify each resolves at
# turn-boundary so drift surfaces before commit-time.
#
# Wiki-link grammar accepted (refused if extended):
#   - [[001-waitlist]]            (feature folder)
#   - [[entity:User]]             (data-model.md heading)
#   - [[pattern:auth-retry]]      (patterns.md heading)
# NO section anchors (#section), NO display aliases (|alias).
#
# Implementation: shells out to a Python helper that uses the MCP
# server's _graph_cache module — same path the queries use, so the
# stop-hook's view of "broken" is exactly what `get_backlinks` sees.
# Falls back to silent pass if the MCP server isn't available
# (extension is optional; this hook is mandatory).
# ============================================================
check_no_nul_bytes() {
  # D4 (stress-test) — NUL bytes (0x00) in any tracked .sdd/ markdown file
  # signal binary contamination (corrupt save, half-written file, byte-flip
  # on a flaky disk). Catches them at turn boundary so the user fixes the
  # corrupt file before committing it.
  if [ ! -d .sdd ]; then return 0; fi
  local hits
  hits=$(LC_ALL=C grep -rlP '\x00' .sdd/ 2>/dev/null \
         --include='*.md' --include='*.json' --include='*.yaml' --include='*.yml' \
         --exclude-dir='.cache' --exclude-dir='archive' --exclude-dir='ideas' || true)
  if [ -n "$hits" ]; then
    # CR Minor #6 fix — quote $hits via newline-IFS read so paths with
    # spaces don't get word-split into garbage args (SC2086).
    local formatted=""
    while IFS= read -r path; do
      [ -n "$path" ] && formatted="${formatted}  ${path}"$'\n'
    done <<< "$hits"
    add_violation "[stop-lint] NUL bytes found in framework files (binary contamination):
${formatted}  Fix: open the file in your editor and save again as UTF-8 (text). NUL
       bytes usually mean a half-written save or filesystem corruption.
       If the file is unrecoverable, restore it: \`git checkout HEAD -- <path>\`."
  fi
}

check_wiki_links_resolve() {
  local mcp_root="$PROJECT_DIR/extensions/sdd-mcp-server"
  # When running on a downstream user's project, the MCP server lives at the
  # framework's own path — try a few common locations.
  if [ ! -d "$mcp_root" ]; then
    # Fall back to the framework-bundled copy if installed via plugin path.
    local plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
    if [ -n "$plugin_root" ] && [ -d "$plugin_root/extensions/sdd-mcp-server" ]; then
      mcp_root="$plugin_root/extensions/sdd-mcp-server"
    else
      return 0  # MCP server not present; graph layer is opt-in via extension
    fi
  fi
  local result
  # CR cycle-2 Major — when the graph checker is FOUND but BROKEN (import
  # error, exception during build, etc.), surface that as ERROR so the user
  # sees invariant 8 has been silently disabled. Old code exited 0 in that
  # branch, hiding broken wiki-links exactly when graph code had drifted.
  result=$(MCP_ROOT="$mcp_root" PROJECT_DIR="$PROJECT_DIR" python3 <<'PYEOF' 2>&1
import os, sys
sys.path.insert(0, os.environ["MCP_ROOT"])
try:
    from queries import _graph_cache
except ImportError as exc:
    print(f"ERROR:import failed — {type(exc).__name__}: {exc}")
    sys.exit(0)
proj = os.environ["PROJECT_DIR"]
try:
    g = _graph_cache.build(proj)
except Exception as exc:
    print(f"ERROR:graph cache build failed — {type(exc).__name__}: {exc}")
    sys.exit(0)
broken = _graph_cache.find_broken_edges(g)
if not broken:
    sys.exit(0)
print(f"BROKEN:{len(broken)}")
for e in broken[:5]:
    raw = e.get("raw") or e.get("to_path", "?")
    src = e.get("from_path", "?")
    line = e.get("from_line", "?")
    print(f"  {src}:{line}  [[{raw}]]")
PYEOF
)
  if [ -n "$result" ] && [[ "$result" == BROKEN:* ]]; then
    local first_line
    first_line=$(echo "$result" | head -1)
    local count="${first_line#BROKEN:}"
    local samples
    samples=$(echo "$result" | tail -n +2 | head -5)
    add_violation "[stop-lint] $count wiki-link(s) don't resolve to a known node.
  Sample (showing first 5):
$samples
  Fix: either rename the link to match an existing node (feature folder, pattern
       heading in patterns.md, or entity heading in data-model.md), or create
       the target node. Run \`get_backlinks(slug)\` via the MCP server to see
       what cites a node before renaming it."
  elif [ -n "$result" ] && [[ "$result" == ERROR:* ]]; then
    # The graph checker is present but failed to run — surface that as a
    # violation so invariant 8 isn't silently disabled when the graph code
    # itself has drifted (CR cycle-2 Major).
    add_violation "[stop-lint] invariant 8 (wiki-link resolution) couldn't run because the
  graph cache helper failed. Wiki-links are NOT being checked this turn.
  Detail: ${result#ERROR:}
  Fix: investigate why \`extensions/sdd-mcp-server/queries/_graph_cache.py\`
       can't be imported / can't build the graph. Common causes: a syntax error
       in a recent edit, a missing dependency, or a malformed .sdd/ tree that
       trips the walker. The other 8 invariants still ran."
  fi
}

# ============================================================
# Run all checks. Each adds to $violations on drift; nothing exits
# early — we want the user to see the whole picture in one pass.
# ============================================================
check_active_line
check_active_pointer_target
check_in_flight_paths
check_phase_line
check_duplicate_ids
check_decisions_append_only
check_manifest_json
check_ticked_rows_have_answers
check_wiki_links_resolve
check_no_nul_bytes

# Happy path: no violations → silent allow.
[ -z "$violations" ] && exit 0

cat >&2 <<EOF
The end-of-turn health check found framework drift since the last
commit. The framework hooks at commit time would catch this later, but
this turn-boundary check surfaces it now so you don't lose context
before the next session starts.

$violations

Fix the items above, then continue. If you genuinely want the stop to
proceed without fixing (rare — only for a recovery operation you've
already planned), bypass by clearing the .sdd/INDEX.md / spec.md drift
manually. The check runs every turn, so any new drift will fire again.
EOF
exit 2
