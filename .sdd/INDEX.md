# SDD framework — INDEX

> The SDD framework dogfooding itself. Every v1.0 item below is a real GitHub issue tracked under [milestone v1.0](https://github.com/samuelserraceo/spec-driven-dev-workflow/milestone/8). When an item is in flight, it gets a `.sdd/features/<NNN>-<slug>/spec.md` walked through the SPEC → BUILD → SHIP loop.

**Active:** _(none)_
**Playbook:** feature
**Active blocker:** _(none)_

## In flight

_(no work items in flight via SDD-managed flow yet — Phase A items 1-5 ship as ad-hoc PRs first; Phase B starts once `#74` self-host lands and `#42` worktree-aware INDEX.md follows)_

## Shipped via ad-hoc PRs (pre-self-host)

The framework's history before self-hosting. Each entry is a tagged release; full details live in `.sdd/decisions.md` and the GitHub release notes linked below.

- **v0.7.5 → v0.13.6** — 18 releases shipped via direct PRs against `main`. Tags v0.7.5 through v0.13.6, all live at https://github.com/samuelserraceo/spec-driven-dev-workflow/releases.
- **v0.13.4** — chore sweep (plain-English rewording #66 + npm install auto-run #70 + doctrine drift cleanup #73). [PR #75](https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/75).
- **v0.13.5** — adversarial-review re-run wiring (closes #65). [PR #76](https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/76).
- **v0.13.6** — five-PR feature pack (#69 / #67 / #68 / #72 / #71). [PRs #77–#82](https://github.com/samuelserraceo/spec-driven-dev-workflow/pulls?q=is%3Apr+is%3Amerged+v0.13.6+).

## Backlog (post-v1.0)

Tracked outside the v1.0 milestone — see open issues at https://github.com/samuelserraceo/spec-driven-dev-workflow/issues for current state.

- Cross-platform (Windows) support — bash-only is fine for v1.0.
- Anthropic plugin marketplace listing — after v1.0 ships and is dogfooded.
- Additional extension Lego bricks: Cypress, Vitest, pytest, Jest, Stripe-specific, Vercel-specific.
- Additional install walkthroughs (Resend, Sentry, Stripe, etc.) following the v0.13.6 CodeRabbit walkthrough pattern.
- User community surfaces (Discord, gallery, etc.) — after v1.0 ships.
- Dedicated security audit pass — separate hostile-reviewer pass on every script.
- Onboarding video / 5-min demo — once the walkthrough HTML is the canonical surface.

## How this differs from a downstream user's INDEX.md

A downstream user's `.sdd/INDEX.md` lists features they're building. This file lists the framework's OWN work items — meta, but the same shape. The framework's "features" are the issues that change `templates/`, `.github/workflows/`, `scripts/`, etc.

When the framework reads its own state via `next-action.sh`, it walks this file the same way it walks any project's INDEX.md. The framework doesn't care that the project happens to BE the framework.
