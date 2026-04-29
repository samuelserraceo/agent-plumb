# Playwright extension for SDD

> Opt-in Lego brick. Wires Playwright (full-browser end-to-end tests) into the SDD
> BUILD test-first per-task flow. Runs alongside the framework, not part of core.

## What this extension does

Drops a `playwright.config.ts` + a sample test file + a "how to write SDD tests in
Playwright" doc into your project. After it's enabled, every BUILD task per the
SDD doctrine ("test file exists at path named in the task line, RED before code,
GREEN before commit") uses Playwright as the runner.

## Why opt-in

Per the SDD design philosophy foundation 1 (simplicity over capability) and
foundation 2 (Lego bricks), the framework is test-runner-agnostic. Your project
might use Vitest, pytest, Jest, Cypress, or something else entirely. The
framework's discipline (test-first, RED→GREEN→commit, moat re-runs verify) works
with any runner.

Playwright is one Lego brick. Vitest, Cypress, pytest, etc. would each be their
own brick at `extensions/<runner>/` following the same shape. None of them are
loaded by default; you pick what fits your project.

## When to enable

- ✅ Web app with a UI (forms, buttons, navigation, anything user-clicks)
- ✅ You want desktop + mobile-viewport testing out of the box (Chromium + iPhone-13)
- ✅ You want visual regression catching (screenshot diffs)
- ❌ Backend-only project with no UI (use pytest, Vitest, or Go's testing)
- ❌ Static site / marketing page (overkill — a small visual-test setup suffices)

The default scaffold ships **Chromium + iPhone-13** projects (matches what
the SDD wireframe template's viewport-targets row asks about: desktop + mobile).
If you want Firefox / WebKit / additional devices, add them to the
`projects` array in your project's `playwright.config.ts` after enable.sh
runs — Playwright supports them natively.

## How to enable

```bash
cd <your-project-root>
bash <path-to-this-repo>/extensions/playwright/enable.sh
```

The script:
1. Creates `playwright.config.ts` at your project root (or asks before overwriting if one exists).
2. Creates `tests/example.spec.ts` showing the SDD task-NNN.spec.ts shape.
3. Creates `docs/sdd-playwright.md` explaining the test pattern.
4. Adds a `## Testing` section to your project's `.sdd/stack.md` recording the choice (only if the section doesn't already exist).
5. **Reminds you to install Playwright as a devDependency yourself** — the script does NOT modify `package.json` or run `npm install`. You run those.
6. Prints next steps.

The script is **idempotent on a per-file basis**: re-running it walks each scaffolded file and asks before overwriting anything that already exists. Files you've edited are never silently replaced.

## What gets created in your project

```text
<your-project>/
├── playwright.config.ts            ← default config: Chromium + iPhone-13 mobile viewport
├── tests/
│   └── example.spec.ts             ← placeholder test in the SDD shape
└── docs/
    └── sdd-playwright.md           ← how to write SDD-shaped Playwright tests
```

The framework's discipline does the rest:
- Each BUILD task scaffolds a test file at `.sdd/features/<id>/tests/task-*.spec.ts` (the path the Playwright config's `testMatch` glob covers)
- The agent writes the test FIRST (it must be RED before the code)
- The code follows; test goes GREEN; commit
- The moat hook re-runs the test on the staged spec to catch fakes

## SDD-shaped Playwright test pattern

> **Important:** the snippet below is **illustrative pseudocode** showing the
> pattern shape. It is NOT what the extension scaffolds. The actual file the
> extension drops at `tests/example.spec.ts` is a **no-op placeholder that
> always passes** — you replace its body when you write your first real test.

Every SDD-shaped Playwright test follows this pattern:

```typescript
// spec: §11.AC<N>  task: T<NN>
// What this asserts (plain English): <one-line description>

import { test, expect } from "@playwright/test";

test("<one-line behaviour the user can read>", async ({ page }) => {
  // Arrange — load the screen, set up state
  await page.goto("/");

  // Act — what the user does (selectors here will differ per project)
  await page.fill("input[name=email]", "test@example.com");
  await page.click("button[type=submit]");

  // Assert — what the user sees
  await expect(page.getByText("Thanks for signing up")).toBeVisible();
});
```

The first line is a comment that ties the test to the spec section + task. That's
the "spec-traceability" rule from CLAUDE.md doctrine — every test file declares
which AC it proves.

## Mobile viewport (per CLAUDE.md plan-decompose coverage rule)

The default config enables an iPhone-13 viewport project alongside the desktop
project. This satisfies the SDD rule: "when §4 declares mobile-first, the
project's test runner config should register a mobile viewport project alongside
the desktop project."

To run only desktop:
```bash
npx playwright test --project=chromium
```

To run only mobile:
```bash
npx playwright test --project="iPhone 13"
```

To run both (default):
```bash
npx playwright test
```

## What this extension does NOT do

- Doesn't install Playwright. It does not edit `package.json` and does not run
  `npm install`. It checks whether `@playwright/test` is already in your
  `package.json`; if missing, it prints the two install commands you run yourself
  (`npm install --save-dev @playwright/test` + `npx playwright install --with-deps`).
- Doesn't write your tests — the agent does that as part of BUILD per task.
- Doesn't run on CI — you wire that in via `.github/workflows/` or your CI of
  choice. The extension's `playwright.config.ts` is CI-friendly out of the box
  (uses `--reporter=html` for local, `--reporter=github` for CI when
  `GITHUB_ACTIONS` env is set).
- Doesn't handle test data setup / teardown — that's project-specific. The
  example.spec.ts shows the simplest "stateless" pattern; you adapt for your
  data shape.

## Disable

To remove the extension:
```bash
bash <path-to-this-repo>/extensions/playwright/disable.sh
```

(Asks before deleting any of the files it created. Won't touch tests you wrote.)
