#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC9 — doctrine line in CLAUDE.md
# templates/CLAUDE.md is the canonical version that downstream projects copy
# via init.sh. The framework's root CLAUDE.md is session-local + untracked.
# The doctrine line lands in the tracked + published one.
set -euo pipefail
if grep -q "lint-action-prose.sh" templates/CLAUDE.md; then
  echo "PASS: AC9 — doctrine line present in templates/CLAUDE.md"
else
  echo "FAIL: templates/CLAUDE.md missing lint-action-prose.sh reference" >&2
  exit 1
fi
