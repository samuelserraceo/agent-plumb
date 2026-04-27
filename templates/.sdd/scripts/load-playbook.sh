#!/usr/bin/env bash
# load-playbook.sh — v0.8 schema loader and validator.
#
# Reads .sdd/ contents, validates against SCHEMA.md, and verifies hash-pinned
# files against .sdd/.cache/manifest.json. Builds an in-memory slug-map for
# duplicate detection during validation. (Persistent slug-map.json caching
# is a Phase B-1 Theme 7 deliverable — wikilink resolution needs it then.)
#
# Inherits Phase A bash patterns (NUL guard, set -uo pipefail, deterministic
# JSON output via python3, plain-English error messages to stderr).
#
# Usage:
#   load-playbook.sh --validate <project-dir>
#       Scan and validate every .sdd/ file. Exit 0 if all OK, exit 1 on
#       any schema error. Errors go to stderr in plain English per SCHEMA.md.
#
#   load-playbook.sh --check-hashes <project-dir>
#       Compare actual file SHAs against .sdd/.cache/manifest.json claims.
#       Mismatches emit a warning to stderr; trust is downgraded. Exit 0
#       unless the manifest itself is missing/malformed (exit 1).
#
# Exit codes:
#   0  success (no errors; warnings allowed for --check-hashes)
#   1  schema error, missing input, or malformed manifest
#   2  internal error (python3 unavailable, etc.)

set -uo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: load-playbook.sh <command> <project-dir>
Commands:
  --validate          scan + validate all .sdd/ files (errors to stderr, exit 1 on fail)
  --check-hashes      compare actual file SHAs against .sdd/.cache/manifest.json
EOF
  exit 1
}

# Empty-cmd safe default — Phase A pattern (catastrophic-#4):
# script invoked with no args on accident must not silently process ".".
[ $# -lt 2 ] && usage

cmd="$1"
proj="$2"

if [ ! -d "$proj" ]; then
  echo "load-playbook: project directory not found: $proj" >&2
  exit 1
fi
if [ ! -d "$proj/.sdd" ]; then
  echo "load-playbook: $proj/.sdd not found (is this an SDD project?)" >&2
  exit 1
fi

# Verify python3 available — bash can't parse YAML reliably (Codex finding #4)
command -v python3 >/dev/null 2>&1 || {
  echo "load-playbook: python3 required but not on PATH" >&2
  exit 2
}

case "$cmd" in
  --validate|--check-hashes)
    ;;
  *)
    usage
    ;;
esac

# Run the python3 backend with cmd + project dir as args.
# Heredoc keeps everything in one file (no separate .py script to ship).
python3 - "$cmd" "$proj" <<'PYEOF'
import json
import os
import re
import sys
import hashlib

CMD = sys.argv[1]
PROJ = sys.argv[2]
SDD = os.path.join(PROJ, ".sdd")

# Closed enums per SCHEMA.md §6
VALID_TAGS = {"USER-LED", "AGENT-LED", "BUILD-TASK", "BUILD-SPIKE", "TRANSITION"}
VALID_BUNDLING = {"bundle_all_fields_in_one_turn", "one_per_turn", "n_a"}
VALID_TRUST = {"framework", "project"}
VALID_STATUS = {"on", "off"}

errors = []
warnings = []

def err(msg):
    errors.append(msg)

def warn(msg):
    warnings.append(msg)

