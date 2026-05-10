---
id: browser-tests
title: "Browser-based automated testing?"
when: start
records_in: ".sdd/stack.md"
records_at: "## Testing"
agent_infers:
  - test-runner
  - test-file-pattern
  - viewport-targets
  - playwright-extension-suggested
---

# Do you want automated tests that click through your app?

The framework's BUILD discipline writes a test for every task before any code.
The question is which tool runs those tests. For an app with a UI, browser-based
testing (something visits your page, fills in forms, clicks buttons, checks the
result) catches real-user problems. For backend code with no UI, simpler tests
suffice.

## Pick one (or describe your own)

1. **Yes — full browser tests** — something visits my app like a real user
   would, on desktop AND mobile. Catches "the button moved off-screen" /
   "the form doesn't submit on iPhone" / "the modal is broken in dark mode."
   (Recommended for any project with a UI. Tool: Playwright.)
2. **Yes — but lightweight** — unit tests on functions and components, no full
   browser. Faster to run; doesn't catch UI-level issues. (Tool: Vitest for
   TypeScript / pytest for Python / similar.)
3. **No UI to test** — backend service, CLI, script. Tests still happen, just
   on functions, not browsers. (Tool depends on language — agent picks.)
4. **Not deciding yet** — skip; ask later via `/sdd-config` once you've started
   the first feature.

Reply with the number, or describe your own.

## What the agent does with your answer

| You said | Agent writes to stack.md `## Testing` |
|---|---|
| "Yes — full browser tests" | `Test runner: Playwright` + `Viewports: Desktop (Chromium) + iPhone-13 mobile` + `Test file pattern: .sdd/features/<id>/tests/task-*.spec.ts`. Offers to run `bash extensions/playwright/enable.sh`, which attempts to install the Playwright extension and the browser binaries (you can decline, and if any step fails the script falls back to manual instructions). |
| "Yes — lightweight" | Picks runner from project-type answer (TS → Vitest, Python → pytest, Go → built-in `testing`, etc.). Records test file pattern accordingly. |
| "No UI to test" | Same as lightweight — picks runner from language. |
| "Not deciding yet" | Skip; question can be re-answered via `/sdd-config`. |

**Then, regardless of which option was picked**, the agent runs
`bash .sdd/scripts/install-ci-workflow.sh --quiet`. The script reads the
`Test runner` line just written, picks the matching CI template under
`.sdd/scripts/templates/sdd-ci-*.yml.tmpl`, and writes
`.github/workflows/sdd-ci.yml`. It self-skips on "Not deciding yet" so the
agent doesn't need to branch — re-running `/sdd-config 004-browser-tests`
later will fire it again once a runner is picked.

## What gets recorded

```markdown
## Testing

- **Test runner:** <choice>
- **Test file pattern:** <pattern matching the runner's testMatch config>
- **Viewports:** <if browser tests, list desktop + mobile viewports>
- **Why:** <one-line reason in plain English>
- **How to run:** `<command>` (e.g. `npx playwright test` / `pytest` / `npm test`)
```

## What this enables

Once the BUILD phase starts on the first feature, the agent uses this answer to:

- Scaffold test files at the right path (per the testMatch pattern)
- Use the right test framework's syntax in the SDD-shaped pattern (one file per
  task, spec-traceability comment, plain-English test name, A/A/A structure)
- Recommend running the matching extension (e.g. `extensions/playwright/`) if
  one exists for the chosen runner

## What ALSO ships immediately (closes #199)

The agent **also writes a `.github/workflows/sdd-ci.yml` file** at wizard time
(if the user picked an option that runs tests). The shipped workflow:

- Runs on every PR and push to `main`
- Installs dependencies (`pnpm install` / `pip install` / language-equivalent)
- Runs typecheck (TypeScript projects only — `tsc --noEmit`)
- Runs unit tests via the chosen runner
- Runs E2E tests if Playwright was picked
- Marks itself as a REQUIRED status check (if Sam answered the branch-protection question)

**Why this matters.** Without an auto-shipped CI workflow, BUILD's RED→GREEN
discipline only applies on the developer's machine — never on the PR. F01 of
pipelogic_v2 shipped to PR #1 with **only CodeRabbit running** because there
was no CI workflow. The framework's quality moat (mutation-verified tests,
RED before code) silently didn't carry through to merge.

The workflow lives at `.github/workflows/sdd-ci.yml` and is editable. The
agent writes a starter version that handles the common case; if the project
grows beyond it, the user customises by hand.

If the user picks **"Not deciding yet"** the agent skips writing the workflow
— but mentions in the recap that `/sdd-config 004-browser-tests` will
re-prompt and write it later.

### Workflow shape (Node/TypeScript example)

```yaml
name: sdd-ci

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm tsc --noEmit
      - run: pnpm test
      # Playwright (only if extensions/playwright/ enabled)
      - run: pnpm exec playwright install --with-deps chromium
        if: hashFiles('playwright.config.ts') != ''
      - run: pnpm exec playwright test
        if: hashFiles('playwright.config.ts') != ''
```

Stack-aware variants live at `.sdd/scripts/templates/sdd-ci-*.yml.tmpl`
(v1.5.3 ships `node.yml.tmpl` + `python.yml.tmpl`; more stacks land as
projects need them). `install-ci-workflow.sh` reads the test-runner answer
here, picks the matching template, and writes the workflow.

**Idempotency:** the script never overwrites an existing
`.github/workflows/sdd-ci.yml` unless called with `--force`. Hand-edits stick
across re-runs of the wizard.

**Adding a new stack:** drop `sdd-ci-<stack>.yml.tmpl` into
`.sdd/scripts/templates/`, then add a case branch in `install-ci-workflow.sh`
mapping the runner string to the new file.
