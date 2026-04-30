"""get_pattern — fetch one block from `.sdd/patterns.md` by slug.

patterns.md is sectioned with level-2 (`## Architecture decisions`) and
level-3 (`### <name>`) headings — the template ships only level-2 sections
but project-grown patterns commonly use level-3 entries inside them.
A "pattern" can be either, so we match both. Slug match is loose:
case-insensitive, hyphen/space-equivalent.

Returns:

    {"slug": "auth-retry-logic",
     "heading": "Auth retry logic",
     "level": 3,
     "content": "...the block prose...",
     "feature_source": "002-login"}   # parsed from the block if a
                                       # `Source:` / `from feature N`
                                       # line is present.

If not found:
    {"error": "pattern not found", "available": [{"slug": ..., "heading": ...}, ...]}
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict, List


_SOURCE_RE = re.compile(
    # Allow optional `[[…]]` wiki-link wrapping around the slug — v1.0
    # graph layer encourages writing `Source: [[<id>-<slug>]]` so the
    # pattern → feature edge gets indexed by the graph cache.
    # `[A-Za-z0-9_/-]+` captures the slug regardless of whether it's
    # wrapped, so `Source: [[001-waitlist]]` and `Source: 001-waitlist`
    # both yield `feature_source: "001-waitlist"`.
    r"(?:Source|From feature|Where it came from)\s*[:=]?\s*\[?\[?([A-Za-z0-9_/-]+)\]?\]?",
    re.IGNORECASE,
)


def _slugify(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def _walk_headings(lines: List[str]):
    """Yield (level, heading, body_start, body_end) tuples in document order.

    body_start/end are line indices; body is everything between this heading
    and the next heading at the same or shallower level.

    Tracks fenced code-block state so that ``` ## inside example markdown
    blocks isn't treated as a real heading (otherwise patterns containing
    fenced examples with their own headings would be split incorrectly and
    example headings would leak into the `available` list).
    """
    headings = []
    in_fence = False
    fence_char = None  # '`' or '~' — only the SAME fence type closes the block
    for idx, line in enumerate(lines):
        # Toggle fence state on lines that start a code block. Match BOTH
        # backtick fences (```, ```text, ```python) AND tilde fences
        # (~~~, ~~~text, ~~~yaml). A markdown example with `~~~` was
        # leaking interior `##` lines into the heading walker.
        m_fence = re.match(r"^\s*(```+|~~~+)", line)
        if m_fence:
            opener = m_fence.group(1)[0]  # '`' or '~'
            if not in_fence:
                in_fence = True
                fence_char = opener
            elif opener == fence_char:
                # Only close on the same fence type
                in_fence = False
                fence_char = None
            continue
        if in_fence:
            continue
        m = re.match(r"^(#{2,3})\s+(.+?)\s*$", line)
        if m:
            headings.append((len(m.group(1)), m.group(2).strip(), idx))
    for i, (lvl, name, start) in enumerate(headings):
        end = len(lines)
        for nlvl, _, nstart in headings[i + 1 :]:
            if nlvl <= lvl:
                end = nstart
                break
        yield lvl, name, start, end


def get_pattern(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    slug = (args or {}).get("slug")
    if not slug:
        return {"error": "missing arg 'slug'"}
    target = _slugify(slug)

    pat_path = os.path.join(project_root, ".sdd", "patterns.md")
    if not os.path.isfile(pat_path):
        return {"error": f"patterns.md not found at {pat_path}"}
    try:
        with open(pat_path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except OSError as exc:
        return {"error": f"cannot read patterns.md: {exc}"}

    available = []
    match = None
    for lvl, name, start, end in _walk_headings(lines):
        # Only level-2 and level-3 headings are real patterns; level-2 is the
        # category, but if the user asks for it by slug we still return it.
        slug_form = _slugify(name)
        available.append({"slug": slug_form, "heading": name, "level": lvl})
        if slug_form == target and match is None:
            match = (lvl, name, start, end)

    if match is None:
        return {"error": "pattern not found", "available": available}

    lvl, name, start, end = match
    body_lines = lines[start + 1 : end]
    content = "\n".join(body_lines).strip()

    feature_source = None
    sm = _SOURCE_RE.search(content)
    if sm:
        feature_source = sm.group(1)

    return {
        "slug": _slugify(name),
        "heading": name,
        "level": lvl,
        "content": content,
        "feature_source": feature_source,
    }
