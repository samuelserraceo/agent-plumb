# Writing SDD-shaped Playwright tests

> Plain-English guide for non-technical readers. Every test file follows the
> same shape so the tests double as living documentation of what the feature
> actually does.

## The shape

Every Playwright test file written under SDD has these properties:

1. **One file per BUILD task.** The task line in `spec.md` names the test file:

   ```text
   - [ ] T03: form submission produces success state → .sdd/features/<id>/tests/task-003.spec.ts
   ```

2. **First line is a spec-traceability comment.** Format:

   ```typescript
   // spec: §11.AC<N>   task: T<NN>
   // What this asserts (plain English): <one-line description>
   ```

3. **One `test(...)` call per assertion the user can recognise.** The test name
   is plain English a non-technical reviewer can read:

   ✅ Good: `test("visitor signs up via email and sees the success state", ...)`

   ❌ Bad: `test("AC3", ...)`, `test("happy path", ...)`, `test("test_signup", ...)`

4. **Arrange → Act → Assert structure** with comments labelling each block.

5. **No setup/teardown the reader needs to understand.** Global setup goes in
   `playwright.config.ts`, not inline.

## Why this shape

The non-technical user (the spec author) must be able to read the tests and
confirm: "yes, that's what I asked for."

Standard developer-style tests fail this — they're written for engineers, not
for the spec author. SDD's whole point is that the spec author can validate
their own work end-to-end. The test file is part of that validation.

## The full lifecycle (BUILD per task)

The framework's BUILD doctrine:

1. **Test file exists** at the path named in the task line.
2. **Run test** → must be **RED**. (If GREEN before code, the test is wrong.)
3. **Write code.**
4. **Run test** → must be **GREEN**.
5. **Commit.** (Task line goes from `[ ]` to `[x]`.)
6. **Move to next task** per the run mode.

Universal halting rules apply: 3 RED in a row, hook block, gap in spec,
missing credentials → stop and ask the user.

## Mobile viewport coverage

The default `playwright.config.ts` ships with two projects:

- `chromium` — desktop Chrome (1280×720)
- `iPhone 13` — mobile viewport (390×844)

If §4 UX brief declares mobile-first, every BUILD task's test runs on BOTH
viewports by default. To run only one:

```bash
npx playwright test --project=chromium
npx playwright test --project="iPhone 13"
```

## Edge cases (the `edge-case-sweep` action)

When the agent runs the `edge-case-sweep` action in SPEC, it brainstorms weird
inputs that no AC covers. User picks which to add. Each picked edge case
becomes a new AC, which becomes a new BUILD task, which becomes a new test.

The example test file shows three tests:
1. Happy-path (one AC)
2. Empty input edge case (validation error)
3. Malformed input edge case (format error)

Typical shape: 1 happy-path + 2-4 edge cases per feature screen.

## What if I don't use Playwright?

The shape generalises. Replace the imports and the assertion API; everything
else (spec-traceability comment, plain-English test name, A/A/A structure)
is runner-agnostic.

For pytest:
```python
# spec: §11.AC1   task: T01
# What this asserts (plain English): visitor signs up via email and sees success.

def test_visitor_signs_up_via_email_and_sees_success_state(client):
    # Arrange
    response = client.get("/")
    # Act
    response = client.post("/signup", data={"email": "test@example.com"})
    # Assert
    assert response.status_code == 200
    assert "Thanks for signing up" in response.text
```

For Vitest:
```typescript
// spec: §11.AC1   task: T01
// What this asserts (plain English): SignupForm renders the email input.

import { render, screen } from "@testing-library/react";
import { SignupForm } from "./SignupForm";

test("SignupForm renders the email input", () => {
  render(<SignupForm />);
  expect(screen.getByPlaceholderText(/email/i)).toBeInTheDocument();
});
```

## Common mistakes the framework catches

| Mistake | What the framework does |
|---|---|
| Test written AFTER code (passes immediately) | First step is "test must be RED before code." Moat hook re-runs verify on commit. |
| Test doesn't actually exercise the feature | Mutation testing (separate tool, e.g. `stryker-mutator`) breaks the code on purpose; if all tests still pass, your tests are theatre. |
| Test file at wrong path | Task line names the path. Moat checks the file exists at that exact path. |
| `.skip` to land a fake "GREEN" | Moat re-runs the test on staged spec; `.skip` reports as skipped, not passed. Agent halts. |
| One test asserting many things | One `test(...)` per AC. If a test has 5 assertions, that's 5 ACs; edge-case-sweep surfaces this. |
