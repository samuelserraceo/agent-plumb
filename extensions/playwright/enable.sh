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

# Detect whether Playwright is already a devDependency.
PLAYWRIGHT_INSTALLED=0
if [ -f "package.json" ] && grep -q '"@playwright/test"' package.json 2>/dev/null; then
  PLAYWRIGHT_INSTALLED=1
fi

# Detect package manager from lockfile presence (closes #70). Default to
# npm if no lockfile is found — most projects start there.
# Bun: v1.2+ defaults to text-based bun.lock; older versions used the
# binary bun.lockb. Detect either so both Bun generations resolve to bun.
detect_pkg_manager() {
  if [ -f "pnpm-lock.yaml" ]; then echo "pnpm"
  elif [ -f "yarn.lock" ]; then echo "yarn"
  elif [ -f "bun.lock" ] || [ -f "bun.lockb" ]; then echo "bun"
  else echo "npm"
  fi
}

# Run the install with the right package manager + run `playwright install`
# to pull the browser binaries. Returns 0 on success, non-zero on failure
# (caller falls back to manual instructions).
run_install() {
  local mgr="$1"
  echo "[playwright-ext] running install with $mgr (this may take a minute)..."
  case "$mgr" in
    npm)  npm install --save-dev @playwright/test || return $? ;;
    yarn) yarn add --dev @playwright/test || return $? ;;
    pnpm) pnpm add --save-dev @playwright/test || return $? ;;
    bun)  bun add --dev @playwright/test || return $? ;;
    *)    echo "[playwright-ext] unknown package manager: $mgr" >&2; return 1 ;;
  esac
  echo "[playwright-ext] downloading browser binaries..."
  # Use bunx for bun environments, npx for everyone else (npm/yarn/pnpm).
  local exec_cmd="npx"
  [ "$mgr" = "bun" ] && exec_cmd="bunx"
  "$exec_cmd" playwright install --with-deps || return $?
  return 0
}

if [ "$PLAYWRIGHT_INSTALLED" -eq 0 ] && [ -f "package.json" ]; then
  echo ""
  echo "[playwright-ext] @playwright/test is not yet installed."
  PKG_MGR=$(detect_pkg_manager)
  echo "[playwright-ext] Detected package manager: $PKG_MGR"
  printf "[playwright-ext] Install Playwright now? [Y/n]: "
  read -r install_answer
  if [ "$install_answer" = "" ] || [ "$install_answer" = "y" ] || [ "$install_answer" = "Y" ]; then
    if run_install "$PKG_MGR"; then
      PLAYWRIGHT_INSTALLED=1
      echo "[playwright-ext] install succeeded."
    else
      echo ""
      echo "[playwright-ext] install failed. Run manually when ready:"
      case "$PKG_MGR" in
        npm)  echo "[playwright-ext]   npm install --save-dev @playwright/test" ;;
        yarn) echo "[playwright-ext]   yarn add --dev @playwright/test" ;;
        pnpm) echo "[playwright-ext]   pnpm add --save-dev @playwright/test" ;;
        bun)  echo "[playwright-ext]   bun add --dev @playwright/test" ;;
      esac
      echo "[playwright-ext]   npx playwright install --with-deps"
    fi
  else
    echo "[playwright-ext] skipping install. Run manually when ready:"
    case "$PKG_MGR" in
      npm)  echo "[playwright-ext]   npm install --save-dev @playwright/test" ;;
      yarn) echo "[playwright-ext]   yarn add --dev @playwright/test" ;;
      pnpm) echo "[playwright-ext]   pnpm add --save-dev @playwright/test" ;;
      bun)  echo "[playwright-ext]   bun add --dev @playwright/test" ;;
    esac
    echo "[playwright-ext]   npx playwright install --with-deps"
  fi
fi

echo ""
echo "[playwright-ext] enabled."
echo ""
echo "Next steps:"
if [ "$PLAYWRIGHT_INSTALLED" -eq 0 ]; then
  echo "  1. Install Playwright (commands shown above)."
  echo "  2. Run the example test to verify: npx playwright test"
  echo "  3. Read tests/example.spec.ts to see the SDD-shaped test pattern."
  echo "  4. Read docs/sdd-playwright.md for the full pattern guide."
  echo "  5. Start your first feature — the agent will scaffold task-<NN>.spec.ts"
  echo "     files at .sdd/features/<id>/tests/ following the same pattern."
else
  echo "  1. Run the example test to verify: npx playwright test"
  echo "  2. Read tests/example.spec.ts to see the SDD-shaped test pattern."
  echo "  3. Read docs/sdd-playwright.md for the full pattern guide."
  echo "  4. Start your first feature — the agent will scaffold task-<NN>.spec.ts"
  echo "     files at .sdd/features/<id>/tests/ following the same pattern."
fi
