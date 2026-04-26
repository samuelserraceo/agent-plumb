#!/usr/bin/env bash
# Migration into v0.4.
# - Adds "Live state / Environments / Known live deviations / Pending production verification"
#   sections to .sdd/INDEX.md if missing. Idempotent.
# - Fixes any leftover spec.md references to current-state.md (now merged into INDEX).
#
# Run by scripts/update.sh against the project root. Must be safe to re-run.

set -euo pipefail

cd "$1"  # target project root

# 1. Append Live state block to INDEX.md if absent
if [ -f .sdd/INDEX.md ] && ! grep -q '^## Live state$' .sdd/INDEX.md; then
  cat >> .sdd/INDEX.md <<'EOF'

---

## Live state
<!-- Auto-maintained by /ship and LEARN. Captures the truth about what's running NOW,
     so a non-technical reader can answer "what does this project actually do today?"
     without reading code. -->

### Environments
- **Development (local):** `pnpm dev` → http://localhost:3001
- **Preview:** _(not yet)_
- **Production:** _(not yet)_

### Known live deviations
<!-- Things that shipped despite deviating from spec. Format:
     <feature-id> — <what deviated> — <why accepted> — <when to fix> -->

_(none)_

### Pending production verification
<!-- Acceptance criteria tagged [PROD-ONLY] that can't be verified locally — they collect
     here on /ship and must be manually walked through after first prod deploy. -->

_(none)_
EOF
  echo "    + Added Live state sections to INDEX.md"
fi

# 2. Fix leftover current-state.md references in any spec.md files
for spec in .sdd/features/*/spec.md; do
  [ -f "$spec" ] || continue
  if grep -q 'current-state.md' "$spec"; then
    sed -i.bak "s|appended to \`current-state.md\` (if used) or INDEX.md's shipped section|distilled to a one-liner in INDEX.md's Shipped section|" "$spec"
    rm -f "$spec.bak"
    echo "    + Fixed current-state.md reference in $spec"
  fi
done
