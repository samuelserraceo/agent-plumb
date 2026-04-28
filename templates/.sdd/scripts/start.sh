#!/usr/bin/env bash
# start.sh — body of the /start slash command.
#
# Scaffolds a new work item: creates the work-item folder with a
# numbered ID, generates an empty spec.md skeleton populated with the
# active playbook's action headings, updates INDEX.md to point at
# the new work item.
#
# Usage:
#   start.sh "<feature title>"          # uses default_playbook from config.md
#   start.sh --playbook=<slug> "<title>"  # explicit playbook (v0.9: only `feature` exists)
#
# Output:
#   - Creates .sdd/<work_item_folder>/<NNN>-<slug>/spec.md
#   - Updates .sdd/INDEX.md
#   - Echoes plain-English next-steps to stdout
#
# Errors (exit 1) on:
#   - .sdd not found (not an SDD project)
#   - .sdd/config.md missing or malformed
#   - --playbook=<slug> references a playbook that doesn't exist
#   - work-item ID computation fails (e.g., directory unreadable)
#   - empty title

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 1

usage() {
  cat >&2 <<'EOF'
[/start] usage:
    /start "<title for the new feature>"

Plain-English: what are you building? Tell me in a short phrase.
The framework will scaffold a new work item folder and walk you
through the questions to fill out.
EOF
  exit 1
}

# Parse args.
PLAYBOOK_OVERRIDE=""
EXTENDS=""
TITLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --playbook=*)
      PLAYBOOK_OVERRIDE="${1#--playbook=}"
      shift
      ;;
    --playbook)
      PLAYBOOK_OVERRIDE="$2"
      shift 2
      ;;
    --extends=*)
      EXTENDS="${1#--extends=}"
      shift
      ;;
    --extends)
      EXTENDS="$2"
      shift 2
      ;;
    *)
      # Everything else joins as the title (allows multi-word without quotes).
      if [ -z "$TITLE" ]; then
        TITLE="$1"
      else
        TITLE="$TITLE $1"
      fi
      shift
      ;;
  esac
done

[ -z "$TITLE" ] && usage

if [ ! -d ".sdd" ]; then
  echo "[/start] this is not an SDD project (no .sdd/ directory)." >&2
  echo "         Run framework setup first." >&2
  exit 1
fi

if [ ! -f ".sdd/config.md" ]; then
  echo "[/start] .sdd/config.md not found — can't determine which playbook to use." >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || {
  echo "[/start] python3 required but not on PATH" >&2
  exit 1
}

# UAT moat-bypass + Cut-11 safe install — wire `core.hooksPath` to
# .claude/hooks so combined `git add && git commit` patterns hit the
# moat via native git pre-commit (Phase B-1 fix). Three cases:
#
#   1. Already set to `.claude/hooks` → silent re-run.
#   2. Empty (default git, no prior hooks tool) → set silently with
#      a one-line "this is what changed" message. Honest UX, no
#      surprise.
#   3. Set to anything else (Husky, lefthook, custom) → HALT with a
#      plain-English explanation. Refuses to silently overwrite an
#      existing hooks setup. Round-2 customisation reviewer flagged
#      the silent override as a real footgun for adopters of SDD on
#      existing repos.
current_hookspath=$(git config --get core.hooksPath 2>/dev/null || echo "")
# CodeRabbit cycle 9/10/11: use `git rev-parse --is-inside-work-tree`
# instead of `[ -d ".git" ]` to detect a git repo. The directory check
# misses worktrees (where .git is a FILE, not a dir) — fairly common
# for users running SDD inside `git worktree add` checkouts. The
# rev-parse form handles both.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ "$current_hookspath" = ".claude/hooks" ]; then
    : # Already SDD's hooks; silent.
  elif [ -z "$current_hookspath" ]; then
    if git config core.hooksPath .claude/hooks 2>/dev/null; then
      echo "[/start] Setting up your safety checks (one-time, applies to this project only)."
    fi
  else
    cat >&2 <<EOF
[/start] Hook conflict — your project already uses git hooks.

  Current core.hooksPath: $current_hookspath
  SDD expects:            .claude/hooks

Your current setup (Husky, lefthook, or custom) would be silently
replaced if SDD set its own path. Refusing to do that without your
say-so. Pick one and re-run /start:

  - If you want SDD's safety checks for this project (recommended
    when you're using SDD to drive the workflow):
        git config core.hooksPath .claude/hooks

  - If you want to keep your existing hooks instead, don't run
    /start. SDD's safety checks won't fire — the agent can commit
    past sections you've approved without re-checking. You'd be
    using SDD's prose-only mode, which is the same as Phase A.

