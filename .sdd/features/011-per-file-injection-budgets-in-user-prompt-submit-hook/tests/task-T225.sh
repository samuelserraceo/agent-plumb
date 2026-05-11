#!/usr/bin/env bash
# T225 — AC6 — .sdd/data-model.md contains an InjectionBudget entity
# entry describing parameters.injection block + its two fields +
# its read-side caller.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DM="$FRAMEWORK_ROOT/.sdd/data-model.md"

if [ ! -f "$DM" ]; then
  echo "FAIL: T225 — data-model.md missing at $DM"
  exit 1
fi

fails=()

# Heading present.
if ! grep -qE '^### InjectionBudget' "$DM"; then
  fails+=("missing '### InjectionBudget' heading")
fi

# Both fields named in the entity body.
for needle in "cap_total_chars" "per_file_budget_chars" "user-prompt-submit.sh" "config.md"; do
  if ! grep -qF -- "$needle" "$DM"; then
    fails+=("entity body must mention '$needle'")
  fi
done

# Relationship row added.
if ! grep -qE '^- \*\*InjectionBudget → Hook' "$DM"; then
  fails+=("missing 'InjectionBudget → Hook' relationship row")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T225 — AC6 data-model.md entity violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T225 — AC6 InjectionBudget entity entry + relationship row present in data-model.md"
