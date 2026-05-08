#!/usr/bin/env bash
# promote-to-active.sh — body of the /promote-to-active slash command.
#
# Closes #169. Flips a QUEUED work item to actively-worked-on:
#   - spec.md PHASE line: QUEUED → playbook's first stage
#   - spec.md Active blocker line: queued-fallback → "§1 (first action: <slug>)"
#   - INDEX.md row: ## Backlog → ## In flight
#   - INDEX.md **Active:** → this work item
#
# Usage:
#   promote-to-active.sh "<id-or-slug>"
#
# Lenient match across .sdd/features/, .sdd/bugs/, .sdd/refactors/, etc:
#   exact NNN-slug | bare NNN | bare slug | unique substring
#
# Exit:
#   0 — promoted successfully
#   1 — error (no match, ambiguous match, not QUEUED, malformed playbook)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 1

usage() {
  cat >&2 <<'EOF'
[/promote-to-active] usage:
    /promote-to-active <work-item-id-or-slug>

Plain-English: which queued work item should become the active one?
Pass the NNN-slug, bare NNN, or a unique slug substring.

Examples:
    /promote-to-active 002-profile-setup
    /promote-to-active 002
    /promote-to-active profile-setup
EOF
  exit 1
}

ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage ;;
    *)
      if [ -z "$ARG" ]; then ARG="$1"; else ARG="$ARG $1"; fi
      shift
      ;;
  esac
done
[ -z "$ARG" ] && usage

if [ ! -d ".sdd" ]; then
  echo "[/promote-to-active] not an SDD project (no .sdd/ directory)." >&2
  exit 1
fi

ARG_INPUT="$ARG" PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import os, re, sys, glob

proj = os.environ["PROJ"]
arg = os.environ["ARG_INPUT"].strip()

# 1. Locate candidate work item folders.
# Walk every direct child of .sdd/<work-item-folder>/<NNN>-<slug>.
# work-item-folder names come from the playbook frontmatter; common ones:
# features/, bugs/, refactors/, projects/. Walk all of them.
candidates = []
sdd_root = os.path.join(proj, ".sdd")
for folder in os.listdir(sdd_root):
    full = os.path.join(sdd_root, folder)
    if not os.path.isdir(full):
        continue
    # Skip the framework's reserved subdirs.
    if folder in {"actions", "playbooks", "scripts", "skeletons", "extensions",
                  "setup", "topics", "archive", "ideas", ".cache"}:
        continue
    # Look for <NNN>-<slug>/ subfolders with a spec.md.
    for entry in os.listdir(full):
        cand_dir = os.path.join(full, entry)
        if not os.path.isdir(cand_dir):
            continue
        if not os.path.isfile(os.path.join(cand_dir, "spec.md")):
            continue
        # rel path from .sdd/, e.g. "features/002-profile-setup"
        rel = f"{folder}/{entry}"
        candidates.append((rel, cand_dir, entry))

if not candidates:
    print("[/promote-to-active] no work item folders found under .sdd/.", file=sys.stderr)
    print("                     Run /status to see project state.", file=sys.stderr)
    sys.exit(1)

# 2. Lenient match.
def matches(arg, rel, basename):
    # Exact path or basename
    if arg == rel or arg == basename:
        return True
    # Bare NNN (e.g. "002" matches "features/002-profile-setup")
    m = re.match(r"^(\d+)$", arg)
    if m and basename.startswith(arg + "-"):
        return True
    # Bare slug (e.g. "profile-setup" matches "002-profile-setup")
    if re.match(r"^[a-z][a-z0-9-]*$", arg):
        slug = re.sub(r"^\d+-", "", basename)
        if slug == arg or arg in basename:
            return True
    # Substring fallback
    if arg in basename:
        return True
    return False

matched = [c for c in candidates if matches(arg, c[0], c[2])]
if not matched:
    print(f"[/promote-to-active] no work item matched {arg!r}.", file=sys.stderr)
    print("                     Run /status to see what's open. Pass the", file=sys.stderr)
    print("                     exact NNN-slug, bare NNN, or a unique slug substring.", file=sys.stderr)
    sys.exit(1)
if len(matched) > 1:
    print(f"[/promote-to-active] {arg!r} matched multiple work items:", file=sys.stderr)
    for rel, _, _ in matched:
        print(f"    - {rel}", file=sys.stderr)
    print("                     Use the full NNN-slug to disambiguate.", file=sys.stderr)
    sys.exit(1)

