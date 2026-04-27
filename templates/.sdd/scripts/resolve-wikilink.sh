#!/usr/bin/env bash
# resolve-wikilink.sh — replace [[slug]] wikilinks in stdin with resolved
# markdown links, using .sdd/.cache/slug-map.json for the lookup.
#
# Usage:
#   cat my-prose.md | resolve-wikilink.sh [<project-dir>]
#   resolve-wikilink.sh < my-prose.md
#
# Behavior:
#   - For each `[[slug]]` in stdin, look up `slug` in slug-map.json
#     (built by `load-playbook.sh --validate`).
#   - Match: replace with `[slug](relative/path)` markdown link.
#   - No match: leave `[[slug]]` as-is + emit warning to stderr.
#   - Slug-map.json missing: pass through unchanged + warn (run
#     `load-playbook.sh --validate` first to build the cache).
#
# Notes:
#   - Multi-match is impossible at this layer because load-playbook
#     errors during slug-map construction (SCHEMA.md §10). If
#     slug-map.json exists, every entry is unambiguous.
#   - Wikilink syntax: `[[slug]]` exactly. Slug = `[a-z][a-z0-9-]*`.
#     Anything outside the brackets is preserved verbatim.
#   - Idempotent: if input already has resolved links AND raw [[slug]]s,
#     only the raw ones get re-resolved.
#
# Exit:
#   0 — input processed (resolved or passed through)
#   1 — input read error / project-dir missing

set -uo pipefail

PROJECT_DIR="${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "resolve-wikilink: project directory not found: $PROJECT_DIR" >&2
  exit 1
fi

# Capture stdin to a temp file BEFORE invoking python3 — `python3 <<EOF`
# uses stdin for the script source, so we can't also read stdin from inside.
input_file=$(mktemp)
trap 'rm -f "$input_file"' EXIT
cat > "$input_file"

PROJ="$PROJECT_DIR" INPUT_FILE="$input_file" python3 <<'PYEOF'
import json, os, re, sys

proj = os.environ["PROJ"]
input_file = os.environ["INPUT_FILE"]
slug_map_path = os.path.join(proj, ".sdd", ".cache", "slug-map.json")

slug_map = {}
if os.path.isfile(slug_map_path):
    try:
        with open(slug_map_path) as f:
            slug_map = json.load(f)
    except Exception as e:
        sys.stderr.write(
            f"resolve-wikilink: WARNING: slug-map.json malformed ({e}); "
            f"passing through unchanged\n"
        )
        slug_map = {}
else:
    sys.stderr.write(
        f"resolve-wikilink: WARNING: {slug_map_path} not found — run "
        f"load-playbook.sh --validate first to build the cache\n"
    )

with open(input_file) as f:
    text = f.read()

# Match [[slug]] where slug is lowercase + dashes only (closed enum
# per SCHEMA.md §2.6 + §6).
WIKILINK = re.compile(r"\[\[([a-z][a-z0-9-]*)\]\]")

def replace(match):
    slug = match.group(1)
    path = slug_map.get(slug)
    if path is None:
        sys.stderr.write(
            f"resolve-wikilink: WARNING: [[{slug}]] does not resolve "
            f"(not in slug-map.json — typo or stale cache?)\n"
        )
        return match.group(0)
    # Replace with a markdown link. Path is already project-relative.
    return f"[{slug}]({path})"

out = WIKILINK.sub(replace, text)
sys.stdout.write(out)
PYEOF
