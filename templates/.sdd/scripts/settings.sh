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

CONFIG="$CONFIG" CMD="$CMD" KEY="$KEY" VAL="$VAL" python3 <<'PYEOF'
import os, re, sys
try:
    import yaml
except ImportError:
    print("[settings] PyYAML is required (install with: pip install pyyaml).",
          file=sys.stderr)
    sys.exit(1)

config_path = os.environ["CONFIG"]
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
fm = yaml.safe_load(fm_text) or {}
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

def get_at(d, dotted):
    """Walk dotted path; return value or raise KeyError."""
    parts = dotted.split(".")
    cur = d
    for p in parts:
        if not isinstance(cur, dict) or p not in cur:
            raise KeyError(dotted)
        cur = cur[p]
    return cur

def set_at(d, dotted, value):
    """Walk dotted path; set leaf to value. Creates intermediate dicts as needed."""
    parts = dotted.split(".")
    cur = d
    for p in parts[:-1]:
        if p not in cur or not isinstance(cur[p], dict):
            cur[p] = {}
        cur = cur[p]
    # Coerce common scalars. CodeRabbit cycle-2 fix (PR #31): the
    # earlier `value.lstrip("-").isdigit()` branch could match `--5`
    # (which `int()` then rejects), and didn't handle a leading `+`.
    # Use try/except on int() directly — the canonical "is this an
    # integer?" check.
    if value.lower() == "true":
        cur[parts[-1]] = True
    elif value.lower() == "false":
        cur[parts[-1]] = False
    else:
        try:
            cur[parts[-1]] = int(value)
        except ValueError:
            try:
                cur[parts[-1]] = float(value)
            except ValueError:
                cur[parts[-1]] = value

def del_at(d, dotted):
    """Walk dotted path; delete leaf. Returns True if removed."""
    parts = dotted.split(".")
    cur = d
    for p in parts[:-1]:
        if not isinstance(cur, dict) or p not in cur:
            return False
        cur = cur[p]
    if parts[-1] in cur:
        del cur[parts[-1]]
        return True
    return False

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
    try:
        v = get_at(fm, key)
        print(f"{key} = {v!r}")
    except KeyError:
        print(f"[settings] key not found: {key}", file=sys.stderr)
        print(f"[settings] run `settings.sh list` to see all keys.", file=sys.stderr)
        sys.exit(2)
    sys.exit(0)

elif cmd == "set":
    if not key or not val:
        print("[settings] usage: settings.sh set <key> <value>", file=sys.stderr)
        sys.exit(1)
    set_at(fm, key, val)
    new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip()
    new_text = f"---\n{new_fm_text}\n---\n{body}"
    # Atomic write: tempfile + rename so a crash mid-write doesn't
    # leave the user with a half-written config.md.
    import tempfile
    tmp_dir = os.path.dirname(config_path) or "."
    fd, tmp_path = tempfile.mkstemp(prefix=".config.tmp.", dir=tmp_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new_text)
        os.replace(tmp_path, config_path)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise
    print(f"{key} = {get_at(fm, key)!r}  (saved)")
    sys.exit(0)

elif cmd == "reset":
    if not key:
        print("[settings] usage: settings.sh reset <key>", file=sys.stderr)
        sys.exit(1)
    if not del_at(fm, key):
        print(f"[settings] key not found: {key}", file=sys.stderr)
        sys.exit(2)
    new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip()
    new_text = f"---\n{new_fm_text}\n---\n{body}"
    import tempfile
    tmp_dir = os.path.dirname(config_path) or "."
    fd, tmp_path = tempfile.mkstemp(prefix=".config.tmp.", dir=tmp_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new_text)
        os.replace(tmp_path, config_path)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise
    print(f"{key} removed (override deleted; project default applies)")
    sys.exit(0)

else:
    print(f"[settings] unknown command: {cmd}", file=sys.stderr)
    print(f"[settings] usage: settings.sh {{list|get|set|reset}} [key] [value]", file=sys.stderr)
    sys.exit(1)
PYEOF