rel, cand_dir, basename = matched[0]
spec_path = os.path.join(cand_dir, "spec.md")

# 3. Read spec.md, verify it's QUEUED.
with open(spec_path, encoding="utf-8") as f:
    spec_text = f.read()

phase_match = re.search(r"^\[PHASE:\s*([A-Z]+)\]", spec_text, re.MULTILINE)
if not phase_match:
    print(f"[/promote-to-active] spec.md at {rel} has no [PHASE: X] line.", file=sys.stderr)
    print("                     Spec may be malformed. Inspect manually.", file=sys.stderr)
    sys.exit(1)

current_phase = phase_match.group(1)
if current_phase != "QUEUED":
    print(f"[/promote-to-active] {rel} is in PHASE: {current_phase}, not QUEUED.", file=sys.stderr)
    print("                     /promote-to-active only flips QUEUED → first stage.", file=sys.stderr)
    if current_phase == "SHIPPED":
        print("                     This work item is already shipped. Run /status to see what's open.", file=sys.stderr)
    else:
        print(f"                     Run /next on it (it's already advancing through {current_phase}).", file=sys.stderr)
    sys.exit(1)

# 4. Read the playbook to find the first stage.
fm_match = re.match(r"^---\n(.*?)\n---\n", spec_text, re.DOTALL)
playbook_slug = None
if fm_match:
    fm = fm_match.group(1)
    pb_match = re.search(r"^playbook:\s*(\S+)", fm, re.MULTILINE)
    if pb_match:
        playbook_slug = pb_match.group(1).strip()

# Fall back to INDEX.md **Playbook:** line, then config.md default_playbook.
if not playbook_slug:
    index_path = os.path.join(proj, ".sdd", "INDEX.md")
    if os.path.isfile(index_path):
        with open(index_path, encoding="utf-8") as f:
            idx = f.read()
        pb_idx = re.search(r"^\*\*Playbook:\*\*\s*(\S+)", idx, re.MULTILINE)
        if pb_idx:
            playbook_slug = pb_idx.group(1).strip()
if not playbook_slug:
    config_path = os.path.join(proj, ".sdd", "config.md")
    if os.path.isfile(config_path):
        with open(config_path, encoding="utf-8") as f:
            cfg = f.read()
        dp = re.search(r"default_playbook:\s*(\S+)", cfg)
        if dp:
            playbook_slug = dp.group(1).strip()

if not playbook_slug:
    print("[/promote-to-active] couldn't determine playbook for this work item.", file=sys.stderr)
    print("                     Spec frontmatter, INDEX.md, and config.md all silent.", file=sys.stderr)
    sys.exit(1)

# Read playbook frontmatter for first stage id + actions.
pb_path = os.path.join(proj, ".sdd", "playbooks", f"{playbook_slug}.md")
if not os.path.isfile(pb_path):
    print(f"[/promote-to-active] playbook not found: {pb_path}", file=sys.stderr)
    sys.exit(1)
with open(pb_path, encoding="utf-8") as f:
    pb_text = f.read()
pb_fm_match = re.match(r"^---\n(.*?)\n---\n", pb_text, re.DOTALL)
if not pb_fm_match:
    print(f"[/promote-to-active] playbook {playbook_slug} has no frontmatter.", file=sys.stderr)
    sys.exit(1)

# Parse stages out of frontmatter (simple YAML-ish — no PyYAML to keep deps light).
# We just need the first stage's id + first action slug.
pb_fm = pb_fm_match.group(1)
stage_block = re.search(r"^stages:\s*\n((?:[ \t].*\n?)+)", pb_fm, re.MULTILINE)
first_stage_id = None
first_action_slug = None
if stage_block:
    block = stage_block.group(1)
    m_id = re.search(r"^\s*-\s+id:\s*(\S+)", block, re.MULTILINE)
    if m_id:
        first_stage_id = m_id.group(1).strip()
    # First action in the FIRST stage's actions: list.
    m_actions = re.search(r"^\s*-\s+id:[^\n]+\n\s+actions:\s*\n((?:\s+-\s+\S+\n?)+)", block, re.MULTILINE)
    if m_actions:
        first_act = re.search(r"^\s+-\s+(\S+)", m_actions.group(1), re.MULTILINE)
        if first_act:
            first_action_slug = first_act.group(1).strip()
if not first_stage_id:
    print(f"[/promote-to-active] couldn't parse first stage from playbook {playbook_slug}.", file=sys.stderr)
    sys.exit(1)

