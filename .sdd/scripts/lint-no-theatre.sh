#!/usr/bin/env bash
# lint-no-theatre.sh — refuse spec.md content that claims things the
# framework can't verify. Closes #111.
#
# A "theatre claim" is a sentence that LOOKS like an enforced guard
# (numerical bound, currency cost limit, enforcement verb, quality
# absolute) but isn't. The classic example Sam caught dogfooding
# v1.1 Tier 3: `cost_limit_usd: 0.50` — looked like a circuit breaker,
# but the framework has no per-provider pricing so it would never fire.
#
# This lint scans staged spec.md (or a target file passed as argv) for
# four token categories and refuses each match unless an ADJACENT
# verifier annotation is present:
#
#   {verify-by: <test-id>}    — points at a test/fixture/AC that proves
#   {best-effort: <who>}      — judgement-based, named human reviewer
#   {prod-only: <reason>}     — verifiable only against live infra
#
# Annotation lookup window: same line OR next 3 lines.
#
# Usage:
#   lint-no-theatre.sh                   — scan active feature's spec.md
#   lint-no-theatre.sh <path>            — scan one file
#
# Exit:
#   0 — no theatre OR every match has a neighbouring annotation
#   1 — at least one unannotated theatre claim found
#   2 — usage / IO error

set -uo pipefail

# ─── Argument parsing ────────────────────────────────────────────────
declare -a TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      sed -n '2,30p' "$0"; exit 0 ;;
    -*) echo "[lint-no-theatre] unknown flag: $1" >&2; exit 2 ;;
    *)  TARGETS+=("$1") ;;
  esac
  shift
done

# Default: active feature's spec.md
if [ "${#TARGETS[@]}" -eq 0 ]; then
  if [ -x .sdd/scripts/resolve-active.sh ]; then
    active=$(.sdd/scripts/resolve-active.sh 2>/dev/null \
              | python3 -c 'import sys,json; print(json.load(sys.stdin).get("active") or "")' 2>/dev/null)
    if [ -n "$active" ] && [ -f ".sdd/$active/spec.md" ]; then
      TARGETS=(".sdd/$active/spec.md")
    fi
  fi
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "[lint-no-theatre] no targets — pass a file or run inside a project with an active feature" >&2
  exit 0  # No-op success when there's nothing to check
fi

# ─── Token categories ────────────────────────────────────────────────
# Each category lists ERE patterns. Matches in any category trigger
# the verifier-annotation requirement.
#
# Note: bash regex grouping uses `()` for ERE. Word boundaries are
# `[[:<:]]`/`[[:>:]]` on BSD-grep but those aren't portable — use
# `[^[:alnum:]_]` flanks instead (see lint-action-prose.sh same
# choice from PR #118 cycle 3).

# Numerical: 1KB, 80%, ≥5, ≤100ms, etc. Match digit + unit/sign.
TOK_NUMERIC='([0-9]+%|[<>≤≥]\s*[0-9]+\s*(KB|MB|ms|sec|tokens?|bytes?)|at least [0-9]+|≥[[:space:]]*[0-9]+|≤[[:space:]]*[0-9]+)'

# Currency: $0.50, USD, dollars, cents
TOK_CURRENCY='(\$[0-9]+(\.[0-9]+)?|USD|cents?|dollars?)'

# Enforcement verbs (whole-word). Refuses/enforces/prevents/ensures/guarantees.
# Plus absolute always/never (rare but classic theatre).
TOK_ENFORCE='(refuses?|enforces?|prevents?|ensures?|guarantees?|always|never)'

# Quality absolutes (whole-word). correctly/accurate/reliable/complete.
TOK_QUALITY='(correctly|accurate|reliable|complete)'

# Combined regex — any of the above.
COMBINED="($TOK_NUMERIC|$TOK_CURRENCY|[^[:alnum:]_]$TOK_ENFORCE([^[:alnum:]_]|$)|[^[:alnum:]_]$TOK_QUALITY([^[:alnum:]_]|$))"

# ─── Annotation regex ────────────────────────────────────────────────
# Tolerates whitespace inside braces (CR feedback expected pattern).
# Matches: `{verify-by:T05}`, `{ verify-by : T05 }`, etc.
ANNOT_RE='\{[[:space:]]*(verify-by|best-effort|prod-only)[[:space:]]*:[[:space:]]*[^}]+\}'

# ─── Code-fence + inline-code skip ───────────────────────────────────
# Flag lines OUTSIDE triple-backtick fences. For inline `code` spans
# on a flagged line, replace inline-code substrings with empty before
# matching theatre tokens (so a token inside `…` doesn't fire).

