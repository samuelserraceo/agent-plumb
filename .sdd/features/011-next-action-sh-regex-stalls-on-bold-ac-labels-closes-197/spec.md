---
playbook: feature
---

# next-action.sh regex stalls on bold AC labels (closes #197)

[PHASE: BUILD]

**Active blocker:** §14 T01 (hash-section.sh bold-strip)

## PHASE: SPEC

### action: brief-intake

- [x] brief: GitHub issue #197 IS the brief. Live verification shows the next-action.sh side was already fixed by PR #227 (parallel-waves); only the hash-section.sh side remains.

#### §0 Brief

**Source:** https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/197 — *"next-action.sh regex stalls on bold AC labels — bricks SPEC at §11→§13"*

**Original fix-shape (from issue):** two parts — (1) next-action.sh regex handles bold-or-plain AC labels; (2) hash-section.sh strips `**` markers before hashing so cosmetic bold/plain edits don't break section approval.

**Live audit (2026-05-11):**
- `next-action.sh` line 220 regex already has `(?:\*\*)?` — fixed by PR #227 (sdd/010-parallel-wave-execution).
- `hash-section.sh` — NOT fixed. Hashing the same content with and without `**` markers produces DIFFERENT SHA-256s. Cosmetic bold/plain edits trip the section-approval moat even though they are semantically identical.

This feature narrows #197's scope to the remaining piece: hash-section.sh bold-strip normalisation.

### action: problem

- [x] who: framework users editing AC label cosmetics post-approval (bold vs plain) and tripping the section-approval moat
- [x] why-now: F09 + F010 ships logged 4 cosmetic re-approval ceremonies; same shape recurs on any bytes-change-no-semantic-change edit
- [x] what-breaks: hash-section.sh treats `- [ ] **AC1:** ...` and `- [ ] AC1: ...` as different sections; the moat fires on cosmetic edits; recovery is a manual `/re-approve N` + audit-trail entry per drift {verify-by: T-001}

#### §1 Problem

#### who-has-it

Framework users (Sam et al.) who add or remove `**bold**` markers around `AC<N>:` / `T<N>:` / `C-<slug>:` labels in spec.md AFTER the section was approved + hash-locked. The most common path: agent writes the section with plain `AC1:` per the action prose example, user later edits the rendered version to `**AC1:**` for readability, the section-approval moat sees the bytes diverged.

#### why-now

F009 had 4 cosmetic re-approval ceremonies (§5, §7, §12, §14). F010 surfaced #197 as a v1.7 candidate. Both ships are now in main; the next user to bold an AC label hits the same trap.

#### what-breaks

3 concrete failure modes {verify-by: T-001}:

1. **Moat surfaces a section-modified-since-approval error** with the `/re-approve` recovery path.
2. **Recovery is a re-approval ceremony** — running `reapprove.sh` + adding a decisions.md audit entry — for a purely-cosmetic edit.
3. **Audit trail bloat** — repeating cosmetic-fix entries dilute the log's signal (real decisions vs whitespace fixes).

### action: success [SKIPPED]

- ⏭ metric: skipped — out of scope (v1.6 PR-A removed success from feature playbook)

### action: user-stories

- [x] stories: 2 personas — Sam-shape (bolding AC labels post-approval), framework-tester (writing fixtures with mixed bold/plain)

#### §3 User Stories

#### Story 1 — Sam-shape user editing AC label cosmetics

> *As a user editing spec.md to add `**bold**` markers around AC labels for readability, I want the section's hash to stay stable so I don't trip the moat with a re-approval ceremony for a no-semantic-change edit.*

#### Story 2 — Framework-tester writing mixed-bold fixtures

> *As someone writing framework tests that scaffold a spec.md with bold AC labels, I want the resulting hash to match the same content with plain labels, so I can prove the normalisation works without writing two parallel fixtures.*

### action: ux-brief

- [x] brief: no UI surface; hash-section.sh stderr behaviour unchanged; success is "the moat does NOT fire on a cosmetic bold/plain edit"

#### §4 UX & Design brief

**Primary surface:** the framework moat's pre-commit error message — what the user does NOT see anymore. Before fix: moat surfaces section-modified-since-approval. After fix: no message; commit lands cleanly. {verify-by: T-001}

### action: proposed-approach

- [x] approach: minimum-diff edit to hash-section.sh normalisation — strip `**` markers around AC/T/C-style labels before hashing

#### §5 Proposed approach

**Approach (chosen): minimum-diff regex strip in hash-section.sh's normalisation pass.**

`hash-section.sh` already normalises section content (CRLF to LF, strip BOM, trailing whitespace per line). Add one more pre-hash transform: strip `**` markers around list-item labels matching `(AC\d+|T\d+|C-[a-z0-9_-]+)` so `- [ ] **AC1:** foo` and `- [ ] AC1: foo` hash identically.

**Risk register:**
- **Over-strip risk** — what if a user uses `**` for emphasis elsewhere in the section? Mitigation: scope the strip to LIST-ITEM LABELS matching the AC/T/C- pattern. Other `**` markers in prose stay intact. {verify-by: T-002}
- **False-negative risk** — what if the user uses `__bold__` syntax? Mitigation: out-of-scope (CommonMark `__` is unusual in this codebase).

