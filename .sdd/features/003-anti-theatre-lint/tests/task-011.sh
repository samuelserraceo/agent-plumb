#!/usr/bin/env bash
# AC11 — shipped specs don't crash the lint (regression detector)
set -uo pipefail
LINT=".sdd/scripts/lint-no-theatre.sh"
for spec in .sdd/features/001-tier-3-llm-driven-synthesis/spec.md \
            .sdd/features/002-plain-english-prose-sweep/spec.md; do
  out=$(bash "$LINT" "$spec" 2>&1); ec=$?
  # Exit 0 (no theatre) or 1 (theatre found) is fine — what we
  # don't want is exit 2 (script crashed) or interpreter error.
  if [ "$ec" -ne 0 ] && [ "$ec" -ne 1 ]; then
    echo "FAIL: lint crashed on $spec (ec=$ec): $out" >&2; exit 1
  fi
done
echo "PASS: AC11 — lint runs cleanly against both shipped specs"