# ─── Main scan ───────────────────────────────────────────────────────
violations=0
for spec in "${TARGETS[@]}"; do
  if [ ! -f "$spec" ]; then
    echo "[lint-no-theatre] $spec: not a file" >&2
    exit 2
  fi

  # Read file once into an array of lines.
  # Portable alternative to `mapfile -t` (bash-4-only) — works on
  # macOS bash 3.2 + linux bash 5+.
  LINES=()
  while IFS= read -r line || [ -n "$line" ]; do
    LINES+=("$line")
  done < "$spec"
  in_fence=0
  total=${#LINES[@]}

  for i in "${!LINES[@]}"; do
    line="${LINES[$i]}"

    # Toggle fence state on any line that contains ``` at start (after
    # optional whitespace). Don't scan tokens INSIDE fenced blocks.
    if [[ "$line" =~ ^[[:space:]]*\`\`\` ]]; then
      in_fence=$((1 - in_fence))
      continue
    fi
    if [ "$in_fence" -eq 1 ]; then continue; fi

    # Strip inline `code` spans before matching tokens. This way
    # backticked teaching examples don't false-positive.
    stripped=$(printf '%s\n' "$line" | sed -E 's/`[^`]*`//g')

    # Match each token category separately so the error message can
    # name what was found. Use grep -iE for case-insensitive matching
    # (catches `usd` in `cost_limit_usd:` as well as uppercase `USD`).
    found_token=""
    # Numerical: byte/time/percent quantities. Unit is optional after
    # comparator+number so `≥80` and `<5` (without explicit unit) also
    # fire — bare numerical thresholds are theatre-shaped too.
    m=$(printf '%s' "$stripped" | grep -ioE '([0-9]+%|[<>≤≥][[:space:]]*[0-9]+([[:space:]]*(KB|MB|ms|sec|tokens?|bytes?))?|at least [0-9]+)' | head -1)
    if [ -n "$m" ]; then
      found_token="$m"
    fi
    if [ -z "$found_token" ]; then
      # Currency tokens. Token-specific boundaries:
      #   - `\$N` where N≥1 — matches anywhere (`$0` alone is "free", skip)
      #   - `usd`, `dollars?` — match anywhere; rare false positives,
      #     and `cost_limit_usd` IS the canonical Sam example we want.
      #   - `cents?` — require non-letter boundary (otherwise matches
      #     inside `agent`, `recent`, `decent`).
      # Currency $N — allow $0, $0.50 too (a "$0 cap" claim is still
      # theatre about the cost). CR cycle 1: previous [1-9] gate
      # missed valid theatre cases.
      m=$(printf '%s' "$stripped" | grep -ioE '\$[0-9]+(\.[0-9]+)?' | head -1)
      if [ -n "$m" ]; then
        found_token="$m"
      fi
      if [ -z "$found_token" ]; then
        m=$(printf '%s' "$stripped" | grep -ioE '(usd|dollars?)' | head -1)
        if [ -n "$m" ]; then
          found_token="$m"
        fi
      fi
      if [ -z "$found_token" ]; then
        m=$(printf '%s' "$stripped" | grep -ioE '(^|[^[:alpha:]])(cents?)([^[:alpha:]]|$)' | head -1)
        if [ -n "$m" ]; then
          found_token=$(printf '%s' "$m" | grep -ioE 'cents?' | head -1)
        fi
      fi
    fi
    if [ -z "$found_token" ]; then
      m=$(printf '%s' "$stripped" | grep -ioE '(^|[^[:alnum:]_])(refuses?|enforces?|prevents?|ensures?|guarantees?|always|never)([^[:alnum:]_]|$)' | head -1 | grep -ioE '(refuses?|enforces?|prevents?|ensures?|guarantees?|always|never)' | head -1)
      if [ -n "$m" ]; then
        found_token="$m"
      fi
    fi
    if [ -z "$found_token" ]; then
      m=$(printf '%s' "$stripped" | grep -ioE '(^|[^[:alnum:]_])(correctly|accurate|reliable|complete)([^[:alnum:]_]|$)' | head -1 | grep -ioE '(correctly|accurate|reliable|complete)' | head -1)
      if [ -n "$m" ]; then
        found_token="$m"
      fi
    fi

    if [ -z "$found_token" ]; then continue; fi

    # Look for an adjacent annotation: same line OR next 3 lines.
    has_annotation=0
    for delta in 0 1 2 3; do
      idx=$((i + delta))
      if [ "$idx" -ge "$total" ]; then break; fi
      if [[ "${LINES[$idx]}" =~ $ANNOT_RE ]]; then
        has_annotation=1
        break
      fi
    done

    if [ "$has_annotation" -eq 0 ]; then
      lineno=$((i + 1))
      echo "[lint-no-theatre] $spec:$lineno — '$found_token' is a theatre claim. Add {verify-by: T-NNN} (points at a test), {best-effort: <who>} (admits judgement-based), or {prod-only: <why>} (live-infra-only) on the same line or within 3 lines below — or soften the wording." >&2
      violations=$((violations + 1))
    fi
  done
done

if [ "$violations" -gt 0 ]; then
  echo "[lint-no-theatre] $violations theatre claim(s) need a verifier annotation — see above" >&2
  exit 1
fi
exit 0