# 5. Write the updated spec.md.
new_spec = re.sub(
    r"^\[PHASE:\s*QUEUED\]",
    f"[PHASE: {first_stage_id}]",
    spec_text,
    count=1,
    flags=re.MULTILINE,
)
# Rewrite the Active blocker line if it has the queued-fallback shape.
new_blocker = (
    f"**Active blocker:** §1 (first action: {first_action_slug or 'n/a'})"
)
new_spec = re.sub(
    r"^\*\*Active blocker:\*\*[^\n]*",
    new_blocker,
    new_spec,
    count=1,
    flags=re.MULTILINE,
)

with open(spec_path, "w", encoding="utf-8") as f:
    f.write(new_spec)

# 6. Update INDEX.md: move row from ## Backlog to ## In flight, set **Active:** to this item.
index_path = os.path.join(proj, ".sdd", "INDEX.md")
if os.path.isfile(index_path):
    with open(index_path, encoding="utf-8") as f:
        idx = f.read()

    # Find the backlog row matching this work item.
    backlog_match = re.search(r"(?ms)^## Backlog\b.*?(?=^## |\Z)", idx)
    in_flight_match = re.search(r"(?ms)^## In flight\b.*?(?=^## |\Z)", idx)
    if backlog_match:
        bl_start, bl_end = backlog_match.span()
        bl = backlog_match.group(0)
        # Match a row referencing this work item.
        row_pat = re.compile(
            rf"^[ \t]*-\s+{re.escape(rel)}\b[^\n]*\n",
            re.MULTILINE,
        )
        row_match = row_pat.search(bl)
        if row_match:
            row = row_match.group(0)
            # Strip "(scaffolded, PHASE: QUEUED)" → "(PHASE: <first_stage_id>)" so
            # the row reads correctly under In flight.
            new_row = re.sub(
                r"\(scaffolded, PHASE:\s*QUEUED\)",
                f"(PHASE: {first_stage_id})",
                row,
                count=1,
            )
            # Remove from backlog.
            new_bl = bl[:row_match.start()] + bl[row_match.end():]
            # If In flight section exists, prepend the row under its heading.
            if in_flight_match:
                if_start, if_end = in_flight_match.span()
                ifl = in_flight_match.group(0)
                # If In flight comes AFTER backlog in the file, splice carefully.
                if if_start > bl_end:
                    # Update backlog first (earlier in file), then in flight.
                    new_ifl = re.sub(
                        r"(## In flight\b[^\n]*\n)((?:<!--[^>]*-->[^\n]*\n)?)",
                        r"\1\2" + new_row,
                        ifl,
                        count=1,
                    )
                    idx = idx[:bl_start] + new_bl + idx[bl_end:if_start] + new_ifl + idx[if_end:]
                else:
                    new_ifl = re.sub(
                        r"(## In flight\b[^\n]*\n)((?:<!--[^>]*-->[^\n]*\n)?)",
                        r"\1\2" + new_row,
                        ifl,
                        count=1,
                    )
                    idx = idx[:if_start] + new_ifl + idx[if_end:bl_start] + new_bl + idx[bl_end:]
            else:
                # No In flight section — create one with this row.
                idx = idx[:bl_start] + new_bl + "\n## In flight\n\n" + new_row + idx[bl_end:]

    # Update **Active:** line to point at this work item.
    if re.search(r"^\*\*Active:\*\*", idx, re.MULTILINE):
        idx = re.sub(
            r"^\*\*Active:\*\*[^\n]*",
            f"**Active:** {rel}",
            idx,
            count=1,
            flags=re.MULTILINE,
        )
    else:
        # Prepend at the top.
        idx = f"**Active:** {rel}\n\n" + idx

    # Update **Active blocker:** at top to point at first action.
    if re.search(r"^\*\*Active blocker:\*\*", idx, re.MULTILINE):
        idx = re.sub(
            r"^\*\*Active blocker:\*\*[^\n]*",
            f"**Active blocker:** §1 (first action: {first_action_slug or 'n/a'})",
            idx,
            count=1,
            flags=re.MULTILINE,
        )

    with open(index_path, "w", encoding="utf-8") as f:
        f.write(idx)

# 7. Tell the user.
print(f"[/promote-to-active] {rel} promoted: PHASE QUEUED → {first_stage_id}.")
print(f"                     INDEX.md updated: row moved to In flight, **Active:** set.")
print(f"")
print(f"Next: run /next to start §1 (first action: {first_action_slug or 'n/a'}).")
PYEOF
