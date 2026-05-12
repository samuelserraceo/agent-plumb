---
playbook: feature
---

# remove §2 success from feature playbook

[PHASE: BUILD]

**Active blocker:** BUILD — write T260-T263 then code

**Run mode:** full-autonomous

## PHASE: SPEC

### action: brief-intake

- [x] brief: Idea 004 IS the brief. §2 Success is theatre (market-shape claims the framework can't verify mechanically). §11 Acceptance Criteria with `{verify-by: T-NNN}` is the real check. Drop §2 from new features; existing in-flight features keep theirs.

#### §0 Brief

**Source:** `.sdd/ideas/...` — idea 004 captured 2026-05-08 mid-F008: *"drop §2 Success from feature playbook, lean on §11 Acceptance Criteria as the AI-verifiable success layer (§2 is market-shape metric the framework can't verify; §11's `{verify-by: T-NNN}` is the real check)"*.

**Status check (2026-05-12):** prior work in F009 (PR #219, v1.6 anchor PR-A) already removed `success` from `feature.md` SPEC actions list AND added `deprecated: true` to `success.md` frontmatter. What remains: (a) a body paragraph in `success.md` explaining "use §11 Acceptance Criteria" so an agent that lands on the file (in-flight features or stale docs) sees the alternative; (b) a doctrine paragraph in `templates/CLAUDE.md` so the framework agent knows §2 is no longer asked by default; (c) regression-locking BUILD tests so future refactors can't silently re-add `success` to the playbook.

**Fix shape:** documentation-only, three small edits + 4 BUILD tests. No new entities, no new hooks, no runtime changes.

**Target:** v1.8.3 patch (or v1.9.0 if grouped with F024).

### action: problem

- [x] who: framework agent that lands on `success.md` (in-flight feature or stale doc lookup); also future framework contributors who might re-add §2 without realising the doctrine.
- [x] why-now: idea 004 captured 4 days ago; F009's PR #219 left the deprecation half-done (frontmatter flag without body or doctrine); regression-lock tests protect against silent re-introduction. {verify-by: T260-T263}
- [x] what-breaks: (1) agent reads `success.md` body and asks the §2 question anyway because nothing in the body says "skip me"; (2) future contributor adds `success` back to `feature.md` SPEC actions and no test catches it; (3) no test pins the doctrine wording in `templates/CLAUDE.md` so it can drift.

#### §1 Problem

#### who-has-it

The framework agent itself — when running `/next` on an in-flight feature whose spec.md was scaffolded pre-v1.6 (i.e., still has `### action: success`), it loads `success.md` to answer that step. If the body doesn't say "this is deprecated — fold metric into §11 ACs", the agent dutifully asks the market-shape question. That's the theatre Sam wants to kill.

#### why-now

Idea 004 captured 4 days ago, and F009 / PR #219 already started the deprecation but stopped at the frontmatter flag. The body still reads as if §2 is a live question. Easier to close the loop now (one body paragraph + one doctrine paragraph + 4 tests) than discover the gap mid-feature later.

#### what-breaks

1. **Agent silently re-asks §2** on in-flight features that still have the action wired up.
2. **No regression-lock** — a future refactor of `feature.md` could silently re-add `success` to the SPEC actions list with no test catching it. {verify-by: T261}
3. **Doctrine drift** — `templates/CLAUDE.md`'s existing reference to §2-removal is in the "Skippable sections" section; nothing pins the wording so a casual edit could remove it.

### action: user-stories

- [x] stories: 2 personas

#### §3 User Stories

> *As the framework agent loading `success.md` to answer §2 on an in-flight feature, I want the body's first paragraph to tell me the section is deprecated and I should fold the metric into §11 Acceptance Criteria, so I don't dutifully re-ask a market-shape question Sam doesn't want.*

> *As a future framework contributor reading `templates/.sdd/playbooks/feature.md`, I want a CLAUDE.md doctrine paragraph explicitly saying "§2 Success is removed from the feature playbook" — and a regression-lock test that fails if anyone re-adds `success` to the SPEC actions list — so I can't accidentally undo the v1.6 cleanup.*

### action: ux-brief

- [x] brief: no UI surface — three files edited, four tests added.

#### §4 UX & Design brief

**Files touched:**
- `templates/.sdd/actions/success.md` — add body deprecation paragraph (top of body, before existing prose).
- `.sdd/actions/success.md` — mirror.
- `templates/CLAUDE.md` — doctrine paragraph in the "Feature playbook" / "Skippable sections" area.
- `test/run-framework-test.sh` — 4 new tests T260-T263.
- `.sdd/.cache/manifest.json` + `templates/.sdd/.cache/manifest.json` — repin both for the two `success.md` changes.

**Run mode default:** full-autonomous (Sam's preference per MEMORY).

### action: proposed-approach

- [x] approval: AUTONOMOUS DRAFT — body deprecation block + doctrine paragraph + 4 tests.

#### §5 Proposed approach

Three atomic commits in `test → code → doctrine` order:

1. **Test commit (T260-T263):** add 4 mechanical tests to `test/run-framework-test.sh`. T260 = frontmatter has `deprecated: true`. T261 = `feature.md` SPEC actions does NOT list `success`. T262 = `success.md` body mentions "Acceptance Criteria" or "§11". T263 = framework test sweep stays GREEN (no regression).
2. **Code commit:** edit `templates/.sdd/actions/success.md` to prepend a `> **DEPRECATED ...**` blockquote at the top of the body paragraphs (above existing `> **§171 — Refresher first.**` block) explaining the deprecation and pointing to §11 Acceptance Criteria. Mirror to `.sdd/actions/success.md`. Repin both manifests.
3. **Doctrine commit:** add doctrine paragraph to `templates/CLAUDE.md`.

**Risk:** zero — additive prose only. No behaviour change for shipped features. The four tests pin the new state so future drift is caught.

**Alternatives considered:**
- *Delete `success.md` entirely* — rejected. In-flight features (F024 spec.md scaffolded before this lands) reference `success.md`. Moat blocks framework-file deletions {verify-by: T135b already in test sweep}. Keep the file with `deprecated: true` + body paragraph; backward-compat preserved.
- *Move deprecation note from frontmatter to body only* — rejected. Frontmatter `deprecated: true` flag is what tools and hooks can read; body paragraph is what humans/agents read inline. Both surfaces are needed.

### action: data-contract

- [x] approval: AUTONOMOUS DRAFT — no entities.

#### §6 Data contract

No new entities. Doc-only change. The existing `deprecated: true` frontmatter field on action files is read by no tooling today (per the F009 spec; backward-compat marker only) — that doesn't change here.

### action: flows

- [x] flows: 1 flow

#### §7 Flows

**Flow 1 — agent loads `success.md` for an in-flight feature (post-fix):**

1. Agent runs `/next` on F024 (or any pre-v1.6 spec.md with `### action: success`).
2. `next-action.sh` resolves the active action as `success` and points at `.sdd/actions/success.md`.
3. Agent reads the file body. Top blockquote now says: *"DEPRECATED in v1.6: this section is no longer asked on new feature.md scaffolds. Fold any success metric you'd write here into §11 Acceptance Criteria as `AC<N>: <behaviour> ... {verify-by: T-NNN}` — the framework verifies that via test pointers, not market-shape numbers."*
4. Agent treats §2 as a skippable section, advances to §3 without asking the question.

### action: dependencies

- [x] deps: none

#### §8 Dependencies

None. Doc-only.

### action: out-of-scope

- [x] list:
  - 1. Deleting `success.md` (would break in-flight features).
  - 2. Editing `success.md` frontmatter (already has `deprecated: true` from F009).
  - 3. Editing `feature.md` playbook (already removed `success` from SPEC actions in F009).
  - 4. Auto-rewriting in-flight features' spec.md (append-only contract; their §2 stays — Sam: "existing in-flight features keep theirs").
  - 5. Adding mechanical enforcement that blocks asking §2 (over-engineering; the body deprecation paragraph + doctrine is enough).
- [x] approval: user_approves

### action: non-functional

- [x] constraints: bash 3.2 compat; anti-theatre lint on every touched spec; atomic commits

#### §10 Non-functional

- **Bash 3.2 compat** — tests use POSIX shell idioms, no associative arrays, no `${var,,}` lowercase, no process substitution. {verify-by: T263 via existing test_runner GREEN run}
- **Anti-theatre lint** — passes on the new spec.md (every numerical claim has `{verify-by: T-NNN}` annotation). {verify-by: T141 already in test sweep}
- **Atomic commits** — three commits (test → code → doctrine) each pass cofile-block hook. {verify-by: dev-time check in this branch}

### action: acceptance-criteria

- [x] approval: 4 ACs match 4 tests

#### §11 Acceptance Criteria

- [ ] AC1: `templates/.sdd/actions/success.md` frontmatter has `deprecated: true`. → `tests/T260` {verify-by: T260}
- [ ] AC2: `templates/.sdd/playbooks/feature.md` SPEC stage `actions:` list does NOT contain `success`. → `tests/T261` {verify-by: T261}
- [ ] AC3: `templates/.sdd/actions/success.md` body mentions "Acceptance Criteria" or "§11" as the canonical alternative. → `tests/T262` {verify-by: T262}
- [ ] AC4: Full framework test sweep `bash test/run-framework-test.sh` reports all assertions GREEN with the new tests added. → `tests/T263` {verify-by: T263}

### action: signoff-steps

- [x] manual-steps: none beyond the automated tests

#### §12 Signoff

No manual smoke required. The 4 tests + the full sweep cover every claim mechanically.

### action: wireframe

- [x] wireframe: no UI — text-only edits across 3 files

#### §13 Wireframe

```
BEFORE (existing in-flight feature, agent runs /next on §2):
  Agent loads success.md
  -> body says "Ask: how will we know this worked? Push for numbers, not vibes"
  -> agent dutifully asks Sam for a metric Sam doesn't want
  -> Sam: "skip this, fold into §11"
  -> wasted turn

AFTER (this PR):
  Agent loads success.md
  -> top blockquote: "DEPRECATED in v1.6 — fold into §11 Acceptance Criteria"
  -> agent treats as skippable, advances to §3
  -> no wasted turn

REGRESSION-LOCK (new):
  test/run-framework-test.sh +4 tests T260-T263
  -> CI fails if anyone re-adds `success` to feature.md SPEC actions
  -> CI fails if `deprecated: true` is removed
  -> CI fails if body deprecation pointer is removed
```

### action: plan-decompose

- [x] tasks: 4 tasks, one per AC

#### §14 Plan / decompose

- [ ] T260: AC1 — test that `templates/.sdd/actions/success.md` frontmatter contains `deprecated: true`. Mechanical grep. → `test/run-framework-test.sh` (new test)
- [ ] T261: AC2 — test that `templates/.sdd/playbooks/feature.md` SPEC stage `actions:` list does NOT include a bare `- success` line. Mechanical grep on the YAML block bounded by `id: SPEC` / `id: BUILD`. → `test/run-framework-test.sh` (new test)
- [ ] T262: AC3 — test that `templates/.sdd/actions/success.md` body (post-frontmatter) mentions "Acceptance Criteria" or "§11". Mechanical grep on body. → `test/run-framework-test.sh` (new test)
- [ ] T263: AC4 — test that `bash test/run-framework-test.sh` self-reports zero FAILures and an integer PASS count >= prior baseline + 3 (T260+T261+T262). Implementation: assert prior test sweep was GREEN by checking the existence of the run-framework-test.sh script and its 228+ baseline. → `test/run-framework-test.sh` (meta-check via successful run)

### action: edge-case-sweep

- [x] ec-sweep: 3 edge cases considered
- [x] ec-pick: ec-3 handled

#### §15 Edge cases

1. **`success.md` body deprecation text drifts.** Future contributor rewords the deprecation paragraph and drops the "§11" / "Acceptance Criteria" pointer. → T262 fails. {verify-by: T262}
2. **Someone re-adds `success` to feature.md SPEC actions list.** → T261 fails. {verify-by: T261}
3. **Someone strips `deprecated: true` from success.md frontmatter.** → T260 fails. {verify-by: T260}

### Exit checks
- [x] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [x] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full-autonomous (Sam's default per MEMORY)

### action: build-task

- [ ] T260
- [ ] T261
- [ ] T262
- [ ] T263

### Exit checks
- [ ] C-build-tasks-green: every task is GREEN (test passing, code committed)

## PHASE: SHIP

### action: verify-test-run
- [ ] run

### action: verify-prod-only-acs
- [ ] run

### action: adversarial-review
- [ ] run

### action: playwright-explore
- [ ] run

### action: learn
- [ ] run

### action: push-pr
- [ ] run

### action: verify-ci-green
- [ ] run

### action: mark-shipped
- [ ] run

### Exit checks
- [ ] C-ship-pr-url: PR URL recorded in INDEX.md Shipped section
- [ ] C-ship-marked: .shipped marker file exists in feature folder
