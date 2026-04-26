#!/usr/bin/env bash
# Migration into v0.7.
# - Ensures .sdd/ideas/ directory exists (for /idea command).
# - rubric-bug.md and rubric-idea.md are copied by update.sh's normal rubric*.md loop.
# - bug.md and idea.md slash commands copied by update.sh's normal commands/ loop.

set -euo pipefail

cd "$1"

mkdir -p .sdd/ideas
[ ! -f .sdd/ideas/.gitkeep ] && touch .sdd/ideas/.gitkeep && echo "    + Created .sdd/ideas/"
