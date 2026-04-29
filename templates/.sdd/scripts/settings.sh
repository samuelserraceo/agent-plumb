#!/usr/bin/env bash
# settings.sh — body of the /settings slash command (v0.10).
#
# Lists, prints, sets, or resets a setting in .sdd/config.md.
#
# Usage:
#   settings.sh list                 # full inventory
#   settings.sh get <key>            # print one setting + provenance
#   settings.sh set <key> <value>    # change one setting (in-place YAML edit)
#   settings.sh reset <key>          # remove an override (project default returns)
#
# Exit:
#   0 — success
#   1 — usage error or config malformed
#   2 — key not recognised
#
# `<key>` uses dot-notation: `budget.max_minutes`, `parameters.ralph.max_iters`,
# `file_rules['.sdd/decisions.md'].append_only`, etc.
#
# This script is a thin wrapper around a Python in-line that reads/
# writes the YAML frontmatter of .sdd/config.md. Why bash + Python:
# bash for fast invocation; Python because YAML round-tripping in
# pure bash is a nightmare and PyYAML is already a framework dep.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "[settings] usage: settings.sh {list|get|set|reset} [key] [value]" >&2
  exit 1
fi

CMD="$1"
KEY="${2:-}"
VAL="${3:-}"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_DIR/.sdd/config.md"

if [ ! -f "$CONFIG" ]; then
  echo "[settings] .sdd/config.md not found in $PROJECT_DIR" >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || {
  echo "[settings] python3 required but not on PATH" >&2
  exit 1
}

CONFIG="$CONFIG" CMD="$CMD" KEY="$KEY" VAL="$VAL" PROJECT_DIR="$PROJECT_DIR" python3 <<'PYEOF'
import json, os, re, subprocess, sys
try:
    import yaml
except ImportError:
    print("[settings] PyYAML is required (install with: pip install pyyaml).",
          file=sys.stderr)
    sys.exit(1)

config_path = os.environ["CONFIG"]
project_dir = os.environ["PROJECT_DIR"]
cmd = os.environ["CMD"]
key = os.environ["KEY"]
val = os.environ["VAL"]

with open(config_path, encoding="utf-8") as f:
    text = f.read()

m = re.match(r'^---\n(.*?)\n---\n(.*)$', text, re.DOTALL)
if not m:
    print(f"[settings] config.md missing YAML frontmatter", file=sys.stderr)
    sys.exit(1)

fm_text = m.group(1)
body = m.group(2)
# CodeRabbit cycle 3 (PR #31): wrap yaml.safe_load in try/except so a
# malformed frontmatter (e.g., duplicate keys, bad indentation) gives
# a plain-English error instead of a Python traceback.
try:
    fm = yaml.safe_load(fm_text) or {}
except yaml.YAMLError as e:
    print(f"[settings] config.md frontmatter is malformed YAML: {e}",
          file=sys.stderr)
    sys.exit(1)
if not isinstance(fm, dict):
    print(f"[settings] config.md frontmatter is not a mapping (got {type(fm).__name__})",
          file=sys.stderr)
    sys.exit(1)

def walk(d, prefix=""):
    """Yield (dotted_key, value) for every leaf in `d`."""
    for k, v in d.items():
        path = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            yield from walk(v, path)
        else:
            yield path, v

def _split_dotted(s):
    """Split a dotted key on `.` but respect double-quoted segments
    so paths embedded in keys (e.g. `file_rules."a.b.md".append_only`)
    work as a single segment. Closes #35.

    Examples:
      'a.b.c'                  -> ['a', 'b', 'c']
      'file_rules."a.b.c".x'   -> ['file_rules', 'a.b.c', 'x']
      'a."b.c"'                -> ['a', 'b.c']
    """
    parts = []
    cur = []
    in_quote = False
    for ch in s:
        if ch == '"':
            in_quote = not in_quote
            continue
        if ch == '.' and not in_quote:
            parts.append(''.join(cur))
            cur = []
            continue
        cur.append(ch)
    parts.append(''.join(cur))
    return parts

