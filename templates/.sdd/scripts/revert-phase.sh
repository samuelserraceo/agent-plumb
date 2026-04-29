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
#   0 — spec.md updated (or no-op if already in <to-phase>)
#   1 — usage error or validation error (stderr explains)
#
# This script is deliberately phase-agnostic: it doesn't hardcode SPEC /
# BUILD / SHIP. The caller declares which phase to revert from and to;
# the script resolves the playbook ordering at runtime to know which
# phases count as "downstream" of <to-phase>.

set -uo pipefail

if [ $# -lt 3 ]; then
  echo "revert-phase.sh: usage: revert-phase.sh <spec-path> <from-phase> <to-phase>" >&2
  exit 1
fi

SPEC_PATH="$1"
FROM_PHASE="$2"
TO_PHASE="$3"

if [ ! -f "$SPEC_PATH" ]; then
  echo "revert-phase.sh: spec not found at $SPEC_PATH" >&2
  exit 1
fi

# Resolve the project root from the spec path so we can find the playbook.
PROJECT_DIR="$(cd "$(dirname "$SPEC_PATH")/../../.." 2>/dev/null && pwd)"
if [ ! -d "$PROJECT_DIR/.sdd" ]; then
  # Try one level up (in case spec is deeper)
  PROJECT_DIR="$(cd "$(dirname "$SPEC_PATH")" && git rev-parse --show-toplevel 2>/dev/null)"
fi

if [ -z "${PROJECT_DIR:-}" ] || [ ! -d "$PROJECT_DIR/.sdd" ]; then
  echo "revert-phase.sh: cannot resolve project root with .sdd/ from $SPEC_PATH" >&2
  exit 1
fi

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

# 2. Resolve the playbook's phase ordering. Reads `.sdd/playbooks/feature.md`
# (or whatever playbook the spec uses). For now we use the canonical 3-phase
# spine SPEC → BUILD → SHIP → SHIPPED — the playbook ordering is loaded from
# the active playbook below.
def _load_playbook_phases(proj_dir):
    """Return a list of phase IDs in playbook order. Reads feature.md
    (the only playbook with a phase-revert use case today). Falls back
    to the canonical 3-phase spine if the playbook is unreadable."""
    pb_path = os.path.join(proj_dir, ".sdd", "playbooks", "feature.md")
    if not os.path.isfile(pb_path):
        return ["SPEC", "BUILD", "SHIP", "SHIPPED"]
    try:
        import yaml
    except ImportError:
        return ["SPEC", "BUILD", "SHIP", "SHIPPED"]
    try:
        with open(pb_path, encoding="utf-8") as f:
            pb_text = f.read()
        # Parse YAML frontmatter between --- markers.
        fm_match = re.match(r"^---\n(.*?)\n---", pb_text, re.DOTALL)
        if not fm_match:
            return ["SPEC", "BUILD", "SHIP", "SHIPPED"]
        fm = yaml.safe_load(fm_match.group(1))
        stages = fm.get("stages", [])
        phases = [s.get("id", "").upper() for s in stages if s.get("id")]
        # Append the terminal state if declared.
        terminal = fm.get("terminal_state", "").upper()
        if terminal and terminal not in phases:
            phases.append(terminal)
        return phases or ["SPEC", "BUILD", "SHIP", "SHIPPED"]
    except Exception:
        return ["SPEC", "BUILD", "SHIP", "SHIPPED"]

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
# Track which `## PHASE:` section we're in. Stop tracking when we hit the
# next `## PHASE:` heading.
out_lines = []
current_phase_section = None
for line in text.split("\n"):
    m_heading = re.match(r"^##\s+PHASE:\s*([A-Z]+)\s*$", line)
    if m_heading:
        current_phase_section = m_heading.group(1).strip().upper()
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
