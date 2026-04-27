#!/usr/bin/env bash
# hash-section.sh — extract a action section from spec.md, normalize per
# SCHEMA.md §9, output its lowercase-hex SHA-256.
#
# Usage:
#   hash-section.sh <spec-path> <subaction-md-path>
#
#   <spec-path>           — path to the spec.md being hashed
#   <subaction-md-path>   — path to the action's framework file
#                           (.sdd/actions/<slug>.md). Used to resolve
#                           BOTH the slug and the title for heading matching.
#
# Output:
#   On success: lowercase-hex SHA-256 to stdout, exit 0.
#   On error:   plain-English error to stderr, exit 1.
#
# Errors that block:
#   - spec.md not found / unreadable
#   - spec.md contains NUL bytes (Phase A invariant — refuse to parse)
#   - action file not found / unreadable
#   - section heading not found in spec.md (matched by either form)
#   - section heading matched multiple times in spec.md (ambiguous)
#
# Heading patterns matched (in order):
#   1. ^### action: <slug>$
#   2. ^### §\d+ <title>$
# where <slug> = filename without .md, <title> = `title:` field from the
# action's frontmatter.
#
# Section content is captured from the line AFTER the matched heading
# until the next line matching ^### (fence-aware — code-fenced ### lines
# are content, not boundaries). Normalized per SCHEMA.md §9 / §11.1:
#   - Convert CRLF/CR to LF
#   - Strip BOM if present at start of content
#   - Strip trailing whitespace from each line
#   - Strip blank-line edges (top + bottom)
#   - Hash UTF-8 bytes of normalized content with SHA-256
#
# This is the SAME normalization used by:
#   - load-playbook.sh (manifest hash check)
#   - pre-commit-stage-verified.sh (manifest pin + Theme 1.6 approved_sections)
# So all three callers agree on the hash for any given content.

set -uo pipefail

if [ $# -ne 2 ]; then
  echo "hash-section: usage: hash-section.sh <spec-path> <subaction-md-path>" >&2
  exit 1
fi

spec="$1"
subaction="$2"

[ -f "$spec" ] || { echo "hash-section: spec not found: $spec" >&2; exit 1; }
[ -f "$subaction" ] || { echo "hash-section: action not found: $subaction" >&2; exit 1; }

SPEC="$spec" SUBACTION="$subaction" python3 <<'PYEOF'
import hashlib, os, re, sys

spec_path = os.environ["SPEC"]
subaction_path = os.environ["SUBACTION"]

# Resolve slug from action filename (without .md).
slug = os.path.splitext(os.path.basename(subaction_path))[0]

# Read spec.md, NUL guard (Phase A invariant — refuse to parse).
try:
    with open(spec_path, "rb") as f:
        spec_bytes = f.read()
except OSError as e:
    print(f"hash-section: cannot read {spec_path}: {e}", file=sys.stderr)
    sys.exit(1)
if b"\x00" in spec_bytes:
    print(f"hash-section: {spec_path} contains NUL bytes — refusing to parse "
          f"(Phase A NUL guard)", file=sys.stderr)
    sys.exit(1)

# Read action frontmatter to get title.
try:
    with open(subaction_path, "rb") as f:
        sa_bytes = f.read()
except OSError as e:
    print(f"hash-section: cannot read {subaction_path}: {e}", file=sys.stderr)
    sys.exit(1)
sa_text = sa_bytes.decode("utf-8", errors="replace")
m = re.match(r"^---\n(.*?)\n---", sa_text, re.DOTALL)
title = None
if m:
    for line in m.group(1).split("\n"):
        tm = re.match(r'^\s*title\s*:\s*"?([^"]+?)"?\s*$', line)
        if tm:
            title = tm.group(1).strip()
            break

# Normalize spec to LF lines, strip BOM if present.
spec_text = spec_bytes.decode("utf-8", errors="replace")
if spec_text.startswith("﻿"):
    spec_text = spec_text[1:]
spec_text = spec_text.replace("\r\n", "\n").replace("\r", "\n")
lines = spec_text.split("\n")

# Build matchers for the heading. Order matters: try slug-form first
# (deterministic), then title-form (Phase A backward compat).
slug_pat = re.compile(r"^###\s+action:\s+" + re.escape(slug) + r"\s*$")
title_pat = None
if title:
    title_re = re.escape(title)
    title_pat = re.compile(r"^###\s+(?:§\d+\s+)?" + title_re + r"\s*$")

# Fence-aware section finder. Returns (heading_idx, end_idx_exclusive).
def find_section():
    fence_open = False
    matches = []
    for i, line in enumerate(lines):
        if re.match(r"^[ \t]*```", line):
            fence_open = not fence_open
            continue
        if fence_open:
            continue
        if slug_pat.match(line):
            matches.append(i)
            continue
        if title_pat and title_pat.match(line):
            matches.append(i)
            continue
    if len(matches) == 0:
        return None, None
    if len(matches) > 1:
        return "multi", matches
    heading_idx = matches[0]
    fence_open = False
    end_idx = len(lines)
    for j in range(heading_idx + 1, len(lines)):
        line = lines[j]
        if re.match(r"^[ \t]*```", line):
            fence_open = not fence_open
            continue
        if fence_open:
            continue
        if re.match(r"^###\s", line):
            end_idx = j
            break
    return heading_idx, end_idx

heading_idx, end_idx = find_section()
if heading_idx is None:
    tried = f"'### action: {slug}'"
    if title:
        tried += f" and '### §N {title}'"
    print(f"hash-section: section for slug {slug!r} not found in {spec_path} "
          f"(tried {tried})", file=sys.stderr)
    sys.exit(1)
if heading_idx == "multi":
    matches = end_idx
    print(f"hash-section: section for slug {slug!r} appears MULTIPLE times "
          f"in {spec_path} at lines {[m+1 for m in matches]} — ambiguous, "
          f"refusing to hash. Rename the duplicate or remove it.",
          file=sys.stderr)
    sys.exit(1)

# Capture content. Strip trailing whitespace per line, strip blank-line edges.
content_lines = lines[heading_idx + 1 : end_idx]
content_lines = [ln.rstrip() for ln in content_lines]
while content_lines and content_lines[0] == "":
    content_lines.pop(0)
while content_lines and content_lines[-1] == "":
    content_lines.pop()

# Hash. UTF-8 bytes of LF-joined normalized content.
normalized = "\n".join(content_lines)
print(hashlib.sha256(normalized.encode("utf-8")).hexdigest())
PYEOF
