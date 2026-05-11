#!/usr/bin/env bash
# promote-legacy-queued.sh — one-shot migrator for pre-v1.5.2 PHASE state drift.
#
# v1.5.2 introduced [PHASE: QUEUED] (#169) as a first-class pre-active state.
# Projects scaffolded BEFORE v1.5.2 have backlog features stored as
# [PHASE: SPEC] in their spec.md files even though their INDEX.md rows
# describe them as queued/backlog. `/next` would silently advance them.
#
# This script walks .sdd/features/, .sdd/bugs/, .sdd/refactors/, and for
# each work-item folder:
#
#   1. Skips if .shipped marker exists (cold feature).
#   2. Reads the first [PHASE: X] line in spec.md.
#   3. Reads the matching INDEX.md row.
#   4. If INDEX row matches queued|Backlog|backlog AND spec.md PHASE is
#      not already QUEUED:
#        - flip spec.md to [PHASE: QUEUED]
#        - canonicalise INDEX row by appending "(scaffolded, PHASE: QUEUED)"
#   5. Stages the touched files via `git add` but does NOT commit.
#   6. Prints a 5-line plain-English summary.
#
# Usage: bash .sdd/scripts/promote-legacy-queued.sh
#        (run from project root; honours $CLAUDE_PROJECT_DIR if set)
#
# Idempotent: re-running on an already-migrated project reports 0 migrated.
# Non-destructive: no auto-commit; user inspects via `git diff --cached`
# before committing the migration.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || { echo "[promote-legacy-queued] cannot cd to $PROJECT_DIR" >&2; exit 1; }

[ -d ".sdd" ] || { echo "[promote-legacy-queued] no .sdd/ directory — not an SDD project" >&2; exit 1; }
[ -f ".sdd/INDEX.md" ] || { echo "[promote-legacy-queued] .sdd/INDEX.md not found" >&2; exit 1; }

python3 <<'PYEOF'
import os, re, subprocess, sys

WORK_FOLDERS = ['features', 'bugs', 'refactors']
SDD_DIR = '.sdd'
INDEX_PATH = '.sdd/INDEX.md'

with open(INDEX_PATH, 'r', encoding='utf-8') as f:
    index_text = f.read()
index_lines = index_text.split('\n')

PHASE_RE = re.compile(r'^\[PHASE:\s*(\w+)\s*\]')
QUEUED_PATTERN = re.compile(r'queued|backlog', re.IGNORECASE)
CANONICAL = '(scaffolded, PHASE: QUEUED)'

inspected = 0
migrated = []
unchanged_shipped = []
unchanged_other = []
warned_partial = []
index_updates = []
touched_files = set()

print("[promote-legacy-queued] scanning .sdd/features/ + .sdd/bugs/ + .sdd/refactors/ ...")

for wf in WORK_FOLDERS:
    folder = os.path.join(SDD_DIR, wf)
    if not os.path.isdir(folder):
        continue
    for item in sorted(os.listdir(folder)):
        item_dir = os.path.join(folder, item)
        if not os.path.isdir(item_dir):
            continue
        spec_path = os.path.join(item_dir, 'spec.md')
        if not os.path.isfile(spec_path):
            continue
        inspected += 1

        # Skip if .shipped marker exists (cold-feature rule).
        if os.path.isfile(os.path.join(item_dir, '.shipped')):
            unchanged_shipped.append(item)
            continue

        # Read PHASE from spec.md.
        with open(spec_path, 'r', encoding='utf-8') as f:
            spec_text = f.read()
        spec_lines = spec_text.split('\n')
        current_phase = None
        phase_line_idx = None
        for i, line in enumerate(spec_lines):
            m = PHASE_RE.match(line)
            if m:
                current_phase = m.group(1)
                phase_line_idx = i
                break

        # Find matching INDEX row (substring match on folder path).
        folder_path_token = f"{wf}/{item}"
        index_row_idx = None
        for i, ln in enumerate(index_lines):
            if folder_path_token in ln:
                index_row_idx = i
                break

        if index_row_idx is None:
            unchanged_other.append(item)
            continue

        row_text = index_lines[index_row_idx]
        is_canonical = CANONICAL in row_text
        looks_queued = bool(QUEUED_PATTERN.search(row_text)) or is_canonical

        if not looks_queued:
            unchanged_other.append(item)
            continue

        # Spec already QUEUED — handle two sub-cases.
        if current_phase == 'QUEUED':
            if is_canonical:
                unchanged_other.append(item)
            else:
                # Just canonicalise the INDEX row.
                index_lines[index_row_idx] = row_text.rstrip() + ' ' + CANONICAL
                index_updates.append(item)
                touched_files.add(INDEX_PATH)
            continue

        # Partial state — INDEX says queued, spec says BUILD/SHIP etc.
        if current_phase != 'SPEC':
            warned_partial.append((item, current_phase))
            continue

        # Migrate: flip spec.md + canonicalise INDEX row.
        spec_lines[phase_line_idx] = '[PHASE: QUEUED]'
        with open(spec_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(spec_lines))
        migrated.append(item)
        touched_files.add(spec_path)

        if not is_canonical:
            index_lines[index_row_idx] = row_text.rstrip() + ' ' + CANONICAL
            index_updates.append(item)
            touched_files.add(INDEX_PATH)

# Write INDEX.md once if anything changed.
if INDEX_PATH in touched_files:
    with open(INDEX_PATH, 'w', encoding='utf-8') as f:
        f.write('\n'.join(index_lines))

# Stage all touched files via `git add` (non-destructive — does NOT commit).
if touched_files:
    subprocess.run(['git', 'add'] + sorted(touched_files), check=False)

# 5-line plain-English summary (counts at top, total-style).
print(f"[promote-legacy-queued] inspected: {inspected} work items")
mig_detail = ""
if migrated:
    head = ', '.join(migrated[:5])
    if len(migrated) > 5:
        head += ', ...'
    mig_detail = f" ({head} spec.md PHASE flipped to QUEUED)"
print(f"[promote-legacy-queued] migrated:  {len(migrated)} items{mig_detail}")
print(f"[promote-legacy-queued] INDEX.md:  {len(index_updates)} rows updated to canonical (scaffolded, PHASE: QUEUED)")

unchanged_total = len(unchanged_shipped) + len(unchanged_other)
parts = []
if unchanged_shipped:
    parts.append(f"{len(unchanged_shipped)} already SHIPPED")
if unchanged_other:
    parts.append(f"{len(unchanged_other)} not legacy-queued")
unchanged_desc = f" ({'; '.join(parts)})" if parts else ""
print(f"[promote-legacy-queued] unchanged: {unchanged_total} items{unchanged_desc}")

for item, phase in warned_partial:
    print(f"[promote-legacy-queued] WARNING: {item} has spec.md PHASE={phase} but INDEX says queued — left alone for manual review", file=sys.stderr)

tail_msg = " Commit the staged changes when you're ready." if (migrated or index_updates) else " No legacy-queued items found."
print(f"[promote-legacy-queued] done.{tail_msg}")
PYEOF
