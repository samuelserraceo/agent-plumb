#!/usr/bin/env bash
# verify-stage.sh — Run the exit checks for a phase, write verification.json.
#
# Usage:   verify-stage.sh <path/to/spec.md> <PHASE>
# Output:  Writes <dir-of-spec>/verification.json
#          Exits 0 if it produced output (regardless of pass/fail count).
#          Exits 1 on input error.
#
# Format:
#   `### Exit checks` lives inside `## PHASE: <PHASE>`.
#   Each check is a line of the form:
#     - [ ] <id>: <description> — <bash command>
#   The bash command runs with `$SECTION_FILE` set to a temp file
#   containing the active phase's body only (F26 fix — checks are scoped
#   to the active phase, not the whole spec).
#
# Determinism: checks emitted sorted by id, no timestamps, stable JSON.

set -uo pipefail

if [ $# -lt 2 ]; then
  echo '{"error":"usage: verify-stage.sh <spec.md> <PHASE>"}' >&2
  exit 1
fi

spec="$1"
target_phase="$2"

if [ ! -f "$spec" ]; then
  echo '{"error":"spec not found"}' >&2
  exit 1
fi

# NUL-byte guard: awk treats \0 as record terminator, silently dropping
# any exit-check line that contains one. The line's `— <bash cmd>`
# separator never matches and the check vanishes from output, defeating
# the moat downstream. Reject input with NUL bytes.
# Using `od -An -c` because bash strips literal \x00 from variable
# expansions, breaking the more obvious `grep -q $'\x00'` approach.
if od -An -c "$spec" 2>/dev/null | grep -q '\\0'; then
  echo '{"error":"spec contains NUL bytes"}' >&2
  exit 1
fi

# Extract the body of `## PHASE: <target_phase>` to a temp file.
# Body = lines between that heading and the next `## ` heading.
section_file=$(mktemp)
trap 'rm -f "$section_file"' EXIT

awk -v target="## PHASE: ${target_phase}" '
  $0 == target { in_phase = 1; next }
  in_phase && /^## / { exit }
  in_phase { print }
' "$spec" > "$section_file"

if [ ! -s "$section_file" ]; then
  echo "{\"error\":\"phase '$target_phase' not found or empty\"}" >&2
  exit 1
fi

# Parse `### Exit checks` block; each `- [ ] <id>: <desc> — <cmd>` line.
# Output one record per line: `<id>|<cmd>`. Sort by id for deterministic order.
checks=$(awk '
  BEGIN { in_checks = 0 }
  /^### Exit checks/ { in_checks = 1; next }
  in_checks && /^### / && !/^### Exit checks/ { in_checks = 0; next }
  in_checks && /^- \[ \] / {
    if (match($0, / — /)) {
      sep_pos = RSTART
      before = substr($0, 7, sep_pos - 7)        # "- [ ] " is 6 bytes
      cmd    = substr($0, sep_pos + RLENGTH)
      colon  = index(before, ":")
      if (colon == 0) next
      id = substr(before, 1, colon - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
      print id "\t" cmd
    }
  }
' "$section_file" | sort -t$'\t' -k1,1)

# Run each check; collect results.
results_file=$(mktemp)
trap 'rm -f "$section_file" "$results_file"' EXIT

if [ -n "$checks" ]; then
  while IFS=$'\t' read -r id cmd; do
    [ -z "$id" ] && continue
    if SECTION_FILE="$section_file" bash -c "$cmd" >/dev/null 2>&1; then
      result="pass"
    else
      result="fail"
    fi
    printf '%s\t%s\n' "$id" "$result" >> "$results_file"
  done <<< "$checks"
fi

# Build verification.json.
out_dir=$(dirname "$spec")
out_path="$out_dir/verification.json"

{
  printf '{\n'
  printf '  "phase": "%s",\n' "$target_phase"
  printf '  "checks": [\n'
  if [ -s "$results_file" ]; then
    n_lines=$(wc -l < "$results_file" | tr -d ' ')
    i=0
    while IFS=$'\t' read -r id result; do
      i=$((i+1))
      if [ "$i" -eq "$n_lines" ]; then
        printf '    {"id": "%s", "result": "%s"}\n' "$id" "$result"
      else
        printf '    {"id": "%s", "result": "%s"},\n' "$id" "$result"
      fi
    done < "$results_file"
  fi
  printf '  ]\n'
  printf '}\n'
} > "$out_path"

exit 0
