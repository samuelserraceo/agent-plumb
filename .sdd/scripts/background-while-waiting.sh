#!/usr/bin/env bash
# background-while-waiting.sh — Emit a marker line per wait window
# (CR-poll / CI-poll), and let the agent declare which safe-set action
# was taken. Trigger + measurement for the §2 metric of feature 008.
#
# Usage:
#   background-while-waiting.sh <wait_type>
#       Emit a new marker line. wait_type ∈ {cr-poll, ci-poll, other}.
#       Initial action_chosen = "pending".
#
#   background-while-waiting.sh --list-candidates
#       Print the safe-set candidate names to stderr (one per line).
#       The agent reads these and picks one.
#
#   background-while-waiting.sh --update-last-action <choice>
#       Update the last log line's action_chosen field. choice ∈
#       {re-read-corpus, pre-fetch-next-feature, draft-pr-description,
#        draft-commit-msgs, speculative-cr-response, none-skipped}.
#
# Output:
#   Marker log at ${SDD_CACHE_DIR}/background-emit.log (defaults to
#   .sdd/.cache/background-emit.log relative to repo root).
#
#   Schema (one JSON object per line):
#     { "ts": "<ISO-8601>", "session_id": "<8-hex>",
#       "wait_type": "<closed-enum>", "action_chosen": "<closed-enum>" }
#
# Exits:
#   0 — success
#   2 — usage error
#   3 — log write failure (disk full, permission denied, etc.)

set -uo pipefail

# Resolve cache directory.
if [ -n "${SDD_CACHE_DIR:-}" ]; then
  CACHE_DIR="$SDD_CACHE_DIR"
else
  REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
  CACHE_DIR="$REPO_ROOT/.sdd/.cache"
fi
LOG="$CACHE_DIR/background-emit.log"

CANDIDATES=(
  re-read-corpus
  pre-fetch-next-feature
  draft-pr-description
  draft-commit-msgs
)

# Session-id: 8 hex chars, stable per shell session via env var so
# successive emits in the same session share an id.
if [ -z "${SDD_SESSION_ID:-}" ]; then
  if command -v openssl >/dev/null 2>&1; then
    export SDD_SESSION_ID="$(openssl rand -hex 4)"
  else
    # Fallback: use $$ + nanoseconds.
    export SDD_SESSION_ID="$(printf '%08x' $(($$ * 1000 + RANDOM % 1000)))"
  fi
fi

iso_ts() {
  if date -u +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
    date -u +%Y-%m-%dT%H:%M:%SZ
  else
    python3 -c 'import datetime; print(datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"))'
  fi
}

usage() {
  cat <<EOF
Usage:
  background-while-waiting.sh <wait_type>
  background-while-waiting.sh --list-candidates
  background-while-waiting.sh --update-last-action <choice>

wait_type: cr-poll | ci-poll | other
choice:    re-read-corpus | pre-fetch-next-feature | draft-pr-description |
           draft-commit-msgs | speculative-cr-response | none-skipped
EOF
}

# Subcommand: --list-candidates
if [ "${1:-}" = "--list-candidates" ]; then
  for c in "${CANDIDATES[@]}"; do
    echo "$c" >&2
  done
  exit 0
fi

# Subcommand: --update-last-action <choice>
if [ "${1:-}" = "--update-last-action" ]; then
  if [ -z "${2:-}" ]; then
    usage >&2
    exit 2
  fi
  choice="$2"
  case "$choice" in
    re-read-corpus|pre-fetch-next-feature|draft-pr-description|draft-commit-msgs|speculative-cr-response|none-skipped) ;;
    *) echo "background-while-waiting: invalid choice: $choice" >&2; usage >&2; exit 2 ;;
  esac
  if [ ! -f "$LOG" ]; then
    echo "background-while-waiting: log file not found: $LOG" >&2
    exit 3
  fi
  # Read all lines, update the last one.
  tmp=$(mktemp)
  if ! python3 - "$LOG" "$choice" "$tmp" <<'PYEOF'
import json, sys
log_path, choice, tmp_path = sys.argv[1:4]
with open(log_path) as f:
    lines = f.readlines()
if not lines:
    sys.exit(3)
last = json.loads(lines[-1].strip())
last["action_chosen"] = choice
lines[-1] = json.dumps(last) + "\n"
with open(tmp_path, "w") as f:
    f.writelines(lines)
PYEOF
  then
    rm -f "$tmp"
    echo "background-while-waiting: failed to update last action" >&2
    exit 3
  fi
  mv "$tmp" "$LOG"
  exit 0
fi

# Default subcommand: emit a marker.
wait_type="${1:-}"
case "$wait_type" in
  cr-poll|ci-poll|other) ;;
  ""|--help|-h) usage >&2; exit 2 ;;
  *) echo "background-while-waiting: invalid wait_type: $wait_type" >&2; usage >&2; exit 2 ;;
esac

# Ensure cache dir exists.
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
  echo "background-while-waiting: failed to create cache dir $CACHE_DIR" >&2
  exit 3
fi

# Build the marker line.
ts=$(iso_ts)
line=$(python3 -c "import json,sys; print(json.dumps({'ts': sys.argv[1], 'session_id': sys.argv[2], 'wait_type': sys.argv[3], 'action_chosen': 'pending'}))" "$ts" "$SDD_SESSION_ID" "$wait_type")

# Append to log.
if ! printf '%s\n' "$line" >> "$LOG" 2>/dev/null; then
  echo "background-while-waiting: failed to append to $LOG" >&2
  exit 3
fi

exit 0
