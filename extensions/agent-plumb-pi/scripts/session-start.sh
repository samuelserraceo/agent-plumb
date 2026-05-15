#!/usr/bin/env bash
# session-start.sh — invoked by the extension's pi.on("session_start")
# handler the first time pi loads in a project. Two jobs:
#
#   1. Refuse politely if the host pi.dev version is below the
#      extension's declared minimum (folded edge case #6).
#   2. HRN-01 copy-on-first-run — copy framework files from the
#      packaged template (--from) into <project>/.pi/sdd/, but only
#      where the destination doesn't already exist. User edits and
#      previously-shipped files are never overwritten; missing files
#      are filled in. Re-runs are no-ops.
#
# Flags:
#   --project <dir>            project root that owns .pi/
#   --from    <dir>            source tree of framework files (the
#                              extension's packaged template — typically
#                              extensions/sdd-pi-extension/sdd-template/)
#   --min-pi-version <semver>  refuse if PI_VERSION < this
#
# Env:
#   PI_VERSION  the host pi.dev's reported version (set by pi at
#               session_start; the test harness sets it directly).

set -euo pipefail

# Portable semver comparator (CR finding #13). `sort -V` is GNU-only;
# macOS ships BSD sort by default. version_ge LEFT RIGHT — returns 0
# (true) if LEFT >= RIGHT, otherwise non-zero. Splits each version on
# '.', pads the shorter side with zeros, compares numerically.
version_ge() {
  local left="${1#v}" right="${2#v}"
  local IFS=.
  local -a left_parts right_parts
  read -r -a left_parts <<<"$left"
  read -r -a right_parts <<<"$right"

  local max_len=${#left_parts[@]}
  if [ "${#right_parts[@]}" -gt "$max_len" ]; then
    max_len=${#right_parts[@]}
  fi

  local i l r
  for ((i = 0; i < max_len; i++)); do
    l="${left_parts[i]:-0}"
    r="${right_parts[i]:-0}"
    # 10# forces decimal interpretation, dodging octal pitfalls on 0-prefixed
    if ((10#$l > 10#$r)); then
      return 0
    elif ((10#$l < 10#$r)); then
      return 1
    fi
  done
  return 0  # equal
}

project=""
from=""
min_pi_version=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project|--from|--min-pi-version)
      # Guard the $2 dereference — under set -u a trailing flag like
      # `--project` with no value would otherwise abort with an
      # opaque "unbound variable" error instead of a clear CLI error.
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        echo "[sdd-pi] missing value for $1" >&2
        exit 2
      fi
      case "$1" in
        --project)         project="$2" ;;
        --from)            from="$2" ;;
        --min-pi-version)  min_pi_version="$2" ;;
      esac
      shift 2
      ;;
    *) echo "[sdd-pi] unknown flag: $1" >&2; exit 2 ;;
  esac
done

for f in project from min_pi_version; do
  if [ -z "${!f}" ]; then
    echo "[sdd-pi] missing required flag: --${f//_/-}" >&2
    exit 2
  fi
done

if [ ! -d "$from" ]; then
  echo "[sdd-pi] --from dir does not exist: $from" >&2
  exit 2
fi

# --- pi version gate (folded EC #6) --------------------------------
current_pi_version="${PI_VERSION:-}"
if [ -z "$current_pi_version" ]; then
  echo "[sdd-pi] PI_VERSION env not set — cannot verify host pi.dev version." >&2
  exit 1
fi

# Accept current >= min via the portable version_ge helper above.
# Avoids GNU `sort -V` which isn't on default macOS.
if ! version_ge "$current_pi_version" "$min_pi_version"; then
  cat >&2 <<MSG
[sdd-pi] Host pi.dev version $current_pi_version is older than the
        SDD extension's minimum supported version ($min_pi_version).
        Upgrade pi (npm i -g @mariozechner/pi-coding-agent@latest) and
        re-open the project.
MSG
  exit 1
fi

# --- HRN-01 copy-on-first-run --------------------------------------
dest="$project/.pi/sdd"
mkdir -p "$dest"

# Walk every regular file under --from and copy it to the matching
# path under .pi/sdd/ ONLY when the destination is missing.
# Use process substitution (not pipe) so the loop runs in the parent
# shell — set -e then propagates a mkdir/cp failure out of the loop
# instead of getting swallowed by the subshell pipe.
while IFS= read -r -d '' rel; do
  rel="${rel#./}"
  out="$dest/$rel"
  if [ ! -e "$out" ]; then
    mkdir -p "$(dirname "$out")"
    cp "$from/$rel" "$out"
  fi
done < <(cd "$from" && find . -type f -print0)

# --- EC#4 worktree-hookpath check (T210/AC11) ----------------------
# Pre-commit enforcement at git layer relies on core.hooksPath pointing
# at .claude/hooks. When extensions.worktreeConfig=true the worktree-
# level config can override it silently — every commit then bypasses
# anti-theatre / atomic-step / test-first. Surface the conflict at
# session_start time so the user sees the actionable command before
# committing anything.
script_dir="$(cd "$(dirname "$0")" && pwd)"
worktree_check="$script_dir/check-worktree-hookpath.sh"
if [ -f "$worktree_check" ]; then
  ( cd "$project" && bash "$worktree_check" ) || exit 1
fi

# --- Agent Plumb banner --------------------------------------------
# Geeky session-start header. ANSI-colored when terminal supports it,
# plain text otherwise (CI, pipes, dumb terminals).
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
  C_GRN=$'\033[38;5;154m'   # chartreuse
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RST=$'\033[0m'
else
  C_GRN=''; C_BOLD=''; C_DIM=''; C_RST=''
fi

cat <<BANNER

   ${C_GRN}┃${C_RST}
   ${C_GRN}┃${C_RST}
   ${C_GRN}▼${C_RST}
  ${C_GRN}◢█◣${C_RST}        ${C_BOLD}AGENT PLUMB${C_RST}  ${C_DIM}· v0.1 · agent-plumb-pi${C_RST}
   ${C_GRN}▼${C_RST}         ${C_DIM}Specs > vibes.${C_RST}

  ${C_DIM}→${C_RST} ${C_BOLD}/sdd-setup${C_RST}     bootstrap a project ${C_DIM}(once)${C_RST}
  ${C_DIM}→${C_RST} ${C_BOLD}/sdd-next${C_RST}      advance one atomic step
  ${C_DIM}→${C_RST} ${C_BOLD}/sdd-status${C_RST}    where am I?
  ${C_DIM}→${C_RST} ${C_BOLD}/sdd-ship${C_RST}      push branch + open PR
  ${C_DIM}→${C_RST} ${C_BOLD}/sdd-idea${C_RST}      capture a thought to backlog

  ${C_DIM}docs: https://github.com/samuelserraceo/agent-plumb${C_RST}

BANNER

exit 0