# ---------------------------------------------------------------------------
# NUL byte guard (Phase A invariant — handoff Section 16)
# ---------------------------------------------------------------------------
def read_text(path):
    """Read file, reject NUL bytes (Phase A invariant)."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        err(f"cannot read {path}: {e}")
        return None
    if b"\x00" in data:
        err(f"{path} contains NUL bytes — refusing to parse (Phase A NUL guard)")
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as e:
        err(f"{path} is not valid UTF-8: {e}")
        return None

# ---------------------------------------------------------------------------
# Frontmatter extraction + duplicate-key-aware YAML parse
# ---------------------------------------------------------------------------
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)

def find_top_level_duplicates(yaml_text):
    """Detect duplicate top-level YAML keys. SCHEMA.md §1.5/§2.6 last row."""
    keys_seen = []
    for line in yaml_text.split("\n"):
        # Top-level keys start at column 0, followed by colon
        m = re.match(r"^([a-zA-Z_][a-zA-Z0-9_-]*)\s*:", line)
        if m:
            keys_seen.append(m.group(1))
    dupes = []
    seen = set()
    for k in keys_seen:
        if k in seen and k not in dupes:
            dupes.append(k)
        seen.add(k)
    return dupes

def parse_frontmatter(path, text):
    """Return parsed YAML dict, or None on failure (errors emitted)."""
    m = FRONTMATTER_RE.match(text)
    if not m:
        err(f"{path} has no YAML frontmatter (must start with '---' line)")
        return None
    yaml_text = m.group(1)

    # Duplicate-key check FIRST (before YAML parser silently picks last value)
    dupes = find_top_level_duplicates(yaml_text)
    if dupes:
        err(f"{path} has duplicate YAML key(s): {', '.join(dupes)} — "
            f"YAML duplicates are silent corruption; fix and retry "
            f"(SCHEMA.md §1.5/§2.6 / Codex finding #4)")
        return None

    # Try PyYAML first; fall back to bash-style key:value parser if PyYAML missing
    try:
        import yaml
        try:
            data = yaml.safe_load(yaml_text)
        except yaml.YAMLError as e:
            err(f"{path} has malformed YAML frontmatter: {e}")
            return None
    except ImportError:
        data = simple_yaml_parse(yaml_text, path)

    if not isinstance(data, dict):
        err(f"{path} frontmatter is not a mapping")
        return None
    return data

def simple_yaml_parse(text, path):
    """Minimal YAML-ish parser fallback when PyYAML isn't installed.
    Handles top-level scalars and inline lists/dicts in flow style.
    Sufficient for the limited shapes SCHEMA.md uses."""
    out = {}
    for line in text.split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^([a-zA-Z_][a-zA-Z0-9_-]*)\s*:\s*(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            out[key] = [s.strip().strip('"\'') for s in inner.split(",")] if inner else []
        elif val.startswith("{") and val.endswith("}"):
            out[key] = {}  # nested flow dict; not parsed in fallback
        elif val == "":
            out[key] = None
        else:
            out[key] = val.strip().strip('"\'')
    return out

# ---------------------------------------------------------------------------
# Per-file validators
# ---------------------------------------------------------------------------
def validate_subaction(path, fm):
    """Validate sub-action frontmatter per SCHEMA.md §2."""
    expected_slug = os.path.splitext(os.path.basename(path))[0]
    rel = os.path.relpath(path, PROJ)

    # Required: type
    if fm.get("type") != "subaction":
        err(f"{rel} has type {fm.get('type')!r} — expected 'subaction' "
            f"(SCHEMA.md §2.1)")

    # Required: slug equals filename
    declared_slug = fm.get("slug")
    if declared_slug != expected_slug:
        err(f"{rel} declares slug={declared_slug!r} but filename suggests "
            f"slug={expected_slug!r} — slug must equal filename without .md "
            f"(SCHEMA.md §1.5/§2.6)")

    # Required: tag in closed enum
    tag = fm.get("tag")
    if tag is None:
        err(f"{rel} is missing required field 'tag' (SCHEMA.md §2.2)")
    elif tag not in VALID_TAGS:
        err(f"{rel} has unknown tag {tag!r} — allowed: "
            f"{', '.join(sorted(VALID_TAGS))} (SCHEMA.md §6)")

    # Required: title
    if not fm.get("title"):
        err(f"{rel} is missing required field 'title' (SCHEMA.md §2.2)")

    # Optional but enum-checked: bundling, trust
    bundling = fm.get("bundling", "n_a")
    if bundling not in VALID_BUNDLING:
        err(f"{rel} has unknown bundling {bundling!r} — allowed: "
            f"{', '.join(sorted(VALID_BUNDLING))} (SCHEMA.md §6)")

    trust = fm.get("trust", "framework")
    if trust not in VALID_TRUST:
        err(f"{rel} has unknown trust value {trust!r} — allowed: "
            f"{', '.join(sorted(VALID_TRUST))} (SCHEMA.md §6)")

def validate_playbook(path, fm, available_subactions=None):
    """Validate playbook frontmatter per SCHEMA.md §1.

    `available_subactions` (optional set of slugs): when provided, every
    subactions[] reference in the playbook must resolve. SCHEMA.md §1.5
    rule. Caller passes the set built from scanning .sdd/subactions/.
    """
    expected_slug = os.path.splitext(os.path.basename(path))[0]
    rel = os.path.relpath(path, PROJ)

    if fm.get("type") != "playbook":
        err(f"{rel} has type {fm.get('type')!r} — expected 'playbook' (SCHEMA.md §1.1)")

    if fm.get("slug") != expected_slug:
        err(f"{rel} declares slug={fm.get('slug')!r} but filename suggests "
            f"slug={expected_slug!r} (SCHEMA.md §1.5)")

    for required in ("title", "when_to_use", "work_item_folder",
                     "work_item_id_pattern", "stages"):
        if required not in fm or fm[required] in (None, "", []):
            err(f"{rel} is missing required field {required!r} (SCHEMA.md §1.2)")

    pattern = fm.get("work_item_id_pattern", "")
    if "{NNN}" not in pattern or "{slug}" not in pattern:
        err(f"{rel} work_item_id_pattern {pattern!r} missing required "
            f"tokens {{NNN}} and/or {{slug}} (SCHEMA.md §1.5)")

    stages = fm.get("stages") or []
    seen_check_ids = set()
    for stage in stages if isinstance(stages, list) else []:
        sid = stage.get("id", "")
        if not re.match(r"^[A-Z]+$", sid) or len(sid) > 16:
            err(f"{rel} stage id {sid!r} — must be UPPERCASE letters only, "
                f"max 16 chars (SCHEMA.md §6)")
        # Sub-action resolution check — SCHEMA.md §1.5
        if available_subactions is not None:
            for slug in stage.get("subactions", []) or []:
                if slug not in available_subactions:
                    err(f"{rel} stage {sid!r} references sub-action "
                        f"{slug!r} but no .sdd/subactions/{slug}.md exists "
                        f"(SCHEMA.md §1.5)")
        for chk in stage.get("exit_checks", []) or []:
            cid = chk.get("id", "")
            if cid in seen_check_ids:
                err(f"{rel} duplicate exit_check id {cid!r} (SCHEMA.md §1.5)")
            seen_check_ids.add(cid)

def validate_config(path, fm):
    """Validate .sdd/config.md per SCHEMA.md §4."""
    rel = os.path.relpath(path, PROJ)
    if fm.get("type") != "config":
        err(f"{rel} has type {fm.get('type')!r} — expected 'config' (SCHEMA.md §4)")
    for required in ("sdd_version", "playbooks_available", "default_playbook", "extensions"):
        if required not in fm:
            err(f"{rel} is missing required field {required!r} (SCHEMA.md §4.1)")

# ---------------------------------------------------------------------------
# Slug-map builder (multi-match detection — SCHEMA.md §10)
# ---------------------------------------------------------------------------
def build_slug_map(file_records):
    """Detect duplicate slugs across all files. Each duplicate is an error."""
    by_slug = {}
    for rec in file_records:
        slug = rec.get("slug")
        if slug is None:
            continue
        by_slug.setdefault(slug, []).append(rec["path"])
    for slug, paths in sorted(by_slug.items()):
        if len(paths) > 1:
            rels = [os.path.relpath(p, PROJ) for p in paths]
            err(f"duplicate slug {slug!r} — declared by multiple files: "
                f"{', '.join(rels)}. Slugs must be unique across .sdd/ "
                f"so [[{slug}]] wikilinks resolve unambiguously (SCHEMA.md §10)")
    return {slug: paths[0] for slug, paths in by_slug.items() if len(paths) == 1}

# ---------------------------------------------------------------------------
# Hash normalization (SCHEMA.md §9, §11.1)
# ---------------------------------------------------------------------------
def normalized_sha256(text):
    """LF line endings, strip trailing whitespace per line, strip blank-line edges."""
    if text is None:
        return None
    lines = [ln.rstrip() for ln in text.replace("\r\n", "\n").replace("\r", "\n").split("\n")]
    while lines and lines[0] == "":
        lines.pop(0)
    while lines and lines[-1] == "":
        lines.pop()
    normalized = "\n".join(lines).encode("utf-8")
    return hashlib.sha256(normalized).hexdigest()

# ---------------------------------------------------------------------------
# Scan + dispatch
# ---------------------------------------------------------------------------
def scan_files():
    """Walk .sdd/ for all known file types. Returns list of records."""
    records = []

    def add(path, file_type):
        text = read_text(path)
        if text is None:
            return
        fm = parse_frontmatter(path, text)
        if fm is None:
            return
        records.append({
            "path": path,
            "type": file_type,
            "slug": fm.get("slug") if file_type != "config" else None,
            "fm": fm,
            "text": text,
        })

    # Playbooks
    pdir = os.path.join(SDD, "playbooks")
    if os.path.isdir(pdir):
        for name in sorted(os.listdir(pdir)):
            if name.endswith(".md"):
                add(os.path.join(pdir, name), "playbook")

    # Sub-actions
    sdir = os.path.join(SDD, "subactions")
    if os.path.isdir(sdir):
        for name in sorted(os.listdir(sdir)):
            if name.endswith(".md"):
                add(os.path.join(sdir, name), "subaction")

    # Extensions
    edir = os.path.join(SDD, "extensions")
    if os.path.isdir(edir):
        for name in sorted(os.listdir(edir)):
            if name.endswith(".md"):
                add(os.path.join(edir, name), "extension")

    # Config (single file)
    cfg = os.path.join(SDD, "config.md")
    if os.path.isfile(cfg):
        add(cfg, "config")

    return records

def cmd_validate():
    records = scan_files()
    # Pre-collect available sub-action slugs so playbook validation can
    # check that every subactions[] reference resolves (SCHEMA.md §1.5).
    available_subactions = {
        r["slug"] for r in records
        if r["type"] == "subaction" and r["slug"]
    }
    for r in records:
        if r["type"] == "subaction":
            validate_subaction(r["path"], r["fm"])
        elif r["type"] == "playbook":
            validate_playbook(r["path"], r["fm"], available_subactions)
        elif r["type"] == "config":
            validate_config(r["path"], r["fm"])
    build_slug_map(records)

def cmd_check_hashes():
    manifest_path = os.path.join(SDD, ".cache", "manifest.json")
    if not os.path.isfile(manifest_path):
        err(f"{os.path.relpath(manifest_path, PROJ)} not found — "
            f"run --validate first or generate manifest (Theme 1.5)")
        return
    try:
        with open(manifest_path) as f:
            manifest = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        err(f"manifest.json malformed: {e}")
        return

    for section in ("playbooks", "subactions", "extensions", "scripts"):
        for slug, entry in (manifest.get(section) or {}).items():
            rel = entry.get("path", "")
            expected = entry.get("expected_sha256", "")
            full = os.path.join(PROJ, rel)
            if not os.path.isfile(full):
                warn(f"manifest references {rel} but file missing — "
                     f"trust downgraded to project")
                continue
            text = read_text(full)
            actual = normalized_sha256(text)
            if actual != expected:
                warn(f"{rel} hash mismatch — manifest says {expected[:12]}..., "
                     f"actual {actual[:12]}... → file is tampered or "
                     f"customized; trust downgraded to project (SCHEMA.md §11.2)")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if CMD == "--validate":
    cmd_validate()
elif CMD == "--check-hashes":
    cmd_check_hashes()
else:
    err(f"unknown command: {CMD}")

# Output errors to stderr, warnings to stderr
for msg in errors:
    sys.stderr.write(f"load-playbook: ERROR: {msg}\n")
for msg in warnings:
    sys.stderr.write(f"load-playbook: WARNING: {msg}\n")

sys.exit(1 if errors else 0)
PYEOF
