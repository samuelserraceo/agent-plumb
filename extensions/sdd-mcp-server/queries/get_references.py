"""get_references — find every place a slug is referenced across `.sdd/`.

Args: `{"slug": "001-waitlist"}` (or any feature/action/playbook slug)

Searches `.sdd/` for the slug in three high-signal locations:

  1. YAML frontmatter `references:` lists
  2. `extends: <slug>` declarations (anywhere — frontmatter or prose)
  3. `Source: <slug>` / `From feature <slug>` lines (prose)
  4. Any other line that mentions the slug verbatim, as a fallback

For each match we return the file path (relative to project_root) and a
short context string showing the line we matched so the caller can
sanity-check the hit without re-opening the file.
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict, List


_SKIP_DIRS = {".cache", "archive", "ideas"}  # cold or noisy
_TARGET_EXTS = {".md", ".yaml", ".yml", ".json"}


def _walk_sdd(root: str):
    sdd_root = os.path.join(root, ".sdd")
    if not os.path.isdir(sdd_root):
        return
    for dirpath, dirnames, filenames in os.walk(sdd_root):
        # Prune skip-dirs in place so os.walk doesn't descend.
        dirnames[:] = [d for d in dirnames if d not in _SKIP_DIRS]
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            if ext not in _TARGET_EXTS:
                continue
            yield os.path.join(dirpath, fname)


def _classify(line: str, slug: str) -> str | None:
    """Return a category label if the line is a known reference shape; else None."""
    s = line.strip()
    if re.match(r"^references\s*:", s, re.IGNORECASE):
        # YAML list inline (`references: [a, b]`) or list-leader.
        if slug in s:
            return "frontmatter:references"
    # Frontmatter list item — accept both bare slug AND slug-with-context-suffix.
    # `- email-signup` AND `- email-signup (depends on contacts)` both qualify.
    if re.match(r"^-\s+" + re.escape(slug) + r"(?:\s|$)", s):
        return "frontmatter:references-item"
    if re.match(r"^extends\s*:", s, re.IGNORECASE) and slug in s:
        return "extends"
    # Source / cross-reference lines. Accept both colon/equals separators
    # AND bare-prefix shape ("From feature 001-waitlist") which is common
    # in SDD prose.
    if re.match(
        r"^(?:source|from feature|where it came from)\s*[:=]?\s+",
        s, re.IGNORECASE,
    ) and slug in s:
        return "source-line"
    return None


def get_references(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    slug = (args or {}).get("slug")
    if not slug:
        return {"error": "missing arg 'slug'"}
    slug = str(slug).strip()
    if not slug:
        return {"error": "missing arg 'slug'"}

    sdd_root = os.path.join(project_root, ".sdd")
    if not os.path.isdir(sdd_root):
        return {"error": f".sdd/ not found at {sdd_root}"}

    matches: List[Dict[str, Any]] = []
    seen = set()  # (relpath, line_no) — dedupe high-signal vs fallback hits

    for fpath in _walk_sdd(project_root):
        try:
            with open(fpath, encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        lines = text.split("\n")
        rel = os.path.relpath(fpath, project_root)
        for ln_no, line in enumerate(lines, start=1):
            cat = _classify(line, slug)
            if cat:
                key = (rel, ln_no)
                if key not in seen:
                    seen.add(key)
                    matches.append({
                        "path": rel,
                        "line": ln_no,
                        "context": line.strip(),
                        "kind": cat,
                    })
                continue
            # Fallback: any verbatim mention not already caught above.
            if slug in line:
                key = (rel, ln_no)
                if key not in seen:
                    seen.add(key)
                    matches.append({
                        "path": rel,
                        "line": ln_no,
                        "context": line.strip(),
                        "kind": "mention",
                    })
    return {"slug": slug, "referenced_in": matches}
