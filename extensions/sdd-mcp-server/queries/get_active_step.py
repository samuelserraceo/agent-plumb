"""get_active_step — what's the active feature's current open step?

Reads `.sdd/INDEX.md` for the `**Active:**` line, parses the feature path,
opens that spec.md, finds the `[PHASE: X]` line, then walks the matching
`## PHASE: X` body for the first open `- [ ] <step-id>: <prompt>` row
that isn't a work-item placeholder (AC<N> / T<N> / C-<N>).

Returns a flat dict — no nesting — so the caller can render it directly:

    {
      "feature_path": ".sdd/features/001-waitlist",
      "phase": "BUILD",
      "step_id": "task-003",
      "step_prompt": "form submission produces success state",
      "step_field": "tests/task-003.mjs"
    }

On any failure (no INDEX.md, no active feature, no spec.md, no open step)
returns `{"error": "<plain-english reason>"}`.
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict


# Lines that look like step rows but are owned by other mechanisms
# (acceptance criteria, build tasks, constraints) — skip them when
# locating the *workflow* blocker that drives /next.
_PLACEHOLDER_RE = re.compile(r"^\s*-\s*\[ \]\s+(AC|T|C-)[A-Za-z0-9_-]")
_STEP_RE = re.compile(r"^\s*-\s*\[ \]\s+([A-Za-z0-9_-]+)\s*:\s*(.+?)\s*$")
_ACTION_RE = re.compile(r"^###\s+action:\s+([a-z][a-z0-9_-]*)\s*$")
_PHASE_TAG_RE = re.compile(r"^\[PHASE:\s*([A-Z]+)\]")
_FIELD_RE = re.compile(r"^\s*-\s*\[ \]\s+[A-Za-z0-9_-]+\s*:.+?(?:→|->)\s*(.+?)\s*$")


def _parse_active_line(index_text: str) -> str | None:
    """Pull the feature path out of `**Active:** features/001-foo  [PHASE]  ...`.

    Returns the path (e.g. `features/001-waitlist`) or None if no active
    feature is declared (the template ships with `_(none)_`).
    """
    for line in index_text.splitlines():
        m = re.match(r"^\*\*Active:\*\*\s+(.+)$", line.strip())
        if not m:
            continue
        rest = m.group(1).strip()
        if rest.startswith("_") or rest.lower().startswith("(none"):
            return None
        # Path is the first whitespace-delimited token.
        return rest.split()[0]
    return None


def get_active_step(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    """Return the active feature's current open step (or an error dict)."""
    index_path = os.path.join(project_root, ".sdd", "INDEX.md")
    if not os.path.isfile(index_path):
        return {"error": f"INDEX.md not found at {index_path}"}

    try:
        with open(index_path, encoding="utf-8") as fh:
            index_text = fh.read()
    except OSError as exc:
        return {"error": f"cannot read INDEX.md: {exc}"}

    feature_path = _parse_active_line(index_text)
    if not feature_path:
        return {"error": "no active feature in INDEX.md"}

    # The Active line is relative to .sdd/. Normalise to a project-relative
    # path that includes the .sdd/ prefix so the answer can be pasted into
    # any tooling that operates on the repo root.
    if not feature_path.startswith(".sdd/"):
        rel_path = os.path.join(".sdd", feature_path)
    else:
        rel_path = feature_path

    spec_path = os.path.join(project_root, rel_path, "spec.md")
    if not os.path.isfile(spec_path):
        return {"error": f"spec.md not found at {rel_path}/spec.md"}

    try:
        with open(spec_path, encoding="utf-8") as fh:
            spec_lines = fh.read().split("\n")
    except OSError as exc:
        return {"error": f"cannot read spec.md: {exc}"}

    # Find the active phase tag.
    phase = None
    for line in spec_lines:
        m = _PHASE_TAG_RE.match(line)
        if m:
            phase = m.group(1)
            break
    if not phase:
        return {"error": "no [PHASE: X] line in spec.md"}

    # Walk the matching `## PHASE: X` body, skipping fenced code blocks
    # and work-item placeholders, capturing the first open step row.
    target_heading = f"## PHASE: {phase}"
    in_phase = False
    in_fence = False
    active_action = None

    for line in spec_lines:
        if line.startswith("## "):
            if line.strip() == target_heading:
                in_phase = True
                in_fence = False
                active_action = None
                continue
            if in_phase:
                # Left the active phase body without finding an open step.
                break
            continue
        if not in_phase:
            continue
        if re.match(r"^\s*```", line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        am = _ACTION_RE.match(line)
        if am:
            active_action = am.group(1)
            continue
        if _PLACEHOLDER_RE.match(line):
            continue
        sm = _STEP_RE.match(line)
        if not sm:
            continue
        step_id, raw_prompt = sm.group(1), sm.group(2)
        # Trim "→ field" suffix from the prompt for readability.
        field = None
        fm = _FIELD_RE.match(line)
        if fm:
            field = fm.group(1).strip()
            raw_prompt = re.sub(r"\s*(?:→|->)\s*.+$", "", raw_prompt).strip()
        return {
            "feature_path": rel_path,
            "phase": phase,
            "action": active_action,
            "step_id": step_id,
            "step_prompt": raw_prompt,
            "step_field": field,
        }

    return {
        "feature_path": rel_path,
        "phase": phase,
        "error": f"no open [ ] step in PHASE: {phase}",
    }
