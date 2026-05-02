# wireframe action redesign

[PHASE: SPEC]

**Active blocker:** §15 done, phase advance next

## PHASE: SPEC

### action: problem

- [x] who: Two real personas — (1) Sam reviewing a SPEC for a non-UI feature like Tier 3 with no obvious "thing to point at", and (2) future plugin-marketplace adopters trying to understand what a backend-only feature does without reading code. {best-effort: human-judged based on 2026-05-01 Sam transcript on Tier 3 §13}
- [x] why-now: Caught dogfooding v1.1 Tier 3 SPEC §13. Sam: *"I think the whole wireframe step has to be better defined. For non-developer we need visualisations to visualise in a simple interactive way. This is super important for non-tech people, and probably one of the only docs we can look at and finally understand whether what we are building is correct."* Tier 3 already dogfooded the redesigned shape (chat examples + flow + architecture diagram) — the pattern works; now promote it to canonical.
- [x] what-breaks: Three concrete breakages.
  1. **Non-UI features get skipped entirely** — current `wireframe.md` is `[SKIPPABLE: non-UI features]`. Backend / library / CLI features need MORE visualisation than UI features, not less; non-technical readers can't infer behaviour from code.
  2. **No global / compounding view** — each feature gets its own `wireframe.html`, but `docs/walkthrough.html` is hand-built and doesn't auto-update.
  3. **UI feature wireframes stop at placeholder text** — current prose says "label components, show placeholder text, mark interactive areas" — below design-handoff level (component states, design tokens, interaction details).

