**Active:** features/002-plain-english-prose-sweep
**Playbook:** feature
**Active blocker:** §1 (first action: problem)
# SDD framework — INDEX


> The SDD framework dogfooding itself. Every v1.0 item below is a real GitHub issue tracked under [milestone v1.0](https://github.com/samuelserraceo/spec-driven-dev-workflow/milestone/8). When an item is in flight, it gets a `.sdd/features/<NNN>-<slug>/spec.md` walked through the SPEC → BUILD → SHIP loop.


## In flight
- features/002-plain-english-prose-sweep — plain-english prose sweep (PHASE: SPEC)

(none)

## Shipped

- **[[001-tier-3-llm-driven-synthesis]]** — v1.1 Tier 3 LLM-driven synthesis: chat-style answers over `.sdd/` corpus with cite-checked `[[…]]` citations.
  - Shipped: 2026-05-01 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/114
  - Data-model: [[entity:Tier3Config]] + [[entity:SynthesisCache]] (added)
  - Extends: (root)
  - Lesson: [[pattern:anti-theatre-is-a-layer-of-foundation-3-not-just-a-one-liner]] — every numerical / enforcement / quality claim in a spec must declare its verification path or be softened
  - First SDD-ceremony work-item the framework dogfooded on itself

## Pending production verification

After Tier 3 first-prod deploy, walk these `[PROD-ONLY]` ACs manually per §12 of the [[001-tier-3-llm-driven-synthesis]] spec:

- [ ] **AC18 (T26)** — Real-provider naturalness check. Against your live Ollama+Gemma VPS, ask one of the §3 stories' questions and confirm the answer (a) passes the cite-check mechanically and (b) reads naturally to you as a human reviewer. *Naturalness is your judgment; cite-check is mechanical.*
- [ ] **AC19 (T27)** — Real-provider rate-limit response shape matches what AC#12 mocks. Manual confirmation against actual Ollama behaviour, once.

Tick each as `[x] PROD-VERIFIED` in this list once walked. If either fails in prod, file a bug task back to BUILD.

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
