#!/usr/bin/env bash
# read-events.sh — F2 events resolver.
#
# Reads .sdd/config.md frontmatter `events:` block and resolves a
# specific event name to the list of file actions it fires.
#
# Usage:
#   read-events.sh <event-name>             — list all events if name omitted
#   read-events.sh <event-name> [<work-item>] — resolve <work-item> placeholder
#
# Output (stdout):
#   JSON: { "event": "...", "actions": [ { "target": "...", "action": "..." }, ... ] }
#
# Path placeholders:
#   The events block uses `<work-item>` as a placeholder for the active
#   work-item path (e.g., "features/001-foo"). Pass the work item as
#   second arg; the script substitutes it. If omitted, paths are emitted
#   verbatim (placeholder visible) — useful for printing the full schema.
#
# Determinism: pure file walk + frontmatter read; JSON via
# json.dumps(sort_keys=True, ensure_ascii=False).
#
# Requires: PyYAML (Python's `yaml` module). If PyYAML is missing,
# install with `pip install pyyaml`. The script's broad except below
# treats an ImportError the same as a parse error — exits 1 with a JSON
# error blob — so callers can detect the failure and surface it.

set -uo pipefail

EVENT="${1:-}"
WORK_ITEM="${2:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

EVENT="$EVENT" WORK_ITEM="$WORK_ITEM" PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import json, os, re, sys

proj      = os.environ["PROJ"]
event     = os.environ["EVENT"]
work_item = os.environ["WORK_ITEM"]

config_path = os.path.join(proj, ".sdd", "config.md")
events = {}

if os.path.isfile(config_path):
    # PyYAML import sits OUTSIDE the parse-try so an `ImportError`
    # (PyYAML not installed) doesn't get reported as "frontmatter parse
    # failure" — the user gets a clear "PyYAML missing" diagnostic
    # instead of a misleading config-file error. Closes #95.
    try:
        import yaml
    except ImportError:
        sys.stderr.write(json.dumps({
            "error": "PyYAML not installed — run `pip install pyyaml` "
                     "(SDD framework dependency)"
        }) + "\n")
        sys.exit(1)
    try:
        with open(config_path, encoding="utf-8") as f:
            text = f.read()
        m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
        if m:
            fm = yaml.safe_load(m.group(1)) or {}
            events = fm.get("events") or {}
            # Shape guard: `events:` must be a mapping (dict). A malformed
            # frontmatter that gives `events: []` (list) or `events: foo`
            # (string) would crash on `.items()` / `.get(...)` below; treat
            # it the same as missing — emit empty events JSON and exit 0.
            if not isinstance(events, dict):
                events = {}
    except Exception as e:
        # Use json.dumps to escape the exception message safely. Earlier
        # f-string-built JSON would emit malformed output if `e` contained
        # double-quotes or backslashes (CodeRabbit cycle 9).
        sys.stderr.write(json.dumps({
            "error": f"config.md frontmatter parse: {e}"
        }) + "\n")
        sys.exit(1)

def resolve_paths(actions, wi):
    """Substitute <work-item> placeholder if work_item provided."""
    if not wi:
        return actions
    out = []
    for a in actions:
        a2 = dict(a)
        if "target" in a2 and isinstance(a2["target"], str):
            a2["target"] = a2["target"].replace("<work-item>", wi)
        out.append(a2)
    return out

def _spec_actions(spec):
    """Safely pull the `actions:` list out of a per-event spec.

    A well-formed event is a mapping like `{ actions: [...] }`. A malformed
    one might be a list, a string, or null. `(spec or {}).get(...)` would
    raise AttributeError on a list/string — so coerce non-dicts to {}.
    """
    if not isinstance(spec, dict):
        return []
    return spec.get("actions") or []

if not event:
    # List all events.
    out = {
        name: {"actions": resolve_paths(_spec_actions(spec), work_item)}
        for name, spec in sorted(events.items())
    }
    sys.stdout.write(json.dumps({"events": out}, sort_keys=True, ensure_ascii=False) + "\n")
    sys.exit(0)

if event not in events:
    sys.stdout.write(json.dumps(
        {"event": event, "actions": [], "_note": f"event '{event}' not declared in config.md"},
        sort_keys=True, ensure_ascii=False) + "\n")
    sys.exit(0)

spec = events[event]
actions = resolve_paths(_spec_actions(spec), work_item)
sys.stdout.write(json.dumps(
    {"event": event, "actions": actions},
    sort_keys=True, ensure_ascii=False) + "\n")
PYEOF