This message protects you from losing your existing hook setup
silently. SDD will not override core.hooksPath without your
explicit consent.
EOF
    exit 1
  fi
fi

# Read config + figure out which playbook to use.
# Validate playbook exists. Compute next NNN. Derive slug from title.
# Scaffold spec.md + update INDEX.md. All in one python3 block for safety.
TITLE_INPUT="$TITLE" PLAYBOOK_OVERRIDE="$PLAYBOOK_OVERRIDE" EXTENDS="$EXTENDS" PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import json, os, re, sys

proj = os.environ["PROJ"]
title = os.environ["TITLE_INPUT"].strip()
playbook_override = os.environ["PLAYBOOK_OVERRIDE"].strip()
extends_raw = os.environ.get("EXTENDS", "").strip()

# --- Read config.md frontmatter ---
config_path = os.path.join(proj, ".sdd", "config.md")
with open(config_path, encoding="utf-8") as f:
    config_text = f.read()
m = re.match(r"^---\n(.*?)\n---", config_text, re.DOTALL)
if not m:
    print("[/start] .sdd/config.md has no YAML frontmatter — malformed.", file=sys.stderr)
    sys.exit(1)
try:
    import yaml
    config_fm = yaml.safe_load(m.group(1))
except Exception as e:
    print(f"[/start] .sdd/config.md frontmatter parse error: {e}", file=sys.stderr)
    sys.exit(1)

playbooks_available = config_fm.get("playbooks_available", []) or []
default_playbook = config_fm.get("default_playbook", "")

# --- Resolve which playbook to use ---
if playbook_override:
    if playbook_override not in playbooks_available:
        print(f"[/start] '{playbook_override}' is not an available playbook in this project.", file=sys.stderr)
        if playbook_override in ("bug", "idea", "question", "project"):
            print(f"[/start] {playbook_override.title()} playbook is coming in Phase C. For now, use 'feature' "
                  "— it's the same process, just with extra steps you can leave blank.", file=sys.stderr)
        else:
            print(f"[/start] available playbooks: {', '.join(playbooks_available) or '(none)'}", file=sys.stderr)
        sys.exit(1)
    chosen = playbook_override
else:
    if not playbooks_available:
        print("[/start] no playbooks available in .sdd/config.md.", file=sys.stderr)
        sys.exit(1)
    if len(playbooks_available) == 1:
        chosen = playbooks_available[0]
    else:
        chosen = default_playbook or playbooks_available[0]

# --- Read playbook frontmatter (work_item_folder + work_item_id_pattern + stages) ---
playbook_path = os.path.join(proj, ".sdd", "playbooks", f"{chosen}.md")
if not os.path.isfile(playbook_path):
    print(f"[/start] playbook file not found: .sdd/playbooks/{chosen}.md", file=sys.stderr)
    sys.exit(1)
with open(playbook_path, encoding="utf-8") as f:
    playbook_text = f.read()
m = re.match(r"^---\n(.*?)\n---", playbook_text, re.DOTALL)
if not m:
    print(f"[/start] playbook has no YAML frontmatter: {playbook_path}", file=sys.stderr)
    sys.exit(1)
try:
    pb_fm = yaml.safe_load(m.group(1))
except Exception as e:
    print(f"[/start] playbook frontmatter parse error: {e}", file=sys.stderr)
    sys.exit(1)

work_item_folder = pb_fm.get("work_item_folder", "items/")
id_pattern = pb_fm.get("work_item_id_pattern", "{NNN}-{slug}")
stages = pb_fm.get("stages", []) or []
if not stages:
    print(f"[/start] playbook has no stages: {playbook_path}", file=sys.stderr)
    sys.exit(1)

# --- Slugify the title ---
def slugify(s):
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = s.strip("-")
    return s or "untitled"

slug = slugify(title)

# --- Compute next NNN ---
work_dir = os.path.join(proj, ".sdd", work_item_folder.rstrip("/"))
os.makedirs(work_dir, exist_ok=True)
existing_ids = []
for entry in os.listdir(work_dir):
    m = re.match(r"^(\d{3})-", entry)
    if m:
        existing_ids.append(int(m.group(1)))
next_id = (max(existing_ids) + 1) if existing_ids else 1
nnn = f"{next_id:03d}"

# --- Build the work item folder name from id_pattern ---
folder_name = id_pattern.replace("{NNN}", nnn).replace("{slug}", slug)
item_dir = os.path.join(work_dir, folder_name)
if os.path.exists(item_dir):
    print(f"[/start] work item already exists: {item_dir}", file=sys.stderr)
    sys.exit(1)
