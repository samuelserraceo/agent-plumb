// Playwright config — framework dogfoods its own Playwright extension.
//
// Closes #116. The framework BUILT extensions/playwright/ for downstream
// users; this config + the tests/ tree at root + the .github/workflows/
// playwright.yml CI job make the framework run those same checks on its
// own walkthrough HTML and feature wireframes. Cobbler stops being a
// shoe-less cobbler.
//
// What this gives you:
// - Desktop Chromium project
// - iPhone-13 mobile-viewport project (catches mobile breakage on every PR)
// - Auto-started static HTTP server on http://localhost:8765 so tests
//   can `page.goto("/docs/walkthrough.html")` etc. without dealing with
//   file:// quirks (some Playwright assertions misbehave on file://).
// - HTML reporter locally; GitHub-friendly reporter on CI
// - Test files at `tests/playwright/**/*.spec.ts`. Per-feature
//   `.sdd/features/<id>/tests/task-*.spec.ts` is also matched, mirroring
//   the SDD shape.

import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: ".",
  testMatch: [
    "tests/playwright/**/*.spec.ts",
    ".sdd/features/*/tests/task-*.spec.ts",
  ],

  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: process.env.GITHUB_ACTIONS ? "github" : "html",

  // Auto-start a static HTTP server rooted at the repo root, so tests
  // can navigate to /docs/walkthrough.html and /.sdd/features/.../wireframe.html.
  // Python's http.server is part of the framework's existing dep
  // surface (python3 + PyYAML are already required) — no new tool.
  webServer: {
    command: "python3 -m http.server 8765 --bind 127.0.0.1",
    url: "http://127.0.0.1:8765",
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },

  use: {
    baseURL: "http://127.0.0.1:8765",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },

  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "iPhone 13",
      use: { ...devices["iPhone 13"] },
    },
  ],
});
