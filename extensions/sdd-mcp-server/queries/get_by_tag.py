"""get_by_tag — list features in a given INDEX.md status section.

Args: `{"tag": "in-flight" | "shipped" | "blocked" | "backlog"}`

Reads `.sdd/INDEX.md` and parses the named status section. Each non-empty
line under the section heading is treated as one feature entry. We try
hard not to fabricate structure — INDEX.md is hand-edited, so we surface
what's there as plain strings plus a best-effort id/summary parse.

Recognised section headings (case-insensitive):
    `## In flight`     -> tag "in-flight"
    `## Shipped`       -> tag "shipped"
    `## Backlog`       -> tag "backlog"
    `## Blocked`       -> tag "blocked"   (not in template; supported if user adds)
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict, List


_HEADING_FOR_TAG = {
    "in-flight": "## In flight",
    "shipped": "## Shipped",
    "backlog": "## Backlog",
    "blocked": "## Blocked",
}

_PHASE_HINT_RE = re.compile(r"\[(SPEC|BUILD|SHIP|SHIPPED|RESEARCH)\]", re.IGNORECASE)
_FEATURE_PATH_RE = re.compile(r"features/([A-Za-z0-9_-]+)")


def _slice_section(lines: List[str], heading: str) -> List[str]:
    """Return the body lines under `heading` (level-2), stopping at the
    next level-2 heading.
    """
    target = heading.lower().strip()
    out: List[str] = []
    capturing = False
    for line in lines:
        stripped = line.strip()
        if stripped.lower().startswith("## "):
            if stripped.lower() == target:
                capturing = True
                continue
            if capturing:
                break
            continue
        if capturing:
            out.append(line)
    return out


def _parse_entry(raw: str) -> Dict[str, Any]:
    """Best-effort parse of one INDEX.md feature line into {id, phase, summary}."""
    line = raw.strip().lstrip("-").strip()
    entry: Dict[str, Any] = {"raw": line}
    fm = _FEATURE_PATH_RE.search(line)
    if fm:
        entry["id"] = fm.group(1)
    pm = _PHASE_HINT_RE.search(line)
    if pm:
        entry["phase"] = pm.group(1).upper()
    # Summary = whatever follows the first em-dash / hyphen pair, else the
    # whole line minus the path token.
    if " — " in line:
        entry["summary"] = line.split(" — ", 1)[1].strip()
    elif " - " in line:
        entry["summary"] = line.split(" - ", 1)[1].strip()
    return entry


def get_by_tag(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    tag = (args or {}).get("tag")
    if not tag:
        return {"error": "missing arg 'tag' — one of: " + ", ".join(_HEADING_FOR_TAG)}
    tag = str(tag).strip().lower()
    heading = _HEADING_FOR_TAG.get(tag)
    if not heading:
        return {"error": f"unknown tag '{tag}' — try one of: {', '.join(_HEADING_FOR_TAG)}"}

    index_path = os.path.join(project_root, ".sdd", "INDEX.md")
    if not os.path.isfile(index_path):
        return {"error": f"INDEX.md not found at {index_path}"}
    try:
        with open(index_path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        return {"error": f"cannot read INDEX.md: {exc}"}

    body = _slice_section(text.split("\n"), heading)
    matches: List[Dict[str, Any]] = []
    in_html_comment = False
    for line in body:
        s = line.strip()
        # Track HTML-comment block state across lines so interior bullet
        # lines inside `<!-- ... -->` don't get picked up as fake feature
        # entries. A comment can span multiple lines:
        #   <!--
        #   - some example feature entry
        #   -->
        # Toggle on the opening token; stay inside until we see -->.
        if "<!--" in s and "-->" not in s:
            in_html_comment = True
            continue
        if in_html_comment:
            if "-->" in s:
                in_html_comment = False
            continue
        # Single-line comment (open + close on same line) — skip.
        if s.startswith("<!--") and s.endswith("-->"):
            continue
        if not s:
            continue
        # Skip the literal "_(none)_" / "_(empty)_" placeholders.
        if s.startswith("_(") and s.endswith(")_"):
            continue
        # Bullet lines only — the template uses bullets for entries.
        if not s.startswith("-"):
            continue
        matches.append(_parse_entry(s))
    return {"tag": tag, "matches": matches}
