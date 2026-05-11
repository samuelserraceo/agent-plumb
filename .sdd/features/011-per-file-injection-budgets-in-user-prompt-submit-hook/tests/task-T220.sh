#!/usr/bin/env bash
# T220 — AC1 — templates/.sdd/config.md contains a
# parameters.injection.per_file_budget_chars map with 6 entries
# (INDEX, spec, principles, stack, data-model, patterns) whose
# values sum to a declared total of 20000 chars.
#
# This is the config-layer contract for feature 011. The user-prompt-
# submit hook reads this map via resolve-parameters.sh; downstream
# projects override per-key in their own config.md. Without this block
# the hook can't find a budget for any file and falls back to a single
# cap — defeating the whole feature.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CFG="$FRAMEWORK_ROOT/templates/.sdd/config.md"

if [ ! -f "$CFG" ]; then
  echo "FAIL: T220 — config.md missing at $CFG"
  exit 1
fi

python3 - "$CFG" <<'PY'
import sys, re
try:
    import yaml
except ImportError:
    print("FAIL: T220 — PyYAML missing (already pulled in by other framework scripts; install via 'pip install pyyaml')")
    sys.exit(1)

path = sys.argv[1]
with open(path) as f:
    text = f.read()

m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    print("FAIL: T220 — config.md frontmatter not found")
    sys.exit(1)

fm = yaml.safe_load(m.group(1))
errs = []

inj = fm.get("parameters", {}).get("injection")
if not isinstance(inj, dict):
    errs.append("parameters.injection block missing or not a map")
else:
    cap = inj.get("cap_total_chars")
    if not isinstance(cap, int):
        errs.append(f"parameters.injection.cap_total_chars must be an integer (got: {cap!r})")
    elif cap != 16000:
        errs.append(f"parameters.injection.cap_total_chars expected 16000, got {cap}")

    budgets = inj.get("per_file_budget_chars")
    if not isinstance(budgets, dict):
        errs.append("parameters.injection.per_file_budget_chars missing or not a map")
    else:
        expected_keys = {"INDEX", "spec", "principles", "stack", "data-model", "patterns"}
        got_keys = set(budgets.keys())
        if got_keys != expected_keys:
            errs.append(f"per_file_budget_chars keys mismatch: expected {sorted(expected_keys)}, got {sorted(got_keys)}")

        for k, v in budgets.items():
            if not isinstance(v, int) or v <= 0:
                errs.append(f"per_file_budget_chars.{k} must be a positive integer (got: {v!r})")

        total = sum(v for v in budgets.values() if isinstance(v, int))
        if total != 20000:
            errs.append(f"per_file_budget_chars values must sum to 20000 (got: {total})")

if errs:
    print("FAIL: T220 — AC1 config shape violations:")
    for e in errs:
        print(f"  - {e}")
    sys.exit(1)

print("PASS: T220 — AC1 config.md has parameters.injection.{cap_total_chars=16000, per_file_budget_chars={...}} summing to 20000 across 6 keys")
PY
