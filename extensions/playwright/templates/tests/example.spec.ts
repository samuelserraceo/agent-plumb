// spec: §11.AC1   task: T01
// What this asserts (plain English): a brand-new visitor lands on /,
// types an email, hits Submit, and sees the success state.
//
// This is the SDD-shaped Playwright test pattern. Every test file:
// - Starts with a one-line spec/task comment (above) so the test ties
//   back to the AC it proves.
// - One `test(...)` call per acceptance criterion. The string is the
//   one-line plain-English description a non-technical reviewer can
//   read in 5 seconds.
// - Arrange → Act → Assert structure with comment headers.
// - No setup/teardown logic that the reader needs to understand to
//   know what's being tested.

import { test, expect } from "@playwright/test";

test("visitor signs up via email and sees the success state", async ({ page }) => {
  // Arrange — load the screen
  await page.goto("/");

  // Act — what the user does
  await page.fill("input[name=email]", "test@example.com");
  await page.click("button[type=submit]");

  // Assert — what the user sees
  await expect(page.getByText("Thanks for signing up")).toBeVisible();
});

// Edge cases — one test per edge case from §11 ACs or edge-case-sweep output.

test("submitting an empty email shows the validation error", async ({ page }) => {
  await page.goto("/");
  await page.click("button[type=submit]");
  await expect(page.getByText(/email.*required/i)).toBeVisible();
});

test("submitting a malformed email shows the format error", async ({ page }) => {
  await page.goto("/");
  await page.fill("input[name=email]", "not-an-email");
  await page.click("button[type=submit]");
  await expect(page.getByText(/valid email/i)).toBeVisible();
});
