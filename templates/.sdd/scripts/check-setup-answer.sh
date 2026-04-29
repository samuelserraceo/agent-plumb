#!/usr/bin/env bash
# check-setup-answer.sh — verify the user has actually answered a setup-wizard
# question (instead of leaving it as "not decided yet" / "tbd" / blank).
#
# Used by actions that depend on a /sdd-setup answer being filled in. The
# canonical case (closes #68): push-pr can't actually push if `where-it-runs`
# was answered "Not deciding yet" — the agent doesn't know what hosting to
# target. Without this check, the agent silently invents a default; with it,
# the agent halts and points the user at /sdd-config <question-id>.
#
# Usage:
#   check-setup-answer.sh <question-id>
#
# Exit:
#   0 — answered (non-deferred, non-empty value found at the brick's records_at)
#   1 — deferred, missing, or unreadable; stderr explains and tells the user
#       to run /sdd-config <question-id>
#   2 — usage error or brick not found
#
# How it resolves the answer:
#   1. Look up the brick at .sdd/setup/<NNN>-<question-id>.md (any NNN prefix).
#   2. Parse its frontmatter for `records_in` and `records_at`.
#   3. Read the recorded answer:
#      - If records_at is a markdown heading (`## Foo`): grep the file for
#        the section, look for the first content line under it, return its
#        value (or treat as deferred if the line matches a deferred pattern).
#      - If records_at is a YAML dotted key (`parameters.foo.bar`): walk the
#        target file's YAML frontmatter; return the value at that path.
#   4. Compare the value to the deferred-marker patterns:
#        "not decided yet", "tbd", "_(deferred)_", "" (empty),
#        "_(empty — fill in as you ...)_" (the scaffold default)
#      Any match → exit 1.
#
# Deterministic; no agent reasoning. Phase-agnostic.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "check-setup-answer.sh: usage: check-setup-answer.sh <question-id>" >&2
  exit 2
fi

QUESTION_ID="$1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if [ ! -d "$PROJECT_DIR/.sdd" ]; then
  echo "check-setup-answer.sh: no .sdd/ at $PROJECT_DIR" >&2
  exit 2
fi

command -v python3 >/dev/null 2>&1 || {
  echo "check-setup-answer.sh: python3 required" >&2
  exit 2
}

QUESTION_ID="$QUESTION_ID" PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import os, re, sys, glob

question_id = os.environ["QUESTION_ID"]
proj        = os.environ["PROJ"]

# 1. Find the brick file.
setup_dir = os.path.join(proj, ".sdd", "setup")
matches = []
if os.path.isdir(setup_dir):
    for path in glob.glob(os.path.join(setup_dir, f"[0-9][0-9][0-9]-{question_id}.md")):
        matches.append(path)
    # Also accept setup/<NNN>-<id>.md with the slug after the dash.
    if not matches:
        for path in glob.glob(os.path.join(setup_dir, "[0-9][0-9][0-9]-*.md")):
            try:
                with open(path, encoding="utf-8") as f:
                    head = f.read(2048)
                # parse frontmatter id field
                m = re.search(r"^id:\s*(\S+)", head, re.MULTILINE)
                if m and m.group(1).strip() == question_id:
                    matches.append(path)
            except OSError:
                continue
if not matches:
    print(f"check-setup-answer.sh: no brick found for question id '{question_id}' in {setup_dir}",
          file=sys.stderr)
    sys.exit(2)
brick_path = matches[0]

# 2. Parse brick frontmatter for records_in + records_at.
with open(brick_path, encoding="utf-8") as f:
    brick_text = f.read()
fm_match = re.match(r"^---\n(.*?)\n---", brick_text, re.DOTALL)
if not fm_match:
    print(f"check-setup-answer.sh: no frontmatter in {brick_path}", file=sys.stderr)
    sys.exit(2)
