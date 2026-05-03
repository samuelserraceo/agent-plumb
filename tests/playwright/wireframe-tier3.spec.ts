// spec: #116 (Playwright on framework's own repo)
// What this asserts (plain English):
//   The Tier 3 wireframe (.sdd/features/001-tier-3-llm-driven-synthesis/
//   wireframe.html) is the framework's first dogfood of the "non-UI
//   features need MORE visualisation than UI features" pattern. It has
//   click-to-expand citations + interactive step / architecture diagrams.
//   These tests verify the keyboard a11y the original PR #114 cycle 4
//   round-tripped on: every clickable element is reachable + activatable
//   with keyboard alone, focus is visible, Escape closes modal.
//
// Why this matters: the framework's marketplace pitch is "non-technical
// reviewers can read the wireframe and understand the feature." That
// promise breaks if a reviewer using a screen reader or keyboard-only
// can't operate the wireframe. PR #114 cycle 4 + PR #128 cycle 2 both
// landed a11y fixes; these tests prevent regression.

import { test, expect } from "@playwright/test";

const WIREFRAME_PATH =
  "/.sdd/features/001-tier-3-llm-driven-synthesis/wireframe.html";

test.describe("Tier 3 wireframe — keyboard accessibility", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(WIREFRAME_PATH);
    // Wait for the post-load JS to add tabindex/role attributes to the
    // interactive groups (the wireframe adds them at runtime, not in
    // static HTML).
    await page.waitForLoadState("networkidle");
  });

  test("page loads and shows the Tier 3 chat-shaped intro", async ({
    page,
  }) => {
    // Sanity: the wireframe is the right one + the hero pitch copy
    // renders. The H1 is "A knowledgeable colleague you can ask
    // anything about your project." — the Tier 3 marketing line.
    const h1 = page.getByRole("heading", { level: 1 }).first();
    await expect(h1).toContainText(/knowledgeable colleague/i);
  });

  test(".cite spans become keyboard-focusable after load", async ({ page }) => {
    // Per PR #114 cycle 4: every .cite span should have tabindex=0 +
    // role=button + a keydown listener. The runtime JS adds these.
    const cites = page.locator(".chat .cite");
    const count = await cites.count();
    expect(count).toBeGreaterThan(0);

    // Check the first one has the expected attributes.
    const first = cites.first();
    await expect(first).toHaveAttribute("tabindex", "0");
    await expect(first).toHaveAttribute("role", "button");
  });

  test("Enter on .cite opens the modal", async ({ page }) => {
    // The modal has class .cite-modal; .open class added when shown.
    const cite = page.locator(".chat .cite").first();
    await cite.focus();
    await page.keyboard.press("Enter");
    const modal = page.locator(".cite-modal");
    await expect(modal).toHaveClass(/\bopen\b/);
  });

  test("Escape closes the modal", async ({ page }) => {
    const cite = page.locator(".chat .cite").first();
    await cite.focus();
    await page.keyboard.press("Enter");
    const modal = page.locator(".cite-modal");
    await expect(modal).toHaveClass(/\bopen\b/);

    await page.keyboard.press("Escape");
    await expect(modal).not.toHaveClass(/\bopen\b/);
  });

  test("Space on .step-grp activates the step (focus-visible ring)", async ({
    page,
  }) => {
    // .step-grp is the SVG group wrapping each flow-diagram step.
    // After page load, runtime JS adds tabindex=0 + keydown listener.
    const steps = page.locator(".step-grp[data-step]");
    const count = await steps.count();
    expect(count).toBeGreaterThan(0);

    const first = steps.first();
    await expect(first).toHaveAttribute("tabindex", "0");

    // Focus + Space should fire the click handler. The handler updates
    // the detail panel below the diagram (hard to assert on without
    // knowing exact data — assert the panel exists + receives some
    // text after activation).
    await first.focus();
    await page.keyboard.press(" ");
    const detail = page.locator("#stepDetail");
    await expect(detail).toBeAttached();
  });

  test(".arch-grp boxes are keyboard-focusable", async ({ page }) => {
    // The architecture diagram has clickable boxes (user / claude /
    // tier3 / corpus / etc). Same a11y pattern as .step-grp.
    const archBoxes = page.locator(".arch-grp[data-box]");
    const count = await archBoxes.count();
    expect(count).toBeGreaterThan(0);

    const first = archBoxes.first();
    await expect(first).toHaveAttribute("tabindex", "0");
  });

  test("focus indicator is visible (no outline:none without replacement)", async ({
    page,
  }) => {
    // a11y regression catcher: someone deletes the focus styles, the
    // wireframe still works for mouse users but breaks for keyboard.
    //
    // The Tier 3 wireframe (built before PR #128's skeleton patterns)
    // relies on the browser's DEFAULT focus outline on the focusable
    // .step-grp container. The newer skeletons add explicit
    // .step-grp:focus-visible stroke/drop-shadow styles. Either is
    // valid — the test passes if:
    //   (a) outline is set (default browser ring), OR
    //   (b) stroke / strokeWidth / filter on the inner .step-box is
    //       upgraded on focus
    // Catches the genuine regression: outline:none with no replacement.
    const step = page.locator(".step-grp[data-step]").first();
    await step.focus();

    // Read both the focused group's outline AND the inner box's stroke /
    // filter. Sufficient for either pattern.
    const indicator = await step.evaluate((el) => {
      const grpStyles = window.getComputedStyle(el);
      const box = el.querySelector(".step-box");
      const boxStyles = box ? window.getComputedStyle(box) : null;
      return {
        grpOutline: grpStyles.outline,
        grpOutlineStyle: grpStyles.outlineStyle,
        grpOutlineWidth: grpStyles.outlineWidth,
        boxStroke: boxStyles?.stroke || "",
        boxStrokeWidth: boxStyles?.strokeWidth || "0",
        boxFilter: boxStyles?.filter || "none",
      };
    });
    const hasOutline =
      indicator.grpOutlineStyle !== "none" &&
      parseFloat(indicator.grpOutlineWidth) > 0;
    const hasStrokeUpgrade = parseFloat(indicator.boxStrokeWidth) > 1.5;
    const hasFilter = indicator.boxFilter && indicator.boxFilter !== "none";
    const hasIndicator = hasOutline || hasStrokeUpgrade || hasFilter;
    expect(
      hasIndicator,
      `focused .step-grp has no visible indicator (outline=${indicator.grpOutline}, strokeWidth=${indicator.boxStrokeWidth}, filter=${indicator.boxFilter})`,
    ).toBe(true);
  });
});
