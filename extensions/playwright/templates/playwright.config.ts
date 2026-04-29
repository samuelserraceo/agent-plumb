// Playwright config scaffolded by the SDD Playwright extension.
//
// What this gives you out of the box:
// - Desktop Chromium tests (the default)
// - iPhone-13 mobile-viewport tests (per CLAUDE.md plan-decompose
//   coverage rule: "when §4 declares mobile-first, the project's test
//   runner config should register a mobile viewport project alongside
//   the desktop project")
// - HTML reporter locally; GitHub-friendly reporter on CI
// - Test files at `tests/**/*.spec.ts` (per-feature) and
//   `.sdd/features/<id>/tests/task-*.spec.ts` (per-BUILD-task — SDD shape)

import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: ".",
  testMatch: [
    "tests/**/*.spec.ts",
    ".sdd/features/*/tests/task-*.spec.ts",
  ],

  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: process.env.GITHUB_ACTIONS ? "github" : "html",

  use: {
    baseURL: process.env.BASE_URL || "http://localhost:3000",
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
