"""get_decisions_since — read entries from .sdd/decisions.md after a given date.

Args: `{"since": "2026-04-28T00:00:00Z"}`

decisions.md is append-only; each entry is one level-2 heading of the form:

    ## <ISO-Z timestamp>  [<work-item-id>]  <playbook>/<action>
    <one-paragraph plain-English summary>
    Hash: <sha256> (optional)

We parse heading lines, keep only entries whose timestamp >= since, and
return them in order they appear (which is chronological because the file
is append-only).

The timestamp comparison is lexicographic on ISO-8601 strings — that's
correct because `Z`-suffixed UTC strings sort the same way as their
real-time order. We don't pull in `dateutil`; the framework's stdlib +
PyYAML budget is enough.
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict, List


# Heading regex: `##` + spaces + ISO-Z timestamp + `  [item]  playbook/action`
_ENTRY_RE = re.compile(
    r"^##\s+"
    r"(?P<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z)"
    r"\s+\[(?P<item>[^\]]+)\]"
    r"\s+(?P<action>\S+)"
    r"\s*$"
)
_HASH_RE = re.compile(r"^Hash:\s*([a-f0-9]+)\s*$", re.IGNORECASE)


def _normalise_iso(s: str) -> str:
    """Loose ISO-Z normalisation: ensure trailing 'Z' for lexicographic
    comparison. Accepts `2026-04-28`, `2026-04-28T00:00:00Z`, etc.

    Returns the input as-is if it already looks like an ISO-Z timestamp;
    pads incomplete dates with `T00:00:00Z` so comparisons work.
    """
    s = s.strip()
    if re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$", s):
        return s
    if re.match(r"^\d{4}-\d{2}-\d{2}$", s):
        return s + "T00:00:00Z"
    if re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$", s):
        return s + "Z"
    return s  # let caller see odd input verbatim; comparison will still try


def get_decisions_since(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    since_raw = (args or {}).get("since")
    if not since_raw:
        return {"error": "missing arg 'since' — e.g. '2026-04-28T00:00:00Z' or '2026-04-28'"}
    since = _normalise_iso(str(since_raw))

    dec_path = os.path.join(project_root, ".sdd", "decisions.md")
    if not os.path.isfile(dec_path):
        return {"error": f"decisions.md not found at {dec_path}"}
    try:
        with open(dec_path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except OSError as exc:
        return {"error": f"cannot read decisions.md: {exc}"}

    entries: List[Dict[str, Any]] = []
    current = None  # accumulator for the entry being built
    for line in lines:
        m = _ENTRY_RE.match(line)
        if m:
            if current is not None:
                entries.append(current)
            current = {
                "timestamp": m.group("ts"),
                "work_item": m.group("item").strip(),
                "action": m.group("action").strip(),
                "summary": "",
                "hash": None,
            }
            continue
        if current is None:
            continue
        # Stop accumulating when we hit a new level-2 heading (handled above)
        # or a blank line followed by another section. For robustness we keep
        # appending non-heading lines into summary and overwrite hash if seen.
        if line.startswith("## "):
            # different (non-entry) heading — flush current and reset
            entries.append(current)
            current = None
            continue
        hm = _HASH_RE.match(line.strip())
        if hm:
            current["hash"] = hm.group(1)
            continue
        if line.strip() == "":
            # Blank line ends the summary paragraph; ignore further blanks.
            continue
        current["summary"] = (current["summary"] + " " + line.strip()).strip()

    if current is not None:
        entries.append(current)

    matched = [e for e in entries if e["timestamp"] >= since]
    return {"since": since, "entries": matched}
