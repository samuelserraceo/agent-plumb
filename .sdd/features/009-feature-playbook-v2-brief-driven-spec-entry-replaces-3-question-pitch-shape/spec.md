---
playbook: feature
---

# feature playbook v2 — brief-driven SPEC entry replaces 3-question Pitch shape

[PHASE: BUILD]

**Active blocker:** §14 (BUILD: T01 brief-intake action)

## PHASE: SPEC


### action: problem

- [x] who: non-technical founders walking SPEC ceremonies on real projects
- [x] why-now: F01 audit (2026-05-08) produced 4 concrete failure modes; doctrine alone insufficient
- [x] what-breaks: 4 concrete failure modes — startup-pitch §1, redundant §2, lazy first-pass record, bundled-question turns

#### §1 Problem

#### who-has-it

Non-technical founders (Sam et al.) walking through SPEC ceremonies on real projects. Specifically anyone who hits §1's three-question Pitch shape ("who / why-now / what-breaks") on work that isn't a customer-facing startup feature — foundation features, internal tools, framework dogfooding. The friction was first observed across pipelogic_v2's F01 SPEC ceremony; same shape will hit any non-startup work.

#### why-now

The F01/pipelogic_v2 audit on 2026-05-08 produced concrete evidence — four specific failure modes captured live in the transcript (line numbers cited in #207). Sam invented the grill protocol himself mid-§2 because the framework wasn't pushing back; that's clear signal doctrine alone isn't enough and structural redesign is needed. Earlier point fixes (#173/#174 grill protocol, #110 plain-English lint, #171 refresher block) closed individual leaks but didn't address the entry shape itself. The cumulative friction is now well-evidenced enough to warrant a v1.6 anchor change.

#### what-breaks

Four things break, drawn directly from #207's *"What's wrong with the current SPEC"* section:

1. **§1 Problem is startup-pitch BS for non-startup work.** Three questions ("who / why-now / what-breaks") don't fit foundation features, internal tools, or framework dogfooding — anywhere the user already knows what they want and just needs to describe it.
2. **§2 Success metrics adds zero signal beyond §11 ACs** for foundation features. Every F01 metric ended up tagged `{best-effort: clickthrough QA}`; the same checks landed in §11 anyway. Pure ceremony noise.
3. **The agent records first-pass answers without challenge.** Even after #173/#174 shipped grill protocol, the doctrine-default still leans toward "record" over "interrogate." Sam invented the grill protocol himself mid-§2 because the framework wasn't pushing back.
4. **Bundled multi-question turns + technical-prose-first drafts** violate doctrine but fire anyway. Sam had to ASK for plain English at §5 (line 4518) and again at §11 (line 26474) of the F01 transcript.

### action: success [SKIPPED]

- ⏭ metric: skipped — out of scope — this redesign deletes §2 from the playbook (per #207 Part 2; argued in §5 proposed-approach)

#### §2 Success [SKIPPED]

**Skipped on purpose** — out of scope — this redesign deletes §2 from the playbook (per #207 Part 2; argued in §5 proposed-approach)

§2 success metrics for this very feature would be self-defeating. The feature's own §5 proposed-approach is going to argue for **deleting §2 from the feature playbook entirely** (issue #207 Part 2: *"§2 Success folded into §11 ACs"*). Filling in success metrics would create theatre: drafting a metric that the feature's own design says shouldn't exist.

Honest discipline: skip with documented reason. Verification of this redesign's success lives in §11 ACs (e.g., *"§2 success removed from feature playbook frontmatter; existing F009 spec.md is the last to use §2"*). That's the §11-as-the-source-of-truth pattern that #207 itself argues for — applied to its own SPEC ceremony as proof.

### action: user-stories

- [x] stories: 3 personas — fresh-project founder, engineer-opt-out, framework-dogfood meta-case

#### §3 User Stories

**3 personas, drawn from #207 + the F01 audit + this F009 ceremony itself:**

#### Story 1 — Non-technical founder starting a fresh project (Sam-shape)

> *As a non-technical founder pasting a brief into a fresh SDD project, I want the framework to read my brief and pre-fill the spec sections it can infer (§1 + §3-§12), so that I only answer 3-5 follow-up questions instead of ~20.*

This is the **primary persona**. Brief intake is the load-bearing UX change. If this story doesn't ship working, the v1.6 redesign hasn't shipped.

#### Story 2 — Engineer-shape user opting out of brief intake

> *As a developer who knows exactly what they want, I want to opt OUT of the brief-paste flow and use the existing 3-question Pitch shape, so that I don't have to write a full brief just to spec a small change.*

This story keeps the existing flow accessible as a fallback. Important for engineer-shape users who'd find the brief-paste step heavier than just answering "who / why-now / what-breaks." The redesign should additive, not breaking.

#### Story 3 — Framework dogfooding meta-case (proven by this very SPEC ceremony)

> *As an agent walking a framework feature where §2 doesn't apply (e.g., F009 itself), I want the framework's own SPEC to handle skip-with-reason without bypassing discipline, so that the framework eats its own dog food on the redesign it's proposing.*

Already proven in this SPEC ceremony — §2 was skipped honestly with a documented reason. This story exists in §3 because the redesign explicitly preserves the skip-with-reason discipline; it's not a new behaviour but a doctrine the redesign must not break.

**Out of scope (deliberate):** evolve-flow (`/start --extends=<id>`) — real story but #207 doesn't address it; adding here bloats v1.6 scope. File as a follow-up if the evolve case becomes friction in practice.

### action: ux-brief

- [x] brief: chat-as-UX — agent message shapes (entry / mid-section / first-draft / end-of-section recap); no visual wireframe


**Primary surface(s):** the agent's chat output. F009 changes 4 message shapes the agent prints during SPEC walkthrough — no visual UI artefact, no wireframe.

| Surface | Old shape | New shape (per #207) |
|---|---|---|
| **Entry prompt** (start of SPEC) | "Three quick questions: who / why-now / what-breaks?" | "Paste your brief, upload a doc, or use the template at `.sdd/ideas/2026-05-08-brief-template-v2.md`." |
| **Mid-section turn** | Agent bundles 2-4 sub-questions per turn | Agent asks **at most ONE** question per turn |
| **First draft (AGENT-LED)** | Engineer-shape prose; lint catches jargon retroactively | Plain-English-first; technical detail in foldable `<details>` block |
| **End-of-section recap** | None | "Here's what I just heard across §N:" + 3-bullet restate |

**Tone / voice constraints (mix of already-shipped + new):**

| Doctrine | Status |
|---|---|
| Plain English; jargon translated on first use (CLAUDE.md non-tech lens + lint #110) | shipped |
| 5-line hard cap on end-of-turn messages | shipped via #205 (v1.6 batch) |
| Approval prompts kept short (no 6-step ceremony block) — best-effort doctrine, agent self-check at every approval | shipped via #201 (v1.6 batch) |
| Free-form escape on every multi-choice question | doctrine |
| **One question per turn** | new — #207 Part 3 (this feature) |
| **Plain-English-first as DEFAULT** (not just lint-enforced) | new — #207 Part 4 (this feature) |
| **End-of-section recap** | new — #207 Part 6 (this feature) |

**Visual / device constraints — N/A.** Mobile / desktop / responsive: chat output renders in Claude Code's UI; this feature doesn't touch the harness's chrome. WCAG accessibility: inherited from Claude Code; not affected. i18n: English-only for v1.6.

**Document-upload UX (#207 Part 5):** §6 data-contract action prose explicitly invites uploads — *"drop a Google Sheets export, a schema dump, a screenshot."* Supported: markdown / CSV / JSON / plain text (clean); PDFs (spotty); screenshots (vision-capable models). Failure path: agent reports plain-English error if format unsupported.

**Wireframe.html: N/A.** The "wireframe" for an agent-chat feature is the action prose templates themselves (`templates/.sdd/actions/<slug>.md`). Updating those IS the wireframe update. The `wireframe.html` file at the feature root is a stub explaining this; per CLAUDE.md rule 5 (wireframe should reflect current state — best-effort doctrine, agent self-check), action prose changes are tracked in the `touches:` field of each downstream action, not in a separate HTML file.

### action: proposed-approach

- [x] approval: AUTONOMOUS DRAFT — sub-PR sequencing per #207; Sam to re-approve on return

#### Recommended approach: 4 sub-PRs, vertical-first, sequenced

Per issue #207, ship the redesign as 4 independently-mergeable sub-PRs. Apply the walking-skeleton primitive (#211) to v1.6 itself: PR-A is the spine; PR-B/C/D widen.

| Sub-PR | Scope | Depends on | Vertical role |
|---|---|---|---|
| **PR-A** | New `brief-intake` action + `brief-summarise` skeleton + project-bootstrap path; `feature.md` playbook frontmatter swap (`problem` -> `brief-intake` as first action) | none (depends only on existing v1.6 batch) | walking-skeleton — proves the brief-paste -> §1-§7 prefill path works end-to-end |
| **PR-B** | Delete `success` from `feature.md` stages; mark `success.md` deprecated; clickthrough-QA pattern (#172) becomes default §11 AC shape | PR-A merged | widens — removes redundant §2 |
| **PR-C** | One-question-at-a-time CLAUDE.md doctrine; audit `requires_user_approval` flags on §13/§15 (drop to false); add to lint-action-prose checks | PR-A merged (touches refresher block) | widens — turn shape |
| **PR-D** | Plain-English-first default in AGENT-LED draft prose; foldable `<details>` for technical detail; §6 data-contract upload-invitation prose | PR-A merged | widens — voice |

#### Why these 4 not 1 mega-PR

- Each PR is independently rebaseable + revertable. If PR-D regresses voice, only voice prose reverts; the brief-intake spine survives.
- CR cycles per PR are bounded — small PRs converge in 1-2 cycles each (proven across v1.5.3/v1.5.4/v1.6 batches we just shipped).
- Downstream users on Channel B (`sdd-migrate.sh`) can adopt incrementally — they could land PR-A only and defer the rest until they've internalised the new shape.

#### Alternatives considered (rejected)

**Alt 1: One mega-PR (~30 files, ~600 LOC).** Tempting because all 4 parts compose into one coherent UX. Rejected: blast radius too large; if any one part breaks downstream projects' SPEC ceremonies, the whole thing reverts. v1.5.3's CR cycle 3 (small PR) converged in 30 min; a mega-PR would likely take 3+ cycles and 3+ hours of CR latency.

**Alt 2: 4 separate features (F009-F012)**, each one full SPEC->BUILD->SHIP loop. Rejected: each feature would need its own brief, its own §1-§15, its own moat-dance. The 4 sub-PRs share so much context (#207 issue body, F009 SPEC artefacts) that splitting into 4 features creates spec-duplication. One feature with 4 sub-PRs is the right granularity.

**Alt 3: Skip the redesign entirely; close #207 as won't-fix.** Rejected: F01/pipelogic_v2 audit produced concrete evidence (line-numbered transcript hits) that the current SPEC ceremony breaks down on non-startup work. The evidence is too strong to ignore.

#### Risk summary

- **Walking-skeleton risk** — if PR-A's brief-paste path doesn't actually save SPEC time, the rest of v1.6 is unjustified. Mitigation: PR-A's §11 AC includes a measurable check ("walking through F010+ with brief-intake takes <half the turns of a 3-question Pitch start"). If PR-A fails that AC, halt and revisit before PR-B/C/D.
- **Backward-compat risk** — existing in-flight features (like F009 itself, F008 pi.dev port) were started under the old SPEC shape. Mitigation: PR-A's `brief-intake` action checks `INDEX.md ## In flight` for pre-existing features and falls back to the old `problem` action for those. Only NEW features (`/start` after PR-A merges) use brief-intake.
- **Documentation drift** — CLAUDE.md doctrine has many cross-references; PRs A/C/D all touch CLAUDE.md. Mitigation: PR-A lands the structural change; PR-C and PR-D append to CLAUDE.md without overwriting PR-A's edits.

#### What this approach explicitly is NOT
- Not a rewrite of the entire feature playbook — only the entry actions (problem -> brief-intake) and a few mid-spec voice doctrines change.
- Not a deprecation of the 3-question Pitch shape — Story 2 (engineer opt-out) keeps it accessible via a flag.
- Not a deferred-question system — the brief-paste pre-fills sections, but USER-LED steps still ask for confirmation per CLAUDE.md no-assume doctrine — best-effort agent self-check at every USER-LED entry.

**Status:** AUTONOMOUS DRAFT. Sam was away when this was committed; the user-approval step on §5 is deferred. He can `/re-approve proposed-approach` on return after reviewing this prose, or push back via `tweak <part>: <change>`.

### action: data-contract

- [x] approval: no entity changes — F009 is framework-prose-only; data-model.md marker added in §5 commit

#### §6 Data Contract

F009 introduces no new entities, fields, or schema changes. The redesign is
framework-prose-only — action files, skeletons, doctrine sections in
CLAUDE.md, and playbook frontmatter. No data-model entries are created or
modified.

A one-line marker comment was added to `.sdd/data-model.md` in the §5 commit
acknowledging this and pointing at this §6 for context.

**Status:** AUTONOMOUS DRAFT. Sam approves on return.

### action: flows

- [x] flows: 1 critical flow — agent walks SPEC with brief paste vs old 3-question Pitch

#### §7 Flows

**Flow 1 — Agent walks SPEC with brief paste (NEW, replaces 3-question Pitch flow):**

```text
User: /start <title>
Agent: "Paste your brief, upload a doc, or use the template at <path>."
User: <pastes brief OR uploads doc OR responds: "use template">
Agent: brief-summarise — "I read your brief, here is what I understood across §1, §3, §4, §6, §7, §8, §9, §10, §11, §12: ..."
User: confirms (or amends)
Agent: pre-fills the 10 sections; flags 3-5 gaps as USER-LED follow-ups (one question per turn)
User: answers each follow-up; agent applies grill protocol per #173/#174
Agent: end-of-section recap after each filled section
User: /next advances to BUILD
```

Implements **Story 1** (fresh-project founder). Story 2 (engineer opt-out) reuses the existing 3-question Pitch flow unchanged. Story 3 (framework dogfooding meta-case) is a constraint on the redesign, not a separate flow.

**Status:** AUTONOMOUS DRAFT.

### action: dependencies

- [x] deps: no external services — framework-prose-only redesign

#### §8 Dependencies

F009 depends on no external services. All changes live in `templates/.sdd/actions/`, `templates/.sdd/skeletons/`, `templates/CLAUDE.md`, and `templates/.sdd/playbooks/feature.md`. Zero pricing impact.

Internal dependencies: shipped doctrine items #110, #171, #173, #174, #201, #205. Foundation #178 (T00 bootstrap) and #211 (walking-skeleton T01) are referenced but not modified.

**Status:** AUTONOMOUS DRAFT.

### action: out-of-scope

- [x] list: 5 explicit out-of-scope items per #207 boundaries
- [x] approval: AUTONOMOUS DRAFT — Sam re-approves on return

#### §9 Out of Scope

Explicitly NOT in this redesign (filed separately or deferred):

1. **Evolve-flow `/start --extends=<id>` redesign** — real persona pain (Story 2-adjacent) but #207 doesn't address it. Filed as a follow-up if friction surfaces.
2. **Mechanical lint enforcement of one-question-per-turn** — doctrine update only this round. Lint script lands in v1.7 if doctrine alone proves insufficient (matching #211's pattern: doctrine first, mechanical later).
3. **Non-English brief intake** — i18n deferred. Brief template + skeleton stay English-only for v1.6.
4. **Live multi-modal upload (audio, video)** — only static files (markdown / CSV / JSON / PDF / screenshots). Streaming uploads deferred to v1.7+.
5. **Backward-incompatible changes to existing F-folders** — pre-v1.6 features (F001-F009) keep running on the old `problem` action. brief-intake only fires on NEW features started after PR-A merges.

**Status:** AUTONOMOUS DRAFT.

### action: non-functional

- [x] constraints: thin — framework-prose-only redesign; no perf/security/compliance impact

#### §10 Non-functional

**Performance:** brief-paste flow has the same agent-turn shape as 3-question Pitch (no extra LLM calls). brief-summarise adds 1 turn; later sections shed turns by pre-filling. Net: SPEC ceremony turn count drops substantially {best-effort: Sam at SHIP — measured against F010+ first-feature counts}.

**Security:** no new attack surface. Brief paste is plain text in the user's terminal. Document uploads are read-only by the agent; no shell execution of pasted content per CLAUDE.md trust-boundary doctrine.

**Compliance:** no PII handling changes. Briefs may contain user PII; agent treats them as `[PROJECT DATA]` per trust-boundary doctrine.

**Status:** AUTONOMOUS DRAFT.

### action: acceptance-criteria

- [x] approval: 10 ACs covering 4 sub-PRs (PR-A walking-skeleton + PR-B/C/D widening) — AUTONOMOUS DRAFT

#### §11 Acceptance Criteria

10 ACs covering the 4 sub-PRs from §5. Each AC is verifiable at SHIP time; none are "feature exists" claims.

**PR-A — brief-intake + skeleton + playbook frontmatter swap (walking-skeleton):**

- [ ] AC1: Running `/start <title>` on a NEW feature (post-PR-A) shows the brief-paste prompt instead of the 3-question Pitch shape (verifiable: grep the agent's first turn output for "Paste your brief" vs "who has this problem")
- [ ] AC2: Pasting a brief that follows the v2 template at `.sdd/ideas/2026-05-08-brief-template-v2.md` produces a brief-summarise turn within the same /next cycle (no extra round-trip)
- [ ] AC3: After brief-summarise, sections §1, §3, §6, §7, §8, §10 in `spec.md` show pre-filled prose drawn from the brief (each section has at least one verbatim quote or derived bullet); §11 + §14 stay placeholder pending the standard ceremony
- [ ] AC4: `/start <title>` on an EXISTING in-flight feature (started before PR-A merged) still walks the old `problem` action (no breakage of pre-PR-A specs)

**PR-B — delete §2 success from feature playbook:**

- [ ] AC5: `templates/.sdd/playbooks/feature.md` frontmatter no longer lists `success` in the SPEC stage's actions; `templates/.sdd/actions/success.md` carries a `deprecated: true` field with a migration note
- [ ] AC6: F009's spec.md is the LAST framework feature in `.sdd/features/` to have a `### action: success` heading; F010+ specs scaffold without one (verifiable: `grep "### action: success" .sdd/features/0??-*/spec.md` returns only F009 + earlier features)

**PR-C — one-question-at-a-time doctrine + autonomous AGENT-LED audit:**

- [ ] AC7: CLAUDE.md "Non-technical user lens" section gains a "One question per turn" subsection with the doctrine line; `lint-action-prose.sh` warns when an action's "What it looks like" example bundles 2+ questions
- [ ] AC8: §13 wireframe + §15 edge-case-sweep action frontmatters drop `requires_user_approval` from `true` to `false` (technical/mechanical, no product judgement)

**PR-D — plain-English-first default + foldable technical detail:**

- [ ] AC9: AGENT-LED actions emit plain-English first drafts wrapped in `<details>` for technical detail, AS DEFAULT (not just lint-enforced retroactively); a representative AGENT-LED action (e.g., `proposed-approach.md`) shows the new pattern in its "What it looks like" block
- [ ] AC10: `templates/.sdd/actions/data-contract.md` prose includes an explicit upload-invitation paragraph naming the supported formats (markdown / CSV / JSON / plain text / PDF / screenshots) and the failure path

**Coverage check vs §4:** §4's 4 doctrine items (one-question-per-turn, plain-English-first, end-of-section recap, document-upload UX) all map to ACs above (AC7+AC8 → one-question; AC9 → plain-English-first; end-of-section recap covered structurally by AC2's "within the same /next cycle" check; AC10 → upload UX). No §4 constraint without AC backing.

**Status:** AUTONOMOUS DRAFT. §11 is section-locked once approved; Sam re-approves on return via `/re-approve acceptance-criteria`.

### action: signoff-steps

- [x] manual-steps: 3 manual smoke tests (CLI walkthrough on F010, backward-compat on F009, lint check)

#### §12 Sign-off Steps

3 manual smoke tests Sam runs before merging the v1.6 anchor PRs:

1. **Brief-paste end-to-end on a fresh feature** — start F010 (or any new framework feature) post-PR-A merge, paste a real brief from `.sdd/ideas/2026-05-08-brief-template-v2.md`, walk through to BUILD entry. Verify §1 + §3-§12 are pre-filled with brief-derived content; only 3-5 follow-up questions asked.
2. **Backward-compat on F009 itself** — re-run /next on F009's branch (post-PR-A); verify it still walks the OLD `problem` action (not brief-intake) since F009 was started pre-PR-A.
3. **Lint check** — `bash .sdd/scripts/lint-action-prose.sh` and `bash test/run-framework-test.sh` pass on the post-PR-D state.

**Status:** AUTONOMOUS DRAFT.

### action: wireframe

- ⏭ wireframe: skipped — §4 established chat-as-UX; wireframe.html stub explains N/A

### action: wireframe [SKIPPED]

### action: plan-decompose

- [x] tasks: 12 tasks (T00 chore + 10 AC-mapped + 1 final integration)

#### §14 Plan-Decompose

**Walking-skeleton ordering applied (per #211).** F009's stack is doctrine + action prose + skeleton — only 1 architectural layer (the agent-prose layer). Walking-skeleton check: pass (single layer; T01 inherently exercises it). T00 bootstrap: skip (no runtime to scaffold; framework is shell + markdown).

Tasks 1:1 with ACs from §11, plus 1 final integration task:

- [ ] T01: Brief-intake action prose drafted (replaces problem.md as feature.md's first action) — touches: templates/.sdd/actions/brief-intake.md (NEW). Test: tests/task-001.sh (smoke — agent reading brief-intake.md sees the new prose). AC1 mapped.
- [ ] T02: brief-summarise.md skeleton written — touches: templates/.sdd/skeletons/brief-summarise.md (NEW). Test: tests/task-002.sh (skeleton renders to expected shape). AC2 mapped.
- [ ] T03: brief-intake action pre-fills §1, §3, §6, §7, §8, §10 from a sample brief — touches: brief-intake.md prose includes pre-fill instructions. Test: tests/task-003.sh (run brief-intake on fixture brief; verify spec.md has expected pre-filled sections). AC3 mapped.
- [ ] T04: feature.md playbook frontmatter swap — `actions: [brief-intake, ...]` replaces `actions: [problem, ...]` for new features only — touches: templates/.sdd/playbooks/feature.md, start.sh logic for in-flight detection. Test: tests/task-004.sh (start a NEW feature gets brief-intake; pre-existing F009 keeps problem). AC4 mapped.
- [ ] T05: Delete success from feature.md SPEC stage actions list; mark success.md deprecated — touches: templates/.sdd/playbooks/feature.md, templates/.sdd/actions/success.md. Test: tests/task-005.sh (frontmatter validator passes; success.md has deprecated:true). AC5 mapped.
- [ ] T06: Verify F010+ specs scaffold without §2 — touches: start.sh test fixture for F010 scaffolding. Test: tests/task-006.sh (grep over scaffolded fixture for "### action: success" returns empty). AC6 mapped.
- [ ] T07: CLAUDE.md "One question per turn" subsection added; lint-action-prose.sh warns on bundled questions — touches: templates/CLAUDE.md, .sdd/scripts/lint-action-prose.sh. Test: tests/task-007.sh (lint warns on a bundled-question fixture). AC7 mapped.
- [ ] T08: §13/§15 action frontmatter audit — `requires_user_approval: false` set on wireframe.md and edge-case-sweep.md — touches: 2 action files. Test: tests/task-008.sh (frontmatter validator confirms). AC8 mapped.
- [ ] T09: AGENT-LED actions emit plain-English-first as default — touches: templates/.sdd/actions/proposed-approach.md (representative; "What it looks like" block updated to show foldable pattern). Test: tests/task-009.sh (action prose includes <details> block in example). AC9 mapped.
- [ ] T10: data-contract.md adds upload-invitation prose — touches: templates/.sdd/actions/data-contract.md. Test: tests/task-010.sh (grep for upload-invitation phrase + format list + failure path). AC10 mapped.
- [ ] T11 [INTEGRATION]: All 10 ACs verified end-to-end against a fresh F010-shaped fixture — touches: tests/integration/v1.6-anchor.smoke.sh (NEW). Test: itself. Closes the walking-skeleton vs widening sequencing.

**Effort estimates:**
- T01: M (action prose + 1 skeleton; new file, careful prose)
- T02: S (skeleton template; existing pattern to mirror)
- T03: M (pre-fill mapping logic + fixtures)
- T04: S (frontmatter edit + start.sh in-flight detection)
- T05/T06: S (deletion + grep verification)
- T07: M (CLAUDE.md doctrine + lint extension)
- T08: XS (frontmatter flag flips)
- T09: M (representative action update + foldable example)
- T10: XS (prose addition)
- T11: M (integration smoke harness)

Total: 6×S/XS + 5×M = ~feature-shaped (~2-3 days human pace; AI multiplier applies).

**Status:** AUTONOMOUS DRAFT. Sam re-approves on return.

### action: edge-case-sweep

- [x] ec-sweep: 6 edge cases drafted
- [x] ec-pick: AUTONOMOUS DRAFT — Sam picks which edges to add as ACs on return

### Exit checks

- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full-autonomous — Sam pre-approved this run mode at BUILD entry

**Run mode:** full-autonomous

### action: build-task

(driven by §14 tasks T01-T11 — each task lands as one commit; test-first per CLAUDE.md)

### exit_checks

- [ ] C-build-tasks-green: every task is GREEN (test passing, code committed) — `grep -cE '^- \[x\] T[0-9]+' "$SECTION_FILE"` matches the count of T-rows in §14
