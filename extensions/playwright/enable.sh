#!/usr/bin/env bash
# enable.sh — install the Playwright extension into the current project.
#
# Idempotent — safe to re-run. If a file already exists, the script asks
# before overwriting; never destroys a user-edited file silently.

set -euo pipefail

EXT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES="$EXT_DIR/templates"
DOCS_SRC="$EXT_DIR/docs"

# Resolve the project root deterministically. CLAUDE_PROJECT_DIR is the
# canonical signal; fall back to the git toplevel; warn loudly if neither
# is available rather than silently scaffolding into a subdirectory.
resolve_project_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
    echo "$CLAUDE_PROJECT_DIR"
    return
  fi
  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    echo "$git_root"
    return
  fi
  echo "warning: not inside a git repo and CLAUDE_PROJECT_DIR not set;" \
       "scaffolding into current directory: $(pwd)" >&2
  pwd
}

PROJECT_DIR="$(resolve_project_root)"
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

# Detect whether Playwright is already a devDependency. The "next steps"
# message branches on this so re-runs (where Playwright IS installed)
# don't tell the user to install it again.
PLAYWRIGHT_INSTALLED=0
if [ -f "package.json" ] && grep -q '"@playwright/test"' package.json 2>/dev/null; then
  PLAYWRIGHT_INSTALLED=1
fi

if [ "$PLAYWRIGHT_INSTALLED" -eq 0 ] && [ -f "package.json" ]; then
  echo ""
  echo "[playwright-ext] @playwright/test not in package.json devDependencies."
  echo "[playwright-ext] Run yourself when ready:"
  echo "[playwright-ext]   npm install --save-dev @playwright/test"
  echo "[playwright-ext]   npx playwright install --with-deps"
fi

echo ""
echo "[playwright-ext] enabled."
echo ""
echo "Next steps:"
if [ "$PLAYWRIGHT_INSTALLED" -eq 0 ]; then
  echo "  1. Install the dependency (the script did NOT run this for you):"
  echo "       npm install --save-dev @playwright/test"
  echo "       npx playwright install --with-deps"
  echo ""
  echo "  2. Run the example test to verify:"
  echo "       npx playwright test"
  echo ""
  echo "  3. Read tests/example.spec.ts to see the SDD-shaped test pattern."
  echo ""
  echo "  4. Read docs/sdd-playwright.md for the full pattern guide."
  echo ""
  echo "  5. Start your first feature — the agent will scaffold task-<NN>.spec.ts"
  echo "     files at .sdd/features/<id>/tests/ following the same pattern."
else
  echo "  1. Run the example test to verify (Playwright already installed):"
  echo "       npx playwright test"
  echo ""
  echo "  2. Read tests/example.spec.ts to see the SDD-shaped test pattern."
  echo ""
  echo "  3. Read docs/sdd-playwright.md for the full pattern guide."
  echo ""
  echo "  4. Start your first feature — the agent will scaffold task-<NN>.spec.ts"
  echo "     files at .sdd/features/<id>/tests/ following the same pattern."
fi
