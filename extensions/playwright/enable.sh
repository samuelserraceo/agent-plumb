#!/usr/bin/env bash
# enable.sh — install the Playwright extension into the current project.
#
# Idempotent — safe to re-run. If a file already exists, the script asks
# before overwriting; never destroys a user-edited file silently.

set -euo pipefail

EXT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES="$EXT_DIR/templates"
DOCS_SRC="$EXT_DIR/docs"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || {
  echo "[playwright-ext] cannot cd into $PROJECT_DIR" >&2
  exit 1
}

echo "[playwright-ext] installing into $PROJECT_DIR"

copy_with_confirm() {
  local src="$1" dst="$2" desc="$3"
  if [ -e "$dst" ]; then
    echo ""
    echo "[playwright-ext] $dst already exists ($desc)."
    printf "[playwright-ext] overwrite? [y/N]: "
    read -r answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
      echo "[playwright-ext] skipped: $dst"
      return
    fi
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "[playwright-ext] installed: $dst"
}

copy_with_confirm "$TEMPLATES/playwright.config.ts" "playwright.config.ts" \
  "Playwright config — desktop + iPhone-13 mobile viewport"

copy_with_confirm "$TEMPLATES/tests/example.spec.ts" "tests/example.spec.ts" \
  "sample SDD-shaped Playwright test"

copy_with_confirm "$DOCS_SRC/sdd-playwright.md" "docs/sdd-playwright.md" \
  "how to write SDD-shaped Playwright tests"

if [ -f ".sdd/stack.md" ]; then
  if grep -q "^## Testing" .sdd/stack.md; then
    echo "[playwright-ext] .sdd/stack.md already has a Testing section; not modifying"
  else
    cat >> .sdd/stack.md <<'EOF'

## Testing

- **Test runner:** Playwright
- **Test file pattern:** `.sdd/features/<id>/tests/task-*.spec.ts` (per BUILD task — matches the scaffolded Playwright config's testMatch) + `tests/<feature>.spec.ts` (optional cross-task suites at project root)
- **Viewports:** Desktop (Chromium) + iPhone-13 mobile
- **Why:** full-browser end-to-end tests with cross-browser + mobile coverage out of the box
- **Run:** `npx playwright test`
EOF
    echo "[playwright-ext] appended Testing section to .sdd/stack.md"
  fi
fi

if [ -f "package.json" ]; then
  if ! grep -q '"@playwright/test"' package.json 2>/dev/null; then
    echo ""
    echo "[playwright-ext] @playwright/test not in package.json devDependencies."
    echo "[playwright-ext] Run yourself when ready:"
    echo "[playwright-ext]   npm install --save-dev @playwright/test"
    echo "[playwright-ext]   npx playwright install --with-deps"
  fi
fi

cat <<'EOF'

[playwright-ext] enabled.

Next steps:
  1. Install the dependency (the script did NOT run this for you):
       npm install --save-dev @playwright/test
       npx playwright install --with-deps

  2. Run the example test to verify:
       npx playwright test

  3. Read tests/example.spec.ts to see the SDD-shaped test pattern.

  4. Read docs/sdd-playwright.md for the full pattern guide.

  5. Start your first feature — the agent will scaffold task-<NN>.spec.ts
     files at .sdd/features/<id>/tests/ following the same pattern.
EOF
