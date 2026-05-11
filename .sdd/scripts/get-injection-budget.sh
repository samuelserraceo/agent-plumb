#!/usr/bin/env bash
# get-injection-budget.sh — feature 011 helper.
#
# Returns the per-file char budget for a corpus file basename. Reads
# parameters.injection.per_file_budget_chars from .sdd/config.md
# (project default) and merges any project-level override.
#
# Usage:
#   get-injection-budget.sh <basename>
#
#   <basename> — corpus file basename WITHOUT path or extension
#                (e.g. "INDEX", "spec", "principles", "stack",
#                "data-model", "patterns").
#
# Output (stdout):
#   A single positive integer = the resolved char budget.
#
# Behavior:
#   - Known key with declared value → return that value (AC4 / AC7).
#   - Known key with negative value → clamp to 0, emit stderr warning
#     naming the key (AC17).
#   - Unknown basename key → return documented default of 2000 chars
#     (AC8). The default lives as a constant in this script.
#   - per_file_budget_chars block missing / null → return documented
#     default for known keys per the framework's hardcoded defaults
#     table (AC9).
#
# Exit codes:
#   0 — success (budget written to stdout)
#   1 — usage error (no basename argument)
#   2 — config.md not found or unparseable
#
# Determinism: pure file walk. No randomness, no timestamps. Same
# input + same config.md → same output.
#
# Anti-theatre: this script's behavior is verified by feature 011
# tests T223 (resolver basic), T226 (partial override), T227
# (unknown key), T228 (missing block), T236 (negative clamp).

set -uo pipefail

if [ $# -ne 1 ]; then
  echo "get-injection-budget: usage: get-injection-budget.sh <basename>" >&2
  exit 1
fi

BASENAME="$1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_DIR/.sdd/config.md"

if [ ! -f "$CONFIG" ]; then
  echo "get-injection-budget: config.md not found at $CONFIG" >&2
  exit 2
fi

CONFIG="$CONFIG" BASENAME="$BASENAME" python3 <<'PYEOF'
import os, re, sys

config_path = os.environ["CONFIG"]
basename = os.environ["BASENAME"]

# Hardcoded framework defaults (AC9 — when the block is missing /
# null, these are returned for known keys; same values as the
# templates/.sdd/config.md defaults). Centralised here so the resolver
# is self-sufficient even if a project's config.md omits the block
# entirely.
FRAMEWORK_DEFAULTS = {
    "INDEX": 3000,
    "spec": 5000,
    "principles": 2000,
    "stack": 3000,
    "data-model": 3000,
    "patterns": 4000,
}

# Unknown-key default (AC8) — used when the basename argument is not
# in either the project's per_file_budget_chars map or the framework
# defaults table.
UNKNOWN_KEY_DEFAULT = 2000

try:
    with open(config_path, "rb") as f:
        raw = f.read()
except OSError as e:
    print(f"get-injection-budget: cannot read {config_path}: {e}", file=sys.stderr)
    sys.exit(2)

text = raw.decode("utf-8", errors="replace")
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    print(f"get-injection-budget: {config_path} has no YAML frontmatter", file=sys.stderr)
    sys.exit(2)

try:
    import yaml
except ImportError:
    # No PyYAML → fall back to framework defaults (AC9 / minimal-Python
    # graceful degradation). Same pattern as other framework scripts.
    yaml = None

project_budgets = {}
if yaml is not None:
    try:
        fm = yaml.safe_load(m.group(1)) or {}
        inj = fm.get("parameters", {}).get("injection") or {}
        block = inj.get("per_file_budget_chars")
        if isinstance(block, dict):
            project_budgets = block
    except Exception as e:
        # CR cycle 1 #12/#17: do not silently swallow YAML parse
        # failures — emit warning naming the file + error before
        # falling back to framework defaults. Otherwise override bugs
        # are invisible to the user.
        print(
            f"get-injection-budget: warning: failed to parse YAML "
            f"frontmatter in {config_path}: {e}; falling back to "
            f"framework defaults",
            file=sys.stderr,
        )
        project_budgets = {}

# Resolution order:
#   1. Project's per_file_budget_chars[basename] if declared
#   2. Framework default for basename if known
#   3. UNKNOWN_KEY_DEFAULT for everything else
if basename in project_budgets:
    value = project_budgets[basename]
    # Must be an integer (or int-coercible). Strings/lists/None reject.
    if not isinstance(value, bool) and isinstance(value, int):
        if value < 0:
            # AC17 — clamp to 0 + stderr warning naming the key.
            print(
                f"get-injection-budget: warning: per_file_budget_chars.{basename} "
                f"is negative ({value}); clamping to 0",
                file=sys.stderr,
            )
            print(0)
            sys.exit(0)
        print(value)
        sys.exit(0)
    else:
        # Malformed value — fall through to framework default with
        # a stderr warning (defensive, matches AC17 pattern).
        print(
            f"get-injection-budget: warning: per_file_budget_chars.{basename} "
            f"is not an integer (got: {value!r}); falling back to framework default",
            file=sys.stderr,
        )

if basename in FRAMEWORK_DEFAULTS:
    print(FRAMEWORK_DEFAULTS[basename])
    sys.exit(0)

# AC8 — unknown basename, return documented default.
print(UNKNOWN_KEY_DEFAULT)
sys.exit(0)
PYEOF
