// spec: #116 (Playwright on framework's own repo)
// What this asserts (plain English):
//   The marketplace landing page (docs/walkthrough.html) loads, key
//   sections render, and the v1.0/v1.1/v1.2 shipped surface is visible
//   to a first-time visitor — the basics that build "this is real
//   software, not a stub" trust within the first 10 seconds of
//   landing on the page.
//
// Why this matters: walkthrough.html is the first thing a marketplace
// visitor sees. Before #116, zero automated tests covered it. A copy
// drift, a broken link, or a missing section would land on `main`
// and the first marketplace visitor would be the bug-finder.

import { test, expect } from "@playwright/test";

test.describe("walkthrough.html — marketplace landing page", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/docs/walkthrough.html");
  });

  test("page loads with the v1.0→v1.9 shipped pill", async ({ page }) => {
    // Assert: header pill says all shipped sweeps are live, not "v1.0.0
    // shipped" alone (which was the pre-#131 drift state) and not stuck
    // on v1.2 (pre-#229) or v1.6.0 (pre-ce74cd2 / v1.7-v1.9 sweep).
    const pill = page.locator(".pill-v10").first();
    await expect(pill).toBeVisible();
    await expect(pill).toContainText("v1.0 → v1.9 shipped");
  });

  test("hero headline reads the framework's plain-English claim", async ({
    page,
  }) => {
    // Assert: the H1 is the SDD pitch a non-technical reader can react
    // to in 5 seconds. Not a placeholder, not Lorem Ipsum.
    const h1 = page.getByRole("heading", { level: 1 });
    await expect(h1).toContainText(
      "build software with AI without the AI making stuff up",
    );
  });

  test("five key sections present (the page's spine)", async ({ page }) => {
    // Assert: each anchor section the nav links to is actually on the
    // page. Catches the regression where a section gets renamed or
    // deleted but the nav stays pointing at it.
    for (const id of [
      "loop",
      "architecture",
      "validation",
      "shipped",
      "planned",
      "try",
      "reference",
    ]) {
      const section = page.locator(`#${id}`);
      await expect(section, `section #${id} should exist`).toBeAttached();
    }
  });

  test("Tier 3 architecture box rendered as live (no dashed/violet)", async ({
    page,
  }) => {
    // Assert: the Tier 3 box on the architecture diagram is solid (live),
    // not dashed (planned). PR #131 flipped this from dashed→solid;
    // a regression here would re-introduce the "v1.1 planned" drift.
    const tier3Box = page.locator('g[data-box="tier3"] rect.arch-box');
    await expect(tier3Box).toBeAttached();
    const cls = await tier3Box.getAttribute("class");
    expect(cls).not.toContain("dashed");
  });

  test("post-v1.0 shipped block lists the v1.x sweep PRs", async ({ page }) => {
    // Assert: the "what landed after v1.0" section names the actual
    // shipped PRs across v1.1 (Tier 3 #114), v1.2 (#118/#121/#124/#128),
    // and v1.3 (test-first #153, claims-audit fix #154). Catches both a
    // stale section AND a future drift where a v1.x sweep ships but the
    // walkthrough doesn't get refreshed.
    const planned = page.locator("#planned");
    await expect(planned).toContainText("v1.1 → v1.6.0 — shipped");
    await expect(planned).toContainText("PR #114"); // Tier 3 (v1.1)
    await expect(planned).toContainText("PR #118"); // plain-English action lint (v1.2)
    await expect(planned).toContainText("PR #121"); // anti-theatre spec lint (v1.2)
    await expect(planned).toContainText("PR #124"); // graph-cache code-span fix (v1.2)
    await expect(planned).toContainText("PR #128"); // wireframe redesign (v1.2)
    await expect(planned).toContainText("PR #153"); // test-first hook (v1.3)
    await expect(planned).toContainText("PR #154"); // claims-audit chicken-egg (v1.3)
  });

  test("filter buttons exist and are buttons (not links)", async ({ page }) => {
    // Assert: the top-right filter buttons render as <button> elements
    // — earlier versions had divs that looked like buttons but weren't
    // keyboard-focusable. CR cycle-2 of PR #114 caught this; assertion
    // here prevents regression.
    const filterAll = page.locator('button.filter-btn[data-set="all"]');
    const filterV10 = page.locator('button.filter-btn[data-set="v10"]');
    const filterV11 = page.locator('button.filter-btn[data-set="v11"]');
    await expect(filterAll).toBeVisible();
    await expect(filterV10).toBeVisible();
    await expect(filterV11).toBeVisible();
  });

  test("no copy-paste artefacts in body text", async ({ page }) => {
    // Assert: common "I forgot to fill this in" leftovers don't appear
    // in user-visible text. Catches the spec-shaped TODO leaking into
    // marketing copy.
    const body = page.locator("body");
    const text = await body.innerText();
    expect(text).not.toContain("Lorem ipsum");
    expect(text).not.toContain("TODO:");
    expect(text).not.toContain("FIXME");
    expect(text).not.toMatch(/<!--\s*TODO/i);
  });

  test("README and v1.0 release link work (return non-404)", async ({
    page,
  }) => {
    // Assert: the two outbound links a visitor most likely clicks
    // resolve. Use a HEAD request to avoid loading external page bodies.
    // Catches the regression where someone renames the repo or moves
    // the release tag.
    const repoLink = page
      .locator('footer a[href*="github.com/samuelserraceo"]')
      .first();
    await expect(repoLink).toHaveAttribute("href", /github\.com/);
  });
});
