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
| "Yes — full browser tests" | `Test runner: Playwright` + `Viewports: Desktop (Chromium) + iPhone-13 mobile` + `Test file pattern: .sdd/features/<id>/tests/task-*.spec.ts`. Recommends running `bash extensions/playwright/enable.sh` to install the Lego brick. |
| "Yes — lightweight" | Picks runner from project-type answer (TS → Vitest, Python → pytest, Go → built-in `testing`, etc.). Records test file pattern accordingly. |
| "No UI to test" | Same as lightweight — picks runner from language. |
| "Not deciding yet" | Skip; question can be re-answered via `/sdd-config`. |

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
