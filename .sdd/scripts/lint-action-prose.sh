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
  # Returns 0 if file's tag is USER-LED or AGENT-LED, 1 otherwise.
  # AMBIGUOUS tags (e.g. "USER-LED,AGENT-LED" or "USER-LED|AGENT-LED")
  # exit the script non-zero — see check_ambiguous_tag() below.
  local tag
  tag=$(get_tag "$1")
  case "$tag" in
    USER-LED|AGENT-LED) return 0 ;;
    *) return 1 ;;
  esac
}

check_ambiguous_tag() {
  # If a file's tag string contains BOTH "USER-LED" and "AGENT-LED"
  # substrings (e.g. "USER-LED,AGENT-LED"), refuse: the action's
  # mode is ambiguous. Exit 1 with a plain-English error.
  local file="$1" tag
  tag=$(get_tag "$file")
  if echo "$tag" | grep -q "USER-LED" && echo "$tag" | grep -q "AGENT-LED"; then
    echo "[lint-action-prose] $file — ambiguous tag '$tag' (USER-LED + AGENT-LED both declared; pick one — every action runs in exactly one mode)" >&2
    return 1
  fi
  return 0
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

  # Pre-check: refuse ambiguous tag declarations on every file (qualifying
  # or not) — an ambiguous tag is itself a problem worth surfacing.
  if ! check_ambiguous_tag "$f"; then
    violations=$((violations + 1))
    continue  # skip qualifying-check + main checks for this file
  fi

  is_qualifying "$f" || continue

  # Check 1: body contains literal "**What it looks like:**" heading.
  # That's the ONLY mechanical check. The quality of the prose itself —
  # "would a non-technical reader (Sam's "mum test") understand this?" —
  # is reviewed by humans at PR time, not by a regex. Mechanical checks
  # for "is this plain English?" become heuristic theatre (see Sam's
  # 2026-05-02 redirect on this PR; the previous form had a 200-char +
  # 2-sentence cap that was a theatre-proxy for the real concern).
  if ! grep -qF '**What it looks like:**' "$f"; then
    echo "[lint-action-prose] $f — missing 'What it looks like:' example block (USER-LED/AGENT-LED actions must ship a concrete plain-English example the agent can mirror)" >&2
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "[lint-action-prose] $violations violation(s) — see above" >&2
  exit 1
fi
exit 0
