#!/usr/bin/env bash
# revert-phase.sh — reset a spec.md from a later phase back to an earlier one.
#
# Used by adversarial-review's "fix now" path (and any future action that
# flips a feature back from a later phase to an earlier one). Without this
# helper, the agent flipped `[PHASE: SHIP]` → `[PHASE: BUILD]` but left
# the SHIP step rows still `[x]` from the first pass. On the second
# BUILD→SHIP transition, `next-action.sh` saw all SHIP rows ticked and
# transitioned straight through to SHIPPED — so adversarial-review never
# re-fired on the new code (the original v0.13.0 bug, closed by #65).
#
# Usage:
#   revert-phase.sh <spec-path> <from-phase> <to-phase>
#
#   spec-path:  path to the work-item's spec.md (relative to project root or absolute)
#   from-phase: the phase the spec is currently in (e.g. SHIP)
#   to-phase:   the phase to revert to (e.g. BUILD)
#
# What it does:
#   1. Validates: spec.md exists, current `[PHASE: X]` matches <from-phase>.
#   2. Rewrites the `[PHASE: <from>]` line to `[PHASE: <to>]`.
#   3. Walks the spec.md body. Under `## PHASE: <from>` and any phase that
#      comes AFTER it in the playbook, un-ticks every `- [x]` row back to
#      `- [ ]`. Phases at or before <to-phase> are untouched.
#   4. Writes the result back atomically (tempfile + rename).
#
# Exit:
#   0 — spec.md updated; one or more downstream phase sections un-ticked.
#   1 — usage error, validation error, or already-in-<to-phase> (stderr
#       explains). NOTE: the "already in to-phase" case is INTENTIONALLY
#       a non-zero exit, not a silent no-op — that would mask caller
#       bugs (e.g., calling revert-phase.sh twice). If a caller really
#       wants idempotency, they should grep `[PHASE: X]` themselves
#       before invoking this script.
#
# This script is deliberately phase-agnostic: it doesn't hardcode SPEC /
# BUILD / SHIP. The caller declares which phase to revert from and to;
# the script resolves the playbook ordering at runtime by reading the
# active playbook declared in INDEX.md (same pattern as next-action.sh).

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "revert-phase.sh: usage: revert-phase.sh <spec-path> <from-phase> <to-phase>" >&2
  echo "revert-phase.sh: got $# argument(s); expected exactly 3." >&2
  exit 1
fi

SPEC_PATH="$1"
FROM_PHASE="$2"
TO_PHASE="$3"

# Resolve PROJECT_DIR FIRST (before checking the spec exists), so a
# repository-relative SPEC_PATH like ".sdd/features/001-x/spec.md"
# works when this script is invoked from any CWD inside the project.
if [ -d "$(dirname "$SPEC_PATH")" ]; then
  PROJECT_DIR="$(cd "$(dirname "$SPEC_PATH")" && git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "${PROJECT_DIR:-}" ] || [ ! -d "$PROJECT_DIR/.sdd" ]; then
  PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "${PROJECT_DIR:-}" ] || [ ! -d "$PROJECT_DIR/.sdd" ]; then
  echo "revert-phase.sh: cannot resolve project root with .sdd/ from $SPEC_PATH" >&2
  exit 1
fi

