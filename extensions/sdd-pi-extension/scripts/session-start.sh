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

set -uo pipefail

project=""
from=""
min_pi_version=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project)         project="$2"; shift 2 ;;
    --from)            from="$2"; shift 2 ;;
    --min-pi-version)  min_pi_version="$2"; shift 2 ;;
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

# Accept current >= min via `sort -V`. The smallest of the two should
# be the minimum; if the current value sorts below the minimum, refuse.
lowest="$(printf '%s\n%s\n' "$current_pi_version" "$min_pi_version" | sort -V | head -n1)"
if [ "$lowest" != "$min_pi_version" ] && [ "$current_pi_version" != "$min_pi_version" ]; then
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
( cd "$from" && find . -type f -print0 ) | while IFS= read -r -d '' rel; do
  rel="${rel#./}"
  out="$dest/$rel"
  if [ ! -e "$out" ]; then
    mkdir -p "$(dirname "$out")"
    cp "$from/$rel" "$out"
  fi
done

exit 0
