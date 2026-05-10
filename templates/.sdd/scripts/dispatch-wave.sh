#!/usr/bin/env bash
# dispatch-wave.sh — body of the WAVE-DISPATCH step in the BUILD-phase
# inner loop, invoked by /next when next-action.sh resolves a wave.
#
# v1 ships the shape-only stub: parses args, reads the spec.md, finds
# tasks marked `[WAVE: N]` in `### action: plan-decompose`, and emits
# structured JSON on stdout describing what WOULD be dispatched. Real
# subagent dispatch (Claude Code Agent tool calls with fresh contexts,
# pre-commit hook firing, partial-wave-report collation, trust-boundary
# markers, multi-model config, prompt shape) lands incrementally in
# T204-T208 — each task is a small additive change to this same file.
#
# Usage:
#   dispatch-wave.sh <wave-N> <spec-path>
#
# Args:
#   <wave-N>      positive integer matching `[WAVE: N]` markers in spec
#   <spec-path>   path to an existing spec.md
#
# Output (stdout): one-line JSON object with at least:
#   { "wave": N, "tasks": ["T200","T201", ...] }
# Future T-tasks extend the shape with `results: [...]` (per-task PASS/
# FAIL) and `dispatched_at: <iso8601>` timestamps.
#
# Exit:
#   0   wave parsed successfully (may have 0 tasks — empty wave is OK)
#   2   bad CLI args (missing args, non-positive-integer wave-N, missing
#       spec file)
#   3   lockfile present (another wave already in flight; folded EC #1)

set -uo pipefail

# ── arg parsing ───────────────────────────────────────────────────────
if [ $# -lt 2 ]; then
  echo "[dispatch-wave] usage: dispatch-wave.sh <wave-N> <spec-path>" >&2
  exit 2
fi

wave_n="$1"
spec_path="$2"

# Reject non-positive-integer wave-N (folded EC #7).
case "$wave_n" in
  ''|*[!0-9]*)
    echo "[dispatch-wave] wave-N must be a positive integer (got: $wave_n)" >&2
    exit 2
    ;;
esac
if [ "$wave_n" -le 0 ]; then
  echo "[dispatch-wave] wave-N must be > 0 (got: $wave_n)" >&2
  exit 2
fi

if [ ! -f "$spec_path" ]; then
  echo "[dispatch-wave] spec path doesn't exist: $spec_path" >&2
  exit 2
fi

# ── lockfile: concurrent wave dispatch guard (folded EC #1) ────────────
# A second `/next` while a wave is in flight would otherwise race on the
# same spec.md row. Lockfile sits next to the spec under .sdd/.wave-lock.
project_root="$(cd "$(dirname "$spec_path")"/../.. && pwd 2>/dev/null || echo)"
lockfile=""
if [ -n "$project_root" ] && [ -d "$project_root/.sdd" ]; then
  lockfile="$project_root/.sdd/.wave-lock"
fi

if [ -n "$lockfile" ] && [ -e "$lockfile" ]; then
  echo "[dispatch-wave] another wave is already in flight (lockfile at $lockfile)" >&2
  echo "[dispatch-wave] wait for it to finish, or `pause` to abandon and clear the lock" >&2
  exit 3
fi

# ── parse plan-decompose for [WAVE: N] tasks ──────────────────────────
# Mirror the regex next-action.sh uses, scoped to the
# `### action: plan-decompose` section.
tasks_json="$(python3 - "$spec_path" "$wave_n" <<'PY'
import json, re, sys

spec_path, wave_n_str = sys.argv[1], sys.argv[2]
wave_n = int(wave_n_str)

try:
    with open(spec_path, encoding="utf-8") as f:
        lines = f.read().splitlines()
except OSError as e:
    print(f"[dispatch-wave] cannot read spec: {e}", file=sys.stderr)
    sys.exit(2)

in_plan = False
tasks = []
row_re = re.compile(r'^\s*-\s*\[ \]\s+(T\d+)\s+\[WAVE:\s*(\d+)\s*\]\s*:')
for ln in lines:
    if ln.startswith("### "):
        in_plan = bool(re.match(r'^###\s+action:\s+plan-decompose\s*$', ln))
        continue
    if ln.startswith("## "):
        in_plan = False
        continue
    if not in_plan:
        continue
    m = row_re.match(ln)
    if not m:
        continue
    t_id, w = m.group(1), int(m.group(2))
    if w == wave_n:
        tasks.append(t_id)

# Always emit on stdout — empty wave is a valid no-op result (folded EC #4).
print(json.dumps({
    "wave": wave_n,
    "tasks": tasks,
    "results": [],  # populated by real dispatch in T204-T208
    "mode": "stub",  # T201 ships shape-only; flips to "dispatched" in T204
}))
PY
)"
rc=$?

if [ "$rc" -ne 0 ]; then
  exit "$rc"
fi

printf '%s\n' "$tasks_json"
exit 0