os.makedirs(item_dir)

# --- Resolve --extends if provided ---
# extends_raw can be: "001", "001-waitlist", "features/001-waitlist", a substring
# match against folder slug. Refuse if it doesn't resolve to exactly one folder.
extends_resolved = None
if extends_raw:
    candidates = []
    # Strip leading "features/" if present.
    needle = extends_raw
    if needle.startswith(work_item_folder.rstrip("/") + "/"):
        needle = needle[len(work_item_folder):]
    # Walk the work-item folder; match by exact name OR NNN prefix OR slug substring.
    for entry in sorted(os.listdir(work_dir)):
        if not os.path.isdir(os.path.join(work_dir, entry)):
            continue
        if entry == needle:
            candidates = [entry]; break
        if needle.isdigit() and entry.startswith(f"{int(needle):03d}-"):
            candidates.append(entry)
        elif needle in entry:
            candidates.append(entry)
    if len(candidates) == 0:
        print(f"[/start] --extends={extends_raw!r}: no matching work item under "
              f"{work_item_folder}. Run /status to see what's shipped.",
              file=sys.stderr)
        sys.exit(1)
    if len(candidates) > 1:
        print(f"[/start] --extends={extends_raw!r}: matches multiple work items:",
              file=sys.stderr)
        for c in candidates:
            print(f"    - {c}", file=sys.stderr)
        print(f"  Use the exact NNN or full folder name to disambiguate.",
              file=sys.stderr)
        sys.exit(1)
    extends_resolved = f"{work_item_folder.rstrip('/')}/{candidates[0]}"

# --- Generate spec.md skeleton ---
# Use the FIRST stage (typically SPEC) as the active phase.
# For each action, include `### action: <slug>` with one [ ] row per step
# declared in that action's frontmatter (F4 atomic-step granularity).
first_stage = stages[0]
first_stage_id = first_stage.get("id", "SPEC")
sub_slugs = first_stage.get("actions", []) or []

# Helper — read one action's `steps:` frontmatter list. Returns [] if the
# action file is missing or has no steps. Per-step `[ ]` rows are written
# in spec.md so /next can advance one step (= one commit) at a time.
def load_action_steps(action_slug):
    path = os.path.join(proj, ".sdd", "actions", f"{action_slug}.md")
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as f:
        text = f.read()
    fm = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not fm:
        return []
    try:
        meta = yaml.safe_load(fm.group(1)) or {}
    except Exception:
        return []
    return meta.get("steps", []) or []

# Spec.md frontmatter — only emitted when there's structured data to record
# (extends:). Keeps the no-extends case free of empty YAML noise.
frontmatter_lines = []
if extends_resolved:
    frontmatter_lines = [
        "---",
        f"extends:",
        f"  - {extends_resolved}",
        "---",
        "",
    ]

spec_lines = list(frontmatter_lines) + [
    f"# {title}",
    "",
    f"[PHASE: {first_stage_id}]",
    "",
    f"**Active blocker:** §1 (first action: {sub_slugs[0] if sub_slugs else 'n/a'})",
    "",
]
if extends_resolved:
    spec_lines.append(f"**Extends:** `{extends_resolved}` (read INDEX.md's Shipped block for the prior feature's distilled context — do NOT cold-read its spec.md)")
    spec_lines.append("")
spec_lines.append(f"## PHASE: {first_stage_id}")
spec_lines.append("")
for i, sa_slug in enumerate(sub_slugs, start=1):
    spec_lines.append(f"### action: {sa_slug}")
    spec_lines.append("")
    steps = load_action_steps(sa_slug)
    if steps:
        for step in steps:
            sid = (step.get("id") or "").strip()
            label = (step.get("prompt") or step.get("action") or "").strip()
            if not sid:
                continue
            if label:
                spec_lines.append(f"- [ ] {sid}: {label}")
            else:
                spec_lines.append(f"- [ ] {sid}")
    else:
        # No steps declared (legacy action file) — fall back to single
        # placeholder. Should not happen for v0.9 actions.
        spec_lines.append("[ ]  (waiting for /next to populate)")
    spec_lines.append("")

# Exit checks block
exit_checks = first_stage.get("exit_checks", []) or []
if exit_checks:
    spec_lines.append("### Exit checks")
    for chk in exit_checks:
        cid = chk.get("id", "C-?")
        cdesc = chk.get("check", "(no description)")
        spec_lines.append(f"- [ ] {cid}: {cdesc}")
    spec_lines.append("")