def get_at(d, dotted):
    """Walk dotted path; return value or raise KeyError.
    UAT v0.10.1 (#52): also accept the relative form (without
    `parameters.` prefix) for top-level parameter keys, so users
    reaching for the displayed key from `/settings list` find it.
    Lookup order: full path first, then `parameters.<dotted>`."""
    parts = _split_dotted(dotted)
    try:
        cur = d
        for p in parts:
            if not isinstance(cur, dict) or p not in cur:
                raise KeyError(dotted)
            cur = cur[p]
        return cur
    except KeyError:
        # Try the parameters-prefixed form
        if not dotted.startswith("parameters."):
            try:
                return get_at(d, "parameters." + dotted)
            except KeyError:
                pass
        raise

# Type expectations for known scalar fields. UAT v0.10.1 (#50): used by
# set_at to refuse non-numeric values for numeric fields with a plain
# error. Not exhaustive — unknown fields fall through to the loose
# coercion path. The list documents the framework's "known shape" for
# parameters that have a canonical type.
KNOWN_INT_FIELDS = {
    "parameters.budget.max_minutes",
    "parameters.budget.max_tokens",
    "parameters.budget.max_commits",
    "parameters.pace.halt_on_red_after_attempts",
    "parameters.ralph.max_iters",
    "parameters.ralph.timeout_per_iter",
    "parameters.review.poll_interval",
    "parameters.review.max_polls",
}
KNOWN_BOOL_FIELDS = {
    "parameters.voice.plain_english",
    "parameters.voice.translate_jargon_on_first_use",
}

def set_at(d, dotted, value):
    """Walk dotted path; set leaf to value. Creates intermediate dicts as needed.
    UAT v0.10.1 (#50): refuses non-numeric values for known-int fields,
    non-bool for known-bool, with a plain-English error. Unknown fields
    fall through to loose coercion as before.
    Also (UAT #52) accepts the relative form for top-level params:
    if the dotted path doesn't start with parameters./events./… and the
    full form `parameters.<dotted>` is in KNOWN_INT/BOOL_FIELDS, normalise."""
    # Normalise the dotted path: if a relative form (e.g.
    # `budget.max_minutes`) doesn't start with a top-level config block
    # prefix, fall back to `parameters.<dotted>` — same rule as get_at.
    # Earlier this normalisation only fired when the prefixed form
    # matched KNOWN_INT/BOOL_FIELDS, creating an asymmetry: a /settings
    # set on an unknown-but-valid relative key would write to the wrong
    # branch of the YAML tree (set_at would create top-level
    # `<key>: <value>` instead of `parameters.<key>: <value>`). Now:
    # set_at + get_at both fall back to `parameters.<dotted>` for any
    # unprefixed key. CodeRabbit cycle-3 PR #53.
    if not dotted.startswith(("parameters.", "events.", "file_rules.", "state_rules.", "folder_rules.", "file_classes.", "co_stage_block.")):
        dotted = "parameters." + dotted

    # Type-validate before coercion.
    if dotted in KNOWN_INT_FIELDS:
        try:
            coerced = int(value)
        except ValueError:
            print(f"[settings] {dotted} expects a positive integer. Got: {value!r}.",
                  file=sys.stderr)
            print(f"[settings] Try: settings.sh set {dotted} 30", file=sys.stderr)
            sys.exit(1)
        # CodeRabbit cycle 2 fix (PR #53): also reject 0 and negative
        # values. KNOWN_INT_FIELDS are all caps/limits/timeouts that
        # require a positive integer (max_minutes=0 means "warn after
        # zero minutes" which always fires; max_iters=0 means Ralph
        # never starts; etc.).
        if coerced <= 0:
            print(f"[settings] {dotted} expects a positive integer. Got: {coerced} (must be > 0).",
                  file=sys.stderr)
            print(f"[settings] Try: settings.sh set {dotted} 30", file=sys.stderr)
            sys.exit(1)
    elif dotted in KNOWN_BOOL_FIELDS:
        if value.lower() in ("true", "yes", "on", "1"):
            coerced = True
        elif value.lower() in ("false", "no", "off", "0"):
            coerced = False
        else:
            print(f"[settings] {dotted} expects a boolean (true/false). Got: {value!r}.",
                  file=sys.stderr)
            sys.exit(1)
    else:
        # Loose coercion for unknown fields (preserves backwards compat).
        if value.lower() == "true":
            coerced = True
        elif value.lower() == "false":
            coerced = False
        else:
            try:
                coerced = int(value)
            except ValueError:
                try:
                    coerced = float(value)
                except ValueError:
                    coerced = value

    parts = _split_dotted(dotted)
    cur = d
    for p in parts[:-1]:
        if p not in cur or not isinstance(cur[p], dict):
            cur[p] = {}
        cur = cur[p]
    cur[parts[-1]] = coerced