# Resolve SPEC_PATH against PROJECT_DIR if it's relative. After this,
# RESOLVED_SPEC is always an absolute path that exists on disk.
case "$SPEC_PATH" in
  /*) RESOLVED_SPEC="$SPEC_PATH" ;;
  *)  RESOLVED_SPEC="$PROJECT_DIR/$SPEC_PATH" ;;
esac

if [ ! -f "$RESOLVED_SPEC" ]; then
  echo "revert-phase.sh: spec not found at $SPEC_PATH (looked under $PROJECT_DIR)" >&2
  exit 1
fi
SPEC_PATH="$RESOLVED_SPEC"

command -v python3 >/dev/null 2>&1 || {
  echo "revert-phase.sh: python3 required but not on PATH" >&2
  exit 1
}

SPEC="$SPEC_PATH" FROM="$FROM_PHASE" TO="$TO_PHASE" PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import os, re, sys, tempfile

spec_path  = os.environ["SPEC"]
from_phase = os.environ["FROM"].strip().upper()
to_phase   = os.environ["TO"].strip().upper()
proj       = os.environ["PROJ"]

with open(spec_path, encoding="utf-8") as f:
    text = f.read()

# 1. Sanity: current [PHASE: X] line must match from_phase.
m = re.search(r"^\[PHASE:\s*([A-Z]+)\]", text, re.MULTILINE)
if not m:
    print("revert-phase.sh: no [PHASE: X] line in spec.md", file=sys.stderr)
    sys.exit(1)
current = m.group(1).strip().upper()
# Validation: spec must be in <from_phase>. We deliberately do NOT
# accept "already in <to_phase>" as a silent no-op — that would mask
# caller bugs (e.g., calling revert-phase.sh twice). If the caller
# really wants idempotency, they can grep [PHASE:] themselves first.
if current != from_phase:
    print(f"revert-phase.sh: spec.md is in [PHASE: {current}], expected [PHASE: {from_phase}]",
          file=sys.stderr)
    sys.exit(1)

# 2. Resolve the playbook's phase ordering. Read the active playbook slug
# from INDEX.md (same pattern as next-action.sh — Lego foundation 2: each
# playbook owns its own phase sequence; this script reads what it declares).
# Falls back to "feature" if INDEX.md doesn't declare one, then to the
# canonical 3-phase spine if the playbook itself is unreadable.
def _load_playbook_phases(proj_dir):
    """Return a list of phase IDs in playbook order, derived from the
    active playbook's stages: frontmatter. Falls back to the canonical
    3-phase spine on any read/parse failure."""
    fallback = ["SPEC", "BUILD", "SHIP", "SHIPPED"]
    # Resolve the active playbook slug from INDEX.md, mirroring
    # next-action.sh's `**Playbook:** <slug>` lookup.
    playbook_slug = "feature"
    index_path = os.path.join(proj_dir, ".sdd", "INDEX.md")
    if os.path.isfile(index_path):
        try:
            with open(index_path, encoding="utf-8") as f:
                idx_text = f.read()
            mp = re.search(r'^\*\*Playbook:\*\*\s+(\S+)\s*$', idx_text, re.M)
            if mp and re.match(r'^[a-z][a-z0-9-]*$', mp.group(1)):
                playbook_slug = mp.group(1)
        except OSError:
            pass
    pb_path = os.path.join(proj_dir, ".sdd", "playbooks", f"{playbook_slug}.md")
    if not os.path.isfile(pb_path):
        return fallback
    try:
        import yaml
    except ImportError:
        return fallback
    try:
        with open(pb_path, encoding="utf-8") as f:
            pb_text = f.read()
        fm_match = re.match(r"^---\n(.*?)\n---", pb_text, re.DOTALL)
        if not fm_match:
            return fallback
        fm = yaml.safe_load(fm_match.group(1))
        stages = fm.get("stages", [])
        phases = [s.get("id", "").upper() for s in stages if s.get("id")]
        # Append the terminal state if declared.
        terminal = fm.get("terminal_state", "").upper()
        if terminal and terminal not in phases:
            phases.append(terminal)
        return phases or fallback
    except Exception:
        return fallback

phases = _load_playbook_phases(proj)
try:
    to_idx   = phases.index(to_phase)
    from_idx = phases.index(from_phase)
except ValueError:
    print(f"revert-phase.sh: phase IDs {from_phase}/{to_phase} not found in playbook (have: {phases})",
          file=sys.stderr)
    sys.exit(1)

if from_idx <= to_idx:
    print(f"revert-phase.sh: from_phase ({from_phase}) must come AFTER to_phase ({to_phase}) in the playbook",
          file=sys.stderr)
    sys.exit(1)

# Phases that need their step rows un-ticked: from_phase and any phase
# strictly downstream of to_phase up to and including from_phase.
to_untick = phases[to_idx + 1 : from_idx + 1]

# 3. Rewrite [PHASE: X] line.
text = re.sub(
    r"^\[PHASE:\s*[A-Z]+\]",
    f"[PHASE: {to_phase}]",
    text,
    count=1,
    flags=re.MULTILINE,
)

# 4. Walk lines, un-tick every `- [x]` under `## PHASE: <P>` for P in to_untick.
# Track which `## PHASE:` section we're in. Stop tracking when we hit either
# the next `## PHASE:` heading OR any other top-level `## ` heading (so an
# unrelated section like `## Notes` between two phase blocks doesn't extend
# the previous phase's scope into it).
out_lines = []
current_phase_section = None
for line in text.split("\n"):
    m_phase_heading = re.match(r"^##\s+PHASE:\s*([A-Z]+)\s*$", line)
    m_other_heading = re.match(r"^##\s+(?!PHASE:)", line)
    if m_phase_heading:
        current_phase_section = m_phase_heading.group(1).strip().upper()
        out_lines.append(line)
        continue
    if m_other_heading:
        # Any non-PHASE `## ` heading ends the previous phase section.
        # Sub-headings (`### ...`) do NOT reset — they're per-action
        # sub-sections inside the phase.
        current_phase_section = None
        out_lines.append(line)
        continue
    if current_phase_section in to_untick:
        # Un-tick: `- [x] ...` → `- [ ] ...` (case-sensitive on the X to
        # avoid touching anything that's not a checked task row).
        new_line = re.sub(r"^(\s*-\s*)\[x\](\s+)", r"\1[ ]\2", line)
        out_lines.append(new_line)
    else:
        out_lines.append(line)

new_text = "\n".join(out_lines)

# 5. Atomic write.
tmp_dir = os.path.dirname(spec_path) or "."
fd, tmp_path = tempfile.mkstemp(prefix=".spec.tmp.", dir=tmp_dir)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(new_text)
    os.replace(tmp_path, spec_path)
except Exception:
    if os.path.exists(tmp_path):
        os.unlink(tmp_path)
    raise

print(f"revert-phase.sh: reverted {os.path.basename(spec_path)} from {from_phase} to {to_phase}; "
      f"un-ticked rows in phases {to_untick}.")
PYEOF