spec_md = os.path.join(item_dir, "spec.md")
with open(spec_md, "w", encoding="utf-8") as f:
    f.write("\n".join(spec_lines))

# --- Update INDEX.md ---
index_path = os.path.join(proj, ".sdd", "INDEX.md")
work_item_rel = f"{work_item_folder.rstrip('/')}/{folder_name}"

if os.path.isfile(index_path):
    with open(index_path, encoding="utf-8") as f:
        index_text = f.read()
else:
    index_text = ""

# Replace or insert the active block at the top.
header_lines = [
    f"**Active:** {work_item_rel}",
    f"**Playbook:** {chosen}",
    f"**Active blocker:** §1 (first action: {sub_slugs[0] if sub_slugs else 'n/a'})",
    "",
]

# Strip ANY **Active:**/**Playbook:**/**Active blocker:** lines from the
# entire body. UAT v0.10.1 finding: the original "from the top until first
# blank" logic broke when INDEX.md template starts with `# Project Index`
# heading — the first iteration set in_old_header=False and subsequent
# Active/Playbook lines slipped through, leaving a duplicate
# `**Active:** _(none)_` boilerplate even after start.sh inserted the
# canonical pointer. Now: scan whole body, strip every match. The
# canonical header_lines we're prepending is the only one that should
# remain.
new_lines = []
for line in index_text.split("\n"):
    if re.match(r"^\*\*(Active|Playbook|Active blocker):\*\*", line):
        continue
    new_lines.append(line)
# Collapse leading blank lines that the strip may have created.
while new_lines and new_lines[0].strip() == "":
    new_lines.pop(0)

# Ensure ## In flight and ## Shipped sections exist.
# v0.10.1: changed from "## Active" to "## In flight" to align with the
# INDEX.md template + enable multi-feature parallel work. Multiple features
# can sit in `## In flight` simultaneously; **Active:** at the top points
# to whichever one the user is working on RIGHT NOW.
body = "\n".join(new_lines).strip()
if "## In flight" not in body:
    body += "\n\n## In flight\n\n" + f"- {work_item_rel} — {title} (PHASE: {first_stage_id})\n"
else:
    # Append under ## In flight section. Three cases:
    #  1. The "_(none yet)_" placeholder is still in place (fresh project) → replace it
    #  2. Other in-flight items already exist → insert this one as new top item under the heading
    #  3. The section heading exists but has only the HTML comment + blank lines → insert under heading
    # CodeRabbit cycle 1 fix (PR #47): the earlier regex had a fragile match that
    # didn't account for the placeholder wrapped in italics or for the comment
    # being on the same line as the heading. Now: try replace first, fall back
    # to a heading-anchored insert that works regardless of section state.
    new_entry = f"- {work_item_rel} — {title} (PHASE: {first_stage_id})"
    # CodeRabbit cycle 2 (PR #47): scope the placeholder replacement to
    # the `## In flight` section only. Earlier `"_(none yet)_" in body`
    # would match the placeholder in any section if one ever migrated
    # there. Now: extract the section first, modify it, splice back.
    section_match = re.search(r"(?ms)^## In flight\b.*?(?=^## |\Z)", body)
    if section_match:
        sec_start, sec_end = section_match.span()
        in_flight_section = section_match.group(0)
        if "_(none yet)_" in in_flight_section:
            in_flight_section = in_flight_section.replace("_(none yet)_", new_entry, 1)
        else:
            in_flight_section = re.sub(
                r"(## In flight\b[^\n]*\n)((?:<!--[^>]*-->[^\n]*\n)?)",
                r"\1\2" + new_entry + "\n",
                in_flight_section,
                count=1,
            )
        body = body[:sec_start] + in_flight_section + body[sec_end:]
if "## Shipped" not in body:
    body += "\n## Shipped\n\n"

new_index = "\n".join(header_lines) + body.lstrip("\n") + ("\n" if not body.endswith("\n") else "")
with open(index_path, "w", encoding="utf-8") as f:
    f.write(new_index)

# --- Plain-English success message to stdout ---
print(f"[/start] scaffolded: {work_item_rel}")
print(f"   - spec.md created with {len(sub_slugs)} actions in stage '{first_stage_id}'")
print(f"   - INDEX.md updated (active = {work_item_rel}, playbook = {chosen})")
print()
print("Next: run /next to start the first action.")
print(f"      I'll ask you about §1 ({sub_slugs[0] if sub_slugs else 'n/a'}) first.")
PYEOF