def del_at(d, dotted):
    """Walk dotted path; delete leaf. Returns True if removed."""
    parts = _split_dotted(dotted)
    cur = d
    for p in parts[:-1]:
        if not isinstance(cur, dict) or p not in cur:
            return False
        cur = cur[p]
    if parts[-1] in cur:
        del cur[parts[-1]]
        return True
    return False

def _infer_active_context(proj):
    """Return (spec_path, action_slug, step_id) for the active step,
    or (None, None, None) if no in-flight feature is resolvable.

    Reads `**Active:** <path>` from .sdd/INDEX.md, then invokes
    next-action.sh on that spec to get the active action + step.
    Used by `get` to walk the F5 cascade and report provenance for
    the value the agent would currently see (closes #34)."""
    index_path = os.path.join(proj, ".sdd", "INDEX.md")
    if not os.path.isfile(index_path):
        return None, None, None
    try:
        with open(index_path, encoding="utf-8") as f:
            idx_text = f.read()
    except OSError:
        return None, None, None
    m = re.search(r'^\*\*Active:\*\*\s+(\S+)', idx_text, re.MULTILINE)
    if not m:
        return None, None, None
    spec_rel = m.group(1).strip()
    spec_path = spec_rel if os.path.isabs(spec_rel) else os.path.join(proj, spec_rel)
    if not os.path.isfile(spec_path):
        return None, None, None
    next_action_sh = os.path.join(proj, ".sdd", "scripts", "next-action.sh")
    if not os.path.isfile(next_action_sh):
        return None, None, None
    try:
        result = subprocess.run(
            ["bash", next_action_sh, spec_path],
            capture_output=True, text=True, timeout=5
        )
    except (subprocess.TimeoutExpired, OSError):
        return None, None, None
    if result.returncode != 0 or not result.stdout.strip():
        return None, None, None
    try:
        na = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None, None, None
    action = (na.get("action") or "").strip()
    step = (na.get("step") or "").strip()
    if not action or not step:
        return None, None, None
    return spec_path, action, step

def _resolve_with_provenance(proj, lookup_key, project_value):
    """If `lookup_key` is in the parameters.* cascade AND there's an
    active in-flight feature, run resolve-parameters.sh and return
    (effective_value, source_label) per the F5 cascade. Otherwise
    return (project_value, "project").

    `source_label` is one of: `project`, `work-item`, `stage:<id>`,
    `action:<slug>`, `step:<id>` — the label resolve-parameters.sh
    stamps onto the leaf in its `_provenance` map."""
    if not lookup_key.startswith("parameters."):
        return project_value, "project"
    spec_path, action_slug, step_id = _infer_active_context(proj)
    if not (spec_path and action_slug and step_id):
        return project_value, "project"
    resolver = os.path.join(proj, ".sdd", "scripts", "resolve-parameters.sh")
    if not os.path.isfile(resolver):
        return project_value, "project"
    try:
        result = subprocess.run(
            ["bash", resolver, spec_path, action_slug, step_id],
            capture_output=True, text=True, timeout=5
        )
    except (subprocess.TimeoutExpired, OSError):
        return project_value, "project"
    if result.returncode != 0 or not result.stdout.strip():
        return project_value, "project"
    try:
        resolved = json.loads(result.stdout)
    except json.JSONDecodeError:
        return project_value, "project"
    provenance = resolved.get("_provenance", {})
    cascade_key_short = lookup_key[len("parameters."):]
    cur = resolved
    for part in _split_dotted(cascade_key_short):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return project_value, "project"
    return cur, provenance.get(cascade_key_short, "project")