fm_text = fm_match.group(1)
m_in = re.search(r"^records_in:\s*[\"']?([^\"'\n]+)", fm_text, re.MULTILINE)
m_at = re.search(r"^records_at:\s*[\"']?([^\"'\n]+)", fm_text, re.MULTILINE)
if not m_in or not m_at:
    print(f"check-setup-answer.sh: brick missing records_in/records_at: {brick_path}",
          file=sys.stderr)
    sys.exit(2)
records_in = m_in.group(1).strip().rstrip('"').rstrip("'")
records_at = m_at.group(1).strip().rstrip('"').rstrip("'")

target_path = os.path.join(proj, records_in)
if not os.path.isfile(target_path):
    print(f"check-setup-answer.sh: target {records_in} not found at {target_path}",
          file=sys.stderr)
    print(f"check-setup-answer.sh: run /sdd-config {question_id} to fill it in.",
          file=sys.stderr)
    sys.exit(1)

# 3. Read the recorded answer.
DEFERRED_PATTERNS = [
    re.compile(r"^\s*$"),
    re.compile(r"(?i)not decided yet"),
    re.compile(r"(?i)\btbd\b"),
    re.compile(r"^\s*_+\(deferred\)_+\s*$", re.IGNORECASE),
    re.compile(r"^\s*_+\(empty[^)]*\)_+\s*$", re.IGNORECASE),
    re.compile(r"^\s*<\s*[^>]+>\s*$"),  # placeholder like <choice>
]

def is_deferred(value):
    if value is None:
        return True
    for pat in DEFERRED_PATTERNS:
        if pat.search(str(value)):
            return True
    return False

answer = None

if records_at.startswith("## "):
    # Markdown heading. Find the section and read the first non-blank,
    # non-comment, non-list-bullet content line under it.
    with open(target_path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    in_section = False
    for line in lines:
        if line.strip() == records_at:
            in_section = True
            continue
        if in_section:
            stripped = line.strip()
            # Stop if we hit the next ## heading.
            if stripped.startswith("## "):
                break
            # Skip blanks, HTML comments, code-fence delimiters.
            if not stripped:
                continue
            if stripped.startswith("<!--") or stripped.startswith("```"):
                continue
            # The first content line is the answer (could be a bullet, a
            # paragraph, or a placeholder). Trim leading bullet markers.
            answer = re.sub(r"^[-*+]\s*", "", stripped)
            break
elif re.match(r"^[a-z][a-z0-9_]*", records_at):
    # YAML dotted key — walk the frontmatter.
    try:
        import yaml
    except ImportError:
        print("check-setup-answer.sh: PyYAML required for YAML-key resolution",
              file=sys.stderr)
        sys.exit(2)
    with open(target_path, encoding="utf-8") as f:
        text = f.read()
    fm2 = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not fm2:
        print(f"check-setup-answer.sh: no frontmatter in {target_path} for YAML key {records_at}",
              file=sys.stderr)
        sys.exit(1)
    try:
        data = yaml.safe_load(fm2.group(1))
    except Exception as exc:
        print(f"check-setup-answer.sh: YAML parse error in {target_path}: {exc}",
              file=sys.stderr)
        sys.exit(2)
    cur = data
    for part in records_at.split("."):
        if not isinstance(cur, dict) or part not in cur:
            answer = None
            break
        cur = cur[part]
    else:
        answer = cur
else:
    print(f"check-setup-answer.sh: unrecognised records_at form: {records_at}",
          file=sys.stderr)
    sys.exit(2)

# 4. Compare to deferred patterns.
if is_deferred(answer):
    print(f"check-setup-answer.sh: setup question '{question_id}' is unanswered or deferred.",
          file=sys.stderr)
    print(f"check-setup-answer.sh: target was {records_in} → {records_at}",
          file=sys.stderr)
    if answer is not None:
        print(f"check-setup-answer.sh: current value: '{answer}'", file=sys.stderr)
    print(f"check-setup-answer.sh: run `/sdd-config {question_id}` to answer it now.",
          file=sys.stderr)
    sys.exit(1)

# 5. Answered. Print the value to stdout for caller convenience.
print(answer)
sys.exit(0)
PYEOF
