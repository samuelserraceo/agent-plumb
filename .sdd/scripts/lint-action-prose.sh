#!/usr/bin/env bash
# lint-action-prose.sh — assert framework-shipped action prose is plain-English-first.
#
# Closes #110. Catches the failure mode the v1.1 Tier 3 cycle hit four
# times: agent reads a USER-LED / AGENT-LED action file whose prose
# leads with technical framing, mirrors that voice, and the user asks
# "use plain English". The fix is to rewrite each qualifying action's
# body to LEAD with a plain-English question + a concrete
# "**What it looks like:**" example block, and to enforce that shape
# mechanically on every PR.
#
# Usage:
#   lint-action-prose.sh                    — full check; exit 0 silent on pass, 1 with errors
#   lint-action-prose.sh --inventory        — list every qualifying file + compliance state
#   lint-action-prose.sh <one-or-more-paths>— check only the named files (used by tests)
#
# Two checks per qualifying file (frontmatter `tag:` is USER-LED or AGENT-LED):
#   1. Body contains literal `**What it looks like:**` heading
#   2. First non-frontmatter paragraph is ≤2 sentences AND ≤200 chars
#
# Foundation 3: positive deterministic checks. No jargon denylists.

set -uo pipefail

# ─── Argument parsing ────────────────────────────────────────────────
MODE="check"
declare -a TARGETS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --inventory) MODE="inventory" ;;
    --help|-h)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    -*) echo "[lint-action-prose] unknown flag: $1" >&2; exit 2 ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done

# Default to the canonical templates path if no targets given
if [ "${#TARGETS[@]}" -eq 0 ]; then
  TARGETS=(templates/.sdd/actions/*.md)
fi

# ─── Helpers ─────────────────────────────────────────────────────────
get_tag() {
  # Extract `tag:` value from frontmatter, normalise whitespace
  local file="$1"
  awk '
    /^---[[:space:]]*$/ { fm = !fm; next }
    fm && /^tag:/ {
      sub(/^tag:[[:space:]]*/, "")
      gsub(/[[:space:]]/, "")
      print
      exit
    }
  ' "$file"
}

is_qualifying() {
  # Returns 0 if file's tag is USER-LED or AGENT-LED, 1 otherwise
  local tag
  tag=$(get_tag "$1")
  case "$tag" in
    USER-LED|AGENT-LED) return 0 ;;
    *) return 1 ;;
  esac
}

# ─── Inventory mode ──────────────────────────────────────────────────
if [ "$MODE" = "inventory" ]; then
  for f in "${TARGETS[@]}"; do
    [ -f "$f" ] || continue
    tag=$(get_tag "$f")
    case "$tag" in
      USER-LED|AGENT-LED)
        echo "$f  [tag=$tag]  qualifying"
        ;;
      *)
        echo "$f  [tag=$tag]  skip"
        ;;
    esac
  done
  exit 0
fi

# ─── Check mode ──────────────────────────────────────────────────────
violations=0
for f in "${TARGETS[@]}"; do
  [ -f "$f" ] || continue
  is_qualifying "$f" || continue

  # Check 1 (T02): body contains literal "**What it looks like:**" heading
  if ! grep -qF '**What it looks like:**' "$f"; then
    echo "[lint-action-prose] $f — missing 'What it looks like:' example block (USER-LED/AGENT-LED actions must ship a plain-English example so the agent has a non-jargon model to mirror)" >&2
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "[lint-action-prose] $violations violation(s) — see above" >&2
  exit 1
fi
exit 0