def _atomic_write_config(text):
    """Atomic write helper: tempfile + rename so a crash mid-write
    doesn't leave the user with a half-written config.md. Closes #36
    by deduplicating the set/reset pair."""
    import tempfile
    tmp_dir = os.path.dirname(config_path) or "."
    fd, tmp_path = tempfile.mkstemp(prefix=".config.tmp.", dir=tmp_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp_path, config_path)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise

if cmd == "list":
    # Print the full inventory grouped by top-level block.
    print("SDD settings (.sdd/config.md):")
    print()
    seen_top = set()
    for k, v in walk(fm):
        top = k.split(".")[0]
        if top not in seen_top:
            print(f"  [{top}]")
            seen_top.add(top)
        print(f"    {k} = {v!r}")
    sys.exit(0)

elif cmd == "get":
    if not key:
        print("[settings] usage: settings.sh get <key>", file=sys.stderr)
        sys.exit(1)
    # Project-default lookup first — also confirms the key is real.
    # get_at already accepts the relative form (e.g. `budget.max_minutes`)
    # by falling back to `parameters.<dotted>`; reproduce that
    # normalisation here so cascade resolution sees the canonical key.
    try:
        project_value = get_at(fm, key)
    except KeyError:
        print(f"[settings] key not found: {key}", file=sys.stderr)
        print(f"[settings] run `settings.sh list` to see all keys.", file=sys.stderr)
        sys.exit(2)
    # Determine the canonical lookup key (for cascade walking).
    lookup_key = key
    config_block_prefixes = (
        "parameters.", "events.", "file_rules.", "state_rules.",
        "folder_rules.", "file_classes.", "co_stage_block.",
    )
    if not lookup_key.startswith(config_block_prefixes):
        lookup_key = "parameters." + lookup_key
    # Walk the F5 cascade if the key lives under parameters.* AND an
    # active feature exists; otherwise fall back to project-only.
    # Closes #34 — provenance label was doc-claimed but missing in code.
    effective_value, source = _resolve_with_provenance(
        project_dir, lookup_key, project_value
    )
    print(f"{key} = {effective_value!r} [{source}]")
    sys.exit(0)

elif cmd == "set":
    if not key or not val:
        print("[settings] usage: settings.sh set <key> <value>", file=sys.stderr)
        sys.exit(1)
    set_at(fm, key, val)
    new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip()
    new_text = f"---\n{new_fm_text}\n---\n{body}"
    _atomic_write_config(new_text)
    print(f"{key} = {get_at(fm, key)!r}  (saved)")
    sys.exit(0)

elif cmd == "reset":
    if not key:
        print("[settings] usage: settings.sh reset <key>", file=sys.stderr)
        sys.exit(1)
    # CodeRabbit cycle-4 PR #53: apply the same prefix normalisation
    # used by set_at + get_at, so /settings reset accepts the relative
    # form (e.g. `budget.max_minutes`) and resolves it to the canonical
    # `parameters.budget.max_minutes` branch. Without this, reset on an
    # unprefixed key silently no-ops because del_at walks a non-existent
    # top-level path.
    if not key.startswith(("parameters.", "events.", "file_rules.", "state_rules.", "folder_rules.", "file_classes.", "co_stage_block.")):
        key = "parameters." + key
    if not del_at(fm, key):
        print(f"[settings] key not found: {key}", file=sys.stderr)
        sys.exit(2)
    new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip()
    new_text = f"---\n{new_fm_text}\n---\n{body}"
    _atomic_write_config(new_text)
    print(f"{key} removed (override deleted; project default applies)")
    sys.exit(0)

else:
    print(f"[settings] unknown command: {cmd}", file=sys.stderr)
    print(f"[settings] usage: settings.sh {{list|get|set|reset}} [key] [value]", file=sys.stderr)
    sys.exit(1)
PYEOF