Source: GitHub [#112](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/112); Sam transcript on Tier 3 §13 walk 2026-05-01; existing dogfood at `.sdd/features/001-tier-3-llm-driven-synthesis/wireframe.html`.

### action: success

- [x] metric: **Quality, single measure.** Every USER-LED / AGENT-LED feature spec walked after this ships either fills `wireframe.html` with content matching the new schema (UI screens OR non-UI flow + architecture) or skips with a stronger reason than "non-UI feature". {best-effort: human reviewer at the next 3 SHIP cycles after 005 lands}

### action: user-stories

- [x] stories: Three personas.

  **Story 1 — Sam reviews a non-UI SPEC and sees the feature.**
  *As Sam reviewing a backend-only feature SPEC, I want a visual wireframe that shows me what happens when the user does X (flow), where this sits in the broader system (architecture), and a concrete example interaction, so I can confirm the design is right BEFORE BUILD without reading code.*

  **Story 2 — Plugin-marketplace adopter understands a feature without code.**
  *As a non-technical plugin-marketplace user browsing a project's `.sdd/features/`, I want every feature's `wireframe.html` to render in my browser as a visual story (whether the feature is UI or backend), so I can decide whether to use the project without code-diving.*

  **Story 3 — Agent has a clear template for both shapes.**
  *As the SDD agent walking a wireframe action, I want two starter skeletons (UI feature; non-UI feature) referenced explicitly in the action prose, so I produce a wireframe that matches what Sam expects without needing to invent the shape from scratch each time.*

### action: ux-brief

- [x] approval: agent-drafted in autonomous mode. The action's OUTPUT is a UX artefact, but this work-item itself produces only template prose + skeletons; no UI surface in the framework code.

**Tone of the skeletons:** match `docs/walkthrough.html` and `001-tier-3-llm-driven-synthesis/wireframe.html` — Tailwind CDN inline, no build step, plain English everywhere, click-to-expand details, click handlers with keyboard accessibility (per #110 cycle 4 a11y findings).

### action: proposed-approach

- [x] approval: agent-drafted in autonomous mode under Sam's standing CRACK ON directive.

**Approach: rewrite + skeletons + drop SKIPPABLE tag. Layer B (auto-update global walkthrough) deferred to v1.3.**

**Pass 1 — Rewrite `templates/.sdd/actions/wireframe.md` action prose (Layer A).**
Drop the `[SKIPPABLE: non-UI features]` tag. Replace the prose with a branch on feature shape:
- **UI feature** → draft a clickable wireframe.html with screens, design tokens, component states, interaction details. References `templates/.sdd/skeletons/wireframe-ui.html`.
- **Non-UI feature** → draft wireframe.html with: a flow diagram (steps when the user does X), an architecture-position diagram (where this feature sits in the broader system), an example walkthrough (concrete user interaction). References `templates/.sdd/skeletons/wireframe-non-ui.html`.
- **Both shapes share** — brief feature summary at top + cross-link to the global walkthrough.

**Pass 2 — Ship two starter skeletons (Layer C).**
- `templates/.sdd/skeletons/wireframe-ui.html` — based on existing v1.0 conventions; expanded with design tokens block, component-states matrix, interaction details.
- `templates/.sdd/skeletons/wireframe-non-ui.html` — abstracted from Tier 3's `wireframe.html`: 4 sections (chat examples / flow diagram / architecture diagram / new-vs-existing).

Both skeletons ship `<!-- TODO: --->` markers per section so the agent knows what to fill in.

**Pass 3 — Layer B deferred.**
Auto-updating `docs/walkthrough.html` on every `/ship` requires knowing the structure Sam wants to preserve. The current walkthrough is hand-built and that's fine for now. Filing as v1.3 follow-up issue from this PR.

**Approach: 1 alternative considered + rejected.**
- **Alternative B — Single unified skeleton with conditional sections.** One `wireframe.html` template with `<!-- IF UI -->` / `<!-- IF NON-UI -->` markers. Rejected: ships dead code in every feature's wireframe; agent has to reason about which sections to remove rather than which to fill.

**What it looks like:** *"At wireframe action time, I read your problem and user stories. Is there a UI surface (form, page, button)? If yes, I drop the UI skeleton into wireframe.html and we iterate on screens together. If no, I drop the non-UI skeleton — flow + architecture + example interaction — and we iterate on those. Either way, there IS a wireframe; non-UI features don't get skipped."*

### action: data-contract

- [x] approval: no schema changes. Two new template files + action prose rewrite.

### action: flows

- [x] flows: One critical flow.

  **Flow A — Agent reaches wireframe action mid-SPEC.**
  ```text
  1. Agent reads the spec's §1 problem + §3 user stories
  2. Agent decides: UI feature OR non-UI feature?
  3a. UI → cp templates/.sdd/skeletons/wireframe-ui.html
       to .sdd/features/<id>/wireframe.html
  3b. Non-UI → cp templates/.sdd/skeletons/wireframe-non-ui.html
       to .sdd/features/<id>/wireframe.html
  4. Fill the section TODOs with feature-specific content
  5. Iterate with Sam until he replies "approved"
  ```

### action: dependencies

- [x] deps: **No new deps.** Existing framework dependencies cover this feature: bash + cp + markdown templates. Zero cost.

### action: out-of-scope

- [x] list: Three things explicitly NOT in scope this round.
  1. **Layer B — auto-update `docs/walkthrough.html` on `/ship`.** Requires structure decisions Sam should make. Filing as v1.3 follow-up from this PR.
  2. **Migrating the 4 already-shipped features' wireframes** to the new skeletons. Existing wireframes were Sam-audited at their own SHIP cycles; back-fixing is parked.
  3. **Visual regression testing** of the skeletons. Out of scope for v1.2; would benefit from #116 (Playwright on framework) once it ships.
- [x] approval: agent-drafted in autonomous mode.

### action: non-functional

- [x] constraints:
  - **Performance:** N/A — template files copied at /next time; no runtime performance concern.
  - **Accessibility floor:** keyboard-activatable interactive elements (Enter/Space on `.cite` / `.step-grp` etc.) — per #110 cycle 4 a11y findings. {verify-by: T08 a11y assertions on the skeletons}
  - **Browser support:** modern Chromium + Safari + Firefox. Tailwind CDN handles polyfills.

### action: acceptance-criteria

- [x] approval: agent-drafted in autonomous mode. Coverage check vs §4 N/A here (UX brief minimal).

**Group 1 — Action prose (Layer A).**

1. **AC1 — `[SKIPPABLE: non-UI features]` tag removed.** `templates/.sdd/actions/wireframe.md` no longer has that tag. → `tests/task-001.sh`

2. **AC2 — UI vs non-UI branching prose lands.** `wireframe.md` body contains the literal phrase "UI feature" AND "non-UI feature" with distinct guidance under each. → `tests/task-002.sh`

3. **AC3 — `**What it looks like:**` block lands.** Required by #110's lint; the rewritten action body must include the example block. → `tests/task-003.sh`

4. **AC4 — `lint-action-prose.sh` passes on the rewritten file.** → `tests/task-004.sh`

5. **AC5 — `lint-no-theatre.sh` passes on the rewritten file.** Eat-own-anti-theatre-dogfood. → `tests/task-005.sh`

**Group 2 — Skeletons (Layer C).**

6. **AC6 — UI skeleton exists and is well-formed HTML.** `templates/.sdd/skeletons/wireframe-ui.html` exists; opens with `<!doctype html>`; contains the 4 expected sections (screens, design tokens, component states, interaction details). → `tests/task-006.sh`

7. **AC7 — Non-UI skeleton exists and is well-formed HTML.** `templates/.sdd/skeletons/wireframe-non-ui.html` exists; opens with `<!doctype html>`; contains the 4 expected sections (chat examples, flow diagram, architecture diagram, new-vs-existing). → `tests/task-007.sh`

8. **AC8 — Both skeletons have keyboard-accessible interactive elements.** Any `.cite`, `.step-grp`, `.arch-grp` or similar interactive element has `tabindex="0"`, `role="button"`, and a keydown handler that listens for Enter/Space (per #110 cycle 4 pattern). → `tests/task-008.sh`

**Group 3 — Don't-break-existing-shape.**

9. **AC9 — Existing 4 shipped features still pass `lint-action-prose.sh` and `lint-no-theatre.sh`.** No collateral damage from the action prose rewrite. → `tests/task-009.sh`

10. **AC10 — Framework regression.** All 196/196 framework + 161/161 MCP tests still pass. → `tests/task-010.sh`

### action: signoff-steps

- [x] manual-steps: Two manual smokes Sam walks before SHIP.
  1. **Eyeball both skeletons.** Open `templates/.sdd/skeletons/wireframe-ui.html` and `wireframe-non-ui.html` in a browser. Confirm each renders cleanly and reads like a smart non-coder asked you to fill the TODOs.
  2. **Live ceremony test.** Start a throwaway feature (`/start "throwaway wireframe test"`). Walk to §13. Confirm the agent picks UI or non-UI shape, copies the right skeleton, and prompts to fill the TODOs.

### action: wireframe

- [x] wireframe: pending — `wireframe.html` for THIS feature would be ironic but redundant. The two skeletons IN `templates/.sdd/skeletons/` ARE the wireframe of this feature. Cross-linking from this spec to the skeletons covers the visualisation need.

### action: plan-decompose

- [x] tasks: 10 tasks, 1-1 with AC1-10. Run mode: full autonomous.

  - [ ] T01: rewrite `templates/.sdd/actions/wireframe.md` — drop SKIPPABLE tag, add UI vs non-UI branch
  - [ ] T02: AC2 branch-prose grep test
  - [ ] T03: AC3 `**What it looks like:**` block grep test
  - [ ] T04: `lint-action-prose.sh` passes on rewritten file
  - [ ] T05: `lint-no-theatre.sh` passes on rewritten file
  - [ ] T06: write `templates/.sdd/skeletons/wireframe-ui.html`
  - [ ] T07: write `templates/.sdd/skeletons/wireframe-non-ui.html`
  - [ ] T08: keyboard-a11y assertion on both skeletons
  - [ ] T09: don't-break-existing-shape (run both lints against the 4 shipped feature specs)
  - [ ] T10: full framework + MCP regression

### action: edge-case-sweep

- [x] ec-sweep: 3 edges considered.
  - **Hybrid features (some UI + some backend).** Action prose explicitly says "if both, ship both shapes in the same file" — sections nested under H2s.
  - **Skeletons drift from `docs/walkthrough.html` shape.** Manageable: Layer B (deferred to v1.3) will eventually unify; for now, skeletons match Tier 3's wireframe (which itself mirrors walkthrough conventions).
  - **Sync between root `.sdd/actions/wireframe.md` and `templates/.sdd/actions/wireframe.md`.** Current pattern: cp templates → root after edit. Same as #110/#111 cycles.
- [x] ec-pick: 0 edge-case ACs added; all 3 are inherited (the lints from #110/#111 already gate this — `lint-action-prose.sh` + `lint-no-theatre.sh` run on every PR per their respective T140 + T141 framework-test gates). {verify-by: T140 + T141 in `test/run-framework-test.sh`}

### Exit checks

- [x] C-spec-acs: 10 ACs in §11
- [x] C-spec-tasks: 10 tasks in plan-decompose

## PHASE: BUILD

### Build tasks (10 total · run mode: full autonomous)

- [ ] T01: rewrite wireframe.md action prose
- [ ] T02: branch-prose grep test
- [ ] T03: example block grep test
- [ ] T04: lint-action-prose.sh passes on rewritten file
- [ ] T05: lint-no-theatre.sh passes on rewritten file
- [ ] T06: UI skeleton
- [ ] T07: non-UI skeleton
- [ ] T08: a11y assertion on both skeletons
- [ ] T09: existing shipped specs don't break
- [ ] T10: framework regression

### Exit checks (BUILD)
- [ ] C-build-tasks-green: every task is GREEN

## PHASE: SHIP

### action: verify-test-run
- [ ] run: framework + MCP + 10/10 task tests passing.

### action: verify-prod-only-acs
- [ ] collect: N/A — no `[PROD-ONLY]` ACs.

### action: adversarial-review
- [ ] adversarial: CodeRabbit on the PR. Iterate until converged.

### action: playwright-explore
- ⏭ skipped — non-UI feature (template + prose changes).

### action: learn
- [ ] lessons: lesson captured in INDEX.md `## Shipped` row.

### action: push-pr
- [ ] pr: PR opened against main.

### action: verify-ci-green
- [ ] ci: all 4 GitHub Actions checks green.

### action: mark-shipped
- [ ] shipped: `.shipped` marker, INDEX.md row, decisions.md audit.

### Exit checks (SHIP)
- [ ] C-ship-pr-merged: PR merged with CI green
- [ ] C-ship-marker: `.shipped` present
- [ ] C-ship-index: INDEX.md `## Shipped` row added
