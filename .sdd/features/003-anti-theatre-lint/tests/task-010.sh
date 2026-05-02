#!/usr/bin/env bash
# AC10 — doctrine line in CLAUDE.md
set -uo pipefail
if ! grep -q "lint-no-theatre.sh" templates/CLAUDE.md; then
  echo "FAIL: doctrine line missing in templates/CLAUDE.md" >&2; exit 1
fi
echo "PASS: AC10 — doctrine line present"