**Alternatives considered + rejected:**
1. **Strip ALL `**` markers from the section before hashing.** Rejected: too aggressive; would change hashes for any prose-emphasis use of bold.
2. **Document the cosmetic-fix path as a known cost.** Rejected: that is what F009/F010 did and it bloats decisions.md; mechanical fix is cleaner.

**Status:** AUTONOMOUS DRAFT.

### action: data-contract

- [x] approval: no new entities

#### §6 Data contract

No new entities. Pure behavioural change to `hash-section.sh`'s normalisation pass.

### action: flows

- [x] flows: 1 flow — user bolds an AC label post-approval, commit succeeds (no moat fire)

#### §7 Flows

```text
User: edits spec.md, adds **bold** around AC1: prefix
User: git commit
Hook (moat): hash-section.sh runs against the staged section
  -> new bold-strip normalisation removes ** around AC1: label
  -> resulting normalised text matches the approved hash
Hook: section hash MATCHES approved_sections.acceptance-criteria -> allow
Git: commit succeeds; no re-approval ceremony needed
```

### action: dependencies

- [x] deps: zero new deps

### action: out-of-scope

- [x] list: 3 explicit deferrals
- [x] approval: AUTONOMOUS DRAFT

#### §9 Out-of-scope

3 explicit deferrals:

1. **Other markdown emphasis (`__bold__` / `_italic_`).** CommonMark supports `__bold__` but the framework's prose uses `**` exclusively. If `__` shows up in real spec.md content, file a follow-up.
2. **Stripping `**` from arbitrary prose** (not just AC labels). Too aggressive; would break sections with intentional `**` emphasis.
3. **Retroactive hash recomputation for already-approved sections.** Existing approved hashes stay; the fix applies forward.

### action: non-functional

- [x] constraints: no perf/security/compliance impact

### action: acceptance-criteria

- [x] approval: 3 ACs

#### §11 Acceptance criteria

- [ ] AC1: hash-section.sh produces the SAME hash for `- [ ] **AC1:** foo` and `- [ ] AC1: foo` within the same section context {verify-by: T-001} — `tests/task-001.sh` hashes both forms and asserts equality
- [ ] AC2: the `**` strip is scoped to LIST-ITEM LABELS matching `(AC\d+|T\d+|C-[a-z0-9_-]+)` — prose with `**Note:**` or `**TODO:**` inside the section is NOT stripped (those `**` markers stay in the hash input) {verify-by: T-002} — `tests/task-002.sh` hashes a section with prose-emphasis `**` and asserts edits to prose `**` still change the hash
- [ ] AC3: the new normalisation does NOT change hashes for sections with no `**` markers at all (regression-lock for existing approved sections) {verify-by: T-003} — `tests/task-003.sh` hashes a plain-label section pre-fix and post-fix and asserts equality

### action: signoff-steps

- [x] manual-steps: 2 manual smokes

#### §12 Sign-off

1. Take an existing approved section with plain `AC1:` labels, edit it to add `**bold**`, attempt commit — verify the moat does NOT fire (the commit lands cleanly). {verify-by: T-001 — AC1 is the automated equivalent}
2. `bash test/run-claims-audit.sh` passes — should be no change to claim count (the new claim is not added in this PR).

### action: wireframe [SKIPPED]

- ⏭ wireframe: skipped — backend hook change, no UI

### action: plan-decompose

- [x] tasks: 3 tasks T01-T03 mapped 1:1 to AC1-AC3

#### §14 Plan-Decompose

- [x] T01: Add bold-strip normalisation to hash-section.sh for AC/T/C- list-item labels — touches: templates/.sdd/scripts/hash-section.sh + manifests (×2). Test: tests/task-001.sh GREEN. AC1 mapped.
- [x] T02: Verify prose-emphasis `**` stays in the hash input (only LIST-ITEM AC/T/C- labels stripped) — test-only. Test: tests/task-002.sh GREEN. AC2 mapped.
- [x] T03: Verify plain-label sections (no `**`) hash unchanged after the fix — test-only. Test: tests/task-003.sh GREEN. AC3 mapped.

**Status:** AUTONOMOUS DRAFT.

### action: edge-case-sweep

- [x] ec-sweep: 3 edge cases
- [x] ec-pick: AUTONOMOUS DRAFT

#### §15 Edge cases

1. EC#1 — Triple-bold `***AC1:***`. Out of scope; treated as prose.
2. EC#2 — Backtick-wrapped. Out of scope; treated as code.
3. EC#3 — Bold inside the AC body (after the colon). Out of scope; the strip targets only the LABEL prefix.

### Exit checks

- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full-autonomous

**Run mode:** full-autonomous

### action: build-task

(driven by §14 tasks T01-T03)

### exit_checks

- [ ] C-build-tasks-green: every task is GREEN — `grep -cE '^- \[x\] T[0-9]+' "$SECTION_FILE"` matches T-row count in §14
