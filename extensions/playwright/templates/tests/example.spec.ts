// spec: §11.AC<N>   task: T<NN>
// What this asserts (plain English): <one-line description>
//
// THIS IS A TEMPLATE STARTER — it is intentionally a no-op so the file
// runs cleanly on a fresh `enable.sh` install. Replace the body with
// the actual assertions for your feature once you start writing tests.
//
// The shape below is the SDD-shaped Playwright pattern. Every test file:
// - Starts with a one-line spec/task comment (above) so the test ties
//   back to the AC it proves.
// - One `test(...)` call per acceptance criterion. The string is the
//   one-line plain-English description a non-technical reviewer can
//   read in 5 seconds.
// - Arrange → Act → Assert structure with comment headers.
// - No setup/teardown logic that the reader needs to understand to
//   know what's being tested.

import { test, expect } from "@playwright/test";

test.describe("SDD example (replace with your real test)", () => {
  // Replace this happy-path with the actual user behaviour you're asserting.
  // Keep the test name in plain English, written so a non-technical
  // reviewer can read the intent in 5 seconds.
  test("placeholder — passes by default; replace with a real assertion", async () => {
    // Arrange — set up state for the user behaviour
    // Act — what the user does
    // Assert — what the user sees
    expect(true).toBe(true);
  });

  // Edge cases — one test per edge case from the §11 ACs or the
  // edge-case-sweep action's output. Examples (replace or delete):
  //
  //   test("submitting an empty <field> shows the validation error", ...);
  //   test("submitting a malformed <field> shows the format error", ...);
  //   test("loading state appears while data is fetching", ...);
});
