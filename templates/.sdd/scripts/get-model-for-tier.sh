#!/usr/bin/env bash
# get-model-for-tier.sh — Lego-style model right-sizing resolver
# (idea 002, 2026-05-10).
#
# Reads:
#   1. An action's `model_tier:` frontmatter (the per-action declaration)
#   2. `.sdd/config.md` `parameters.models.<tier>:` (the project override)
#
# Returns: the model identifier string the framework should pick for
# that action, or an empty string when the project hasn't overridden
# the tier (caller falls back to whatever Claude Code is already
# running — opt-in, backwards-compat).
#
# Usage:
#   get-model-for-tier.sh <action-slug>      — return model for action
#   get-model-for-tier.sh --tier <tier>      — return model for a tier
#                                              directly (skip action lookup)
#
# Exit:
#   0 — emitted a model string (possibly empty)
#   2 — usage / IO error
#
# Notes:
# - Bash 3.2 compatible (macOS default; no associative arrays).
# - PyYAML required (already a framework dependency per
#   resolve-parameters.sh).
# - Backwards-compat: an action without `model_tier:` falls back to
#   tier=routine (safe middle default).
# - Unknown tier in frontmatter (not in {thinking,routine,mechanical})
#   emits a stderr warning and falls back to routine — same shape as
#   resolve-parameters.sh's automation.level handling.

set -uo pipefail

usage() {
  cat >&2 <<'EOF'
usage: get-model-for-tier.sh <action-slug>
       get-model-for-tier.sh --tier <tier>

Returns the model identifier configured for the action's cognitive
tier (or for the tier directly, with --tier). Empty stdout means the
project hasn't set a model for that tier — caller falls back to
Claude Code's default.
EOF
}

if [ $# -lt 1 ]; then
  usage; exit 2
fi

ACTION_SLUG=""
TIER_DIRECT=""
case "$1" in
  --help|-h) usage; exit 0 ;;
  --tier)
    if [ $# -lt 2 ]; then usage; exit 2; fi
    TIER_DIRECT="$2"
    ;;
  -*) echo "[get-model-for-tier] unknown flag: $1" >&2; usage; exit 2 ;;
  *)  ACTION_SLUG="$1" ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

ACTION_SLUG="$ACTION_SLUG" TIER_DIRECT="$TIER_DIRECT" \
  PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import json, os, re, sys

proj   = os.environ["PROJ"]
action = os.environ["ACTION_SLUG"]
tier_direct = os.environ["TIER_DIRECT"]

VALID_TIERS = ("thinking", "routine", "mechanical")
FALLBACK_TIER = "routine"  # safe middle when action has no model_tier:

def read_frontmatter(path):
    """Return YAML frontmatter as dict; {} on missing-file / no-block /
    parse-error. Same shape as resolve-parameters.sh's reader (#95)."""
    if not os.path.isfile(path):
        return {}
    try:
        import yaml
    except ImportError:
        sys.stderr.write(
            "[get-model-for-tier] PyYAML not installed — run "
            "`pip install pyyaml` (SDD framework dependency)\n"
        )
        sys.exit(1)
    try:
        with open(path, encoding="utf-8") as f:
            t = f.read()
        m = re.match(r'^---\n(.*?)\n---', t, re.DOTALL)
        if not m:
            return {}
        return yaml.safe_load(m.group(1)) or {}
    except (yaml.YAMLError, OSError):
        return {}

# Step 1 — resolve which tier we're asking about.
if tier_direct:
    tier = tier_direct
else:
    action_path = os.path.join(proj, ".sdd", "actions", f"{action}.md")
    fm = read_frontmatter(action_path)
    tier = fm.get("model_tier")
    if tier in (None, ""):
        # Backwards-compat: action without `model_tier:` falls back to
        # routine. Quiet — this IS the documented default for older
        # actions that predate idea 002.
        tier = FALLBACK_TIER

# Step 2 — validate tier.
if tier not in VALID_TIERS:
    sys.stderr.write(
        f"[get-model-for-tier] warning: tier=\"{tier}\" is not one of "
        f"{VALID_TIERS} — falling back to \"{FALLBACK_TIER}\".\n"
    )
    tier = FALLBACK_TIER

# Step 3 — look up the project's model for this tier in config.md.
config_path = os.path.join(proj, ".sdd", "config.md")
cfg = read_frontmatter(config_path)
params = cfg.get("parameters") or {}
models = params.get("models") or {}
model_str = models.get(tier, "")

# Empty stdout when the tier isn't mapped — caller's responsibility to
# fall back to Claude Code's default. Newline so shell consumers can
# `read` cleanly.
if model_str is None:
    model_str = ""
sys.stdout.write(str(model_str) + "\n")
PYEOF
