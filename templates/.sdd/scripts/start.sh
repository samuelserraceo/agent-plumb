#!/usr/bin/env bash
# start.sh — body of the /start slash command.
#
# Scaffolds a new work item: creates the work-item folder with a
# numbered ID, generates an empty spec.md skeleton populated with the
# active playbook's sub-action headings, updates INDEX.md to point at
# the new work item.
#
# Usage:
#   start.sh "<feature title>"          # uses default_playbook from config.md
#   start.sh --playbook=<slug> "<title>"  # explicit playbook (B-1: only `feature` exists)
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

# Theme 7+UAT — auto-install the safety checks (one-time, per project).
# Closes the UAT moat-bypass finding: without `core.hooksPath` pointing at
# .claude/hooks/, combined `git add && git commit` patterns bypass the
# moat. Setting it once wires every commit (agent or human, combined or
# split) through the safety check chain.
#
# Honest UX (Option 2): visible one-line message on first install, silent
# on subsequent /start runs. User sees what changed; doesn't have to run
# any setup command themselves.
current_hookspath=$(git config --get core.hooksPath 2>/dev/null || echo "")
if [ "$current_hookspath" != ".claude/hooks" ] && [ -d ".git" ]; then
  if git config core.hooksPath .claude/hooks 2>/dev/null; then
    echo "[/start] Setting up your safety checks (one-time, applies to this project only)."
  fi
fi

# Read config + figure out which playbook to use.
# Validate playbook exists. Compute next NNN. Derive slug from title.
# Scaffold spec.md + update INDEX.md. All in one python3 block for safety.
TITLE_INPUT="$TITLE" PLAYBOOK_OVERRIDE="$PLAYBOOK_OVERRIDE" PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import json, os, re, sys

proj = os.environ["PROJ"]
title = os.environ["TITLE_INPUT"].strip()
playbook_override = os.environ["PLAYBOOK_OVERRIDE"].strip()

# --- Read config.md frontmatter ---
config_path = os.path.join(proj, ".sdd", "config.md")
with open(config_path) as f:
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
with open(playbook_path) as f:
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

# --- Generate spec.md skeleton ---
# Use the FIRST stage (typically SPEC) as the active phase.
# For each sub-action, include `### sub-action: <slug>` with placeholder body.
first_stage = stages[0]
first_stage_id = first_stage.get("id", "SPEC")
sub_slugs = first_stage.get("subactions", []) or []

spec_lines = [
    f"# {title}",
    "",
    f"[PHASE: {first_stage_id}]",
    "",
    f"**Active blocker:** §1 (first sub-action: {sub_slugs[0] if sub_slugs else 'n/a'})",
    "",
    f"## PHASE: {first_stage_id}",
    "",
]
for i, sa_slug in enumerate(sub_slugs, start=1):
    spec_lines.append(f"### sub-action: {sa_slug}")
    spec_lines.append("")
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
with open(spec_md, "w") as f:
    f.write("\n".join(spec_lines))

# --- Update INDEX.md ---
index_path = os.path.join(proj, ".sdd", "INDEX.md")
work_item_rel = f"{work_item_folder.rstrip('/')}/{folder_name}"

if os.path.isfile(index_path):
    with open(index_path) as f:
        index_text = f.read()
else:
    index_text = ""

# Replace or insert the active block at the top.
header_lines = [
    f"**Active:** {work_item_rel}",
    f"**Playbook:** {chosen}",
    f"**Active blocker:** §1 (first sub-action: {sub_slugs[0] if sub_slugs else 'n/a'})",
    "",
]

# Strip any existing **Active:**/**Playbook:**/**Active blocker:** lines from the top.
new_lines = []
in_old_header = True
for line in index_text.split("\n"):
    if in_old_header and re.match(r"^\*\*(Active|Playbook|Active blocker):\*\*", line):
        continue
    if in_old_header and line.strip() == "":
        in_old_header = False
        continue
    in_old_header = False
    new_lines.append(line)

# Ensure ## Active and ## Shipped sections exist.
body = "\n".join(new_lines).strip()
if "## Active" not in body:
    body += "\n\n## Active\n\n" + f"- {work_item_rel} — {title} (PHASE: {first_stage_id})\n"
else:
    # Append under ## Active section
    body = re.sub(r"(## Active\n\n)", r"\1- " + f"{work_item_rel} — {title} (PHASE: {first_stage_id})\n", body, count=1)
if "## Shipped" not in body:
    body += "\n## Shipped\n\n"

new_index = "\n".join(header_lines) + body.lstrip("\n") + ("\n" if not body.endswith("\n") else "")
with open(index_path, "w") as f:
    f.write(new_index)

# --- Plain-English success message to stdout ---
print(f"[/start] scaffolded: {work_item_rel}")
print(f"   - spec.md created with {len(sub_slugs)} sub-actions in stage '{first_stage_id}'")
print(f"   - INDEX.md updated (active = {work_item_rel}, playbook = {chosen})")
print()
print("Next: run /next to start the first sub-action.")
print(f"      I'll ask you about §1 ({sub_slugs[0] if sub_slugs else 'n/a'}) first.")
PYEOF
