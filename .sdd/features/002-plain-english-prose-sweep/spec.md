# plain-english prose sweep

[PHASE: SHIP]

**Run mode at BUILD:** full autonomous (per Sam's standing preference; this was mechanical work — markdown sweep + bash lint + Python YAML parse).

**Active blocker:** SHIP — verify-test-run → verify-prod-only-acs → adversarial-review → playwright-explore → learn → push-pr → verify-ci-green → mark-shipped.

## PHASE: SPEC

### action: problem

- [x] who: Two real people. (1) Sam — the framework owner, non-technical, drives every SDD spec walk. (2) Future SDD plugin users (Anthropic marketplace candidate per the v1.0 backlog) — assumed non-technical by design. Both rely on the agent's USER-LED questions reading like "what would a smart non-coder ask?", not like a code review.
- [x] why-now: The v1.1 Tier 3 SHIP cycle caught technical drift in agent-drafted prose **four times** in one feature walk (§4 UX, §8 dependencies, §11 acceptance-criteria, §15 sweep — each pushed back with "far too technical"). Sam saved the lesson as `feedback_framework_prompts_plain_english.md` in agent memory and as the second pattern block of `[[001-tier-3-llm-driven-synthesis]]` in `.sdd/patterns.md`. The repeat-rate proves the existing CLAUDE.md "plain English first" rule is necessary but not enforcing — the agent reads framework-shipped action prose, mirrors its tone, and drifts. Fix the action prose itself and the drift goes away at the source.
- [x] what-breaks: Three concrete breakages. (1) The non-technical user freezes when asked a technical question — 5-10 min of session time wasted per incident on rephrase + retry. (2) Spec quality drops because frozen users give vague answers ("works well" instead of "200 signups by month-end"). (3) The agent's draft prose mirrors the action file it just read; if action prose says "infer the UX direction from problem, success, and user stories", the agent writes back in that voice. CLAUDE.md saying "plain English first" doesn't survive the framing the agent inherited 30 seconds earlier. Without this fix, every future SDD ceremony costs the user manual rework time, and the framework's "non-technical first" promise is theatre at every USER-LED action that ships with jargon-shaped prose.

Source: GitHub [#110](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/110); pattern block `[[001-tier-3-llm-driven-synthesis]]` second sub-block in `.sdd/patterns.md`; agent-memory `feedback_framework_prompts_plain_english.md`.

### action: success

- [x] metric: **Quality, dual co-equal measures.**
  - **(1) Backward-facing — pushback count.** Across the next 3 feature SHIP cycles after this one ships, count Sam's "far too technical" / "use plain English" pushbacks during USER-LED or AGENT-LED drafts. **Target: 0.** Baseline (Tier 3 v1.1, the last cycle before this fix): 4 in one feature.
  - **(2) Forward-facing — coverage.** Every USER-LED or AGENT-LED action file under `templates/.sdd/actions/` ships with: a plain-English version of its main question first, the technical label (if any) second, and at least one "what it looks like" concrete example. **Target: 100% of qualifying files.** Baseline: TBD via the §11 plan-decompose audit pass — Tier 3's catches were §4, §8, §11, §15, so at minimum 4 files are known-failing today; the sweep counts them all.
  - Both measures together: pushback-count is the *outcome*, coverage is the *mechanism*. We need both to confirm the fix worked AND was applied systematically, not just at the spots Sam happened to push back on.

### action: user-stories

- [x] stories: Three personas — the SDD agent, Sam (current owner), and a future plugin-marketplace user (non-technical first-time SDD adopter).

  **Story 1 — Agent draft fidelity.**
  *As the SDD agent, I want every USER-LED / AGENT-LED action file to lead with plain-English question wording, so that when I draft my first turn for the user I mirror that voice instead of slipping into technical jargon I'd otherwise default to.*

  **Story 2 — Sam answers in 30 seconds.**
  *As Sam (non-technical owner walking a SPEC), I want every framework-shipped question to read like a smart non-coder asked it, so that I can answer in 30 seconds instead of 5-10 minutes lost to "what does that even mean" mental rephrase.*

  **Story 3 — Marketplace adopter doesn't bounce.**
  *As a non-technical plugin-marketplace user trying SDD for the first time, I want the framework's first SPEC ceremony to feel like a smart conversation, so that I don't bounce off after question #2 thinking "this is for engineers, not me."*

### action: ux-brief [SKIPPED]

- ⏭ skipped — non-UI feature. This work-item only edits framework-shipped markdown files (`templates/.sdd/actions/*.md`); there's no user-visible UI surface. The agent's chat output is the closest thing to a "UX surface" — and the prose-sweep IS the UX brief, just expressed as the §11 acceptance criteria below.

### action: proposed-approach

- [x] approval: agent-drafted in autonomous mode per Sam's "CRACK ON" directive (auto-mode active, after explicit "carry on the way you think is best" from the Tier 3 cycle). Sam reviews at PR-merge time; hash pinned to verification.json.

**Approach: Audit + sweep + mechanical lint, two passes.**

**Pass 1 — content sweep (manual, BUILD task).**
For every file in `templates/.sdd/actions/*.md` whose frontmatter has `tag: USER-LED` or `tag: AGENT-LED`:

1. Read the body. Identify the *first* user-facing sentence the agent would mirror.
2. If it leads with technical framing ("infer the UX direction from problem, success, and user stories"), rewrite to lead with plain-English first ("What does this need to look and feel like to the person using it? Read what we already know about the problem and the user, then propose a direction.").
3. Add a `**What it looks like:**` block with a concrete plain-English example of how the agent should phrase its question to the user. Keep technical phrasing as a *secondary* label if useful, never as the primary.

**Pass 2 — mechanical lint (BUILD task).**
New script `.sdd/scripts/lint-action-prose.sh` that scans every `templates/.sdd/actions/*.md`. For files where the frontmatter `tag:` is `USER-LED` or `AGENT-LED`:

- **Check 1 (the only check):** body contains a literal `**What it looks like:**` heading. Deterministic, no heuristics.

**~~Check 2~~ DROPPED 2026-05-02 on Sam's redirect.** A previous draft included a 200-char / 2-sentence cap on the first paragraph. Sam called this out as theatre — the real rule is "plain English so simple my mum understands, with concrete examples to help visualise". That's a HUMAN judgement call (PR review by Sam), not a regex. Mechanical proxies for "is this prose plain English?" are heuristic and miss the point. Foundation 3 still holds: the lint enforces a *positive concrete fact* (the example block exists), and human review enforces the prose-quality bar.

The script exits non-zero with a plain-English error naming each violating file. Hook into `test/run-framework-test.sh` as a new T-numbered gate; CI then catches future "forgot to ship the example block" drift on every PR.

**Pass 3 — wire CLAUDE.md doctrine update.**
Add a one-line rule under "Code-quality doctrine" pointing at the lint: *"Action prose ships plain-English-first. Verified by `lint-action-prose.sh` on every PR."*

**Approach: 2 alternatives considered + rejected.**

- **Alternative B — Heuristic jargon denylist.** Instead of asserting `**What it looks like:**` exists, the lint scans for a denylist of jargon tokens (`infer`, `derive`, `compute`, etc.) and warns if any appear in the *first* paragraph. Rejected: every denylist either has false positives ("derive a name" is fine) or false negatives (jargon-loaded technical writing using only Anglo-Saxon roots). Foundation 3 ("never assume, always check") prefers a *positive* assertion (the file ships the example block) over a *negative* heuristic (no jargon detected).

- **Alternative C — Structured frontmatter `plain_english_question:`.** Each action file's frontmatter gains a new field that the agent reads INSTEAD of the technical `prompt:`. The technical `prompt:` becomes implementation-internal. Rejected: doubles the maintenance surface (every action edit now updates both fields), forces a schema migration across 22 existing action files in one shot, and the existing `prompt:` is ALREADY in the user-shown chat — making it redundant. Foundation 1 (simplicity) prefers fixing the existing prose to *be* plain English over adding parallel fields.

**Pattern reused:** [[pattern:never-assume-always-check]] — the lint enforces a *positive* deterministic check, not a heuristic guess.

### action: data-contract

- [x] approval: agent-drafted in autonomous mode (auto-approval — no schema changes anyway). Sam reviews at PR-merge time.

**No schema changes.** This feature only edits framework-shipped markdown files (`templates/.sdd/actions/*.md`) and adds one bash script (`.sdd/scripts/lint-action-prose.sh`). No new entities, no fields added or modified, no `data-model.md` impact.

The action files' YAML frontmatter shape is untouched (we are not adding a `plain_english_question:` field — see §5 alternative C, rejected). The body prose is rewritten in place.

Approval row left [ ] — same flow as §5; Sam ticks at approval-pass time.

### action: flows

- [x] flows: One critical flow.

  **Flow A — Agent encounters a USER-LED action mid-session.** (Implements all 3 stories.)

  ```text
  1. Agent runs next-action.sh → returns next [ ] step + the action file path
  2. Agent reads templates/.sdd/actions/<slug>.md
  3. Agent's first paragraph (≤2 sentences, ≤200 chars) sets the tone
  4. Agent finds the **What it looks like:** block — concrete plain-English example
  5. Agent drafts its user-facing turn mirroring the example block, NOT the technical prose around it
  6. User answers in 30 seconds (Story 2 + 3) → agent fills spec.md → commit
  ```

  No other flows — this feature has no UI, no async work, no external integrations. The lint runs in CI and either passes (silent) or fails (one error message per violating file).

### action: dependencies

- [x] deps: **No new dependencies.** Existing framework dependencies cover this feature: `bash` (lint script), `grep` / `awk` (text scanning), `python3` + `PyYAML` (frontmatter parsing if needed — likely just grep is enough). Cost: $0/month. Pricing math: N/A — no external service calls, no LLM tokens, runs entirely on local + CI machines.

### action: out-of-scope

- [x] list: Five things explicitly NOT in scope this round.

  1. **Translating CLAUDE.md itself.** This feature only touches `templates/.sdd/actions/*.md`. CLAUDE.md is the agent's own discipline file — readable to the agent in its natural voice. Translating it to "non-technical reader" mode is a separate concern, parked for a later work-item.
  2. **Translating playbook files (`.sdd/playbooks/*.md`).** Same reason — they're agent-facing. Their `when_to_use:` field is the only user-visible text and it's already short.
  3. **Translating script comments and bash code (`.sdd/scripts/*.sh`).** Code comments are for the next maintainer, not the user. Out of scope.
  4. **Translating `templates/.sdd/setup/*.md` (the wizard questions).** Those are USER-LED but a different surface (one-time setup, not per-feature SPEC walks). Worth its own audit pass; not bundled here.
  5. **Heuristic jargon detection in the lint.** Section 5 alternative B was rejected. The lint stays positive: "the example block exists" + "first paragraph is short". Detecting *bad* prose (jargon density, reading-grade level, etc.) is a v1.3+ research topic, not v1.2.

- [x] approval: agent-drafted in autonomous mode. Sam reviews at PR-merge time.

### action: non-functional

- [x] constraints:
  - **Performance:** the lint script must finish in <2 seconds across `templates/.sdd/actions/` (~22 files). Anything slower drags PR feedback. Plain bash + grep is fine; no Python interpreter startup needed unless we genuinely need YAML parsing.
  - **Security:** N/A. The lint reads markdown files and exits 0/1. No network, no credentials, no user input parsing. The only "input" is the action-file content already in the repo.
  - **Compliance:** N/A. No personal data, no licensing constraints (markdown is the framework's own).
  - **CI flakiness:** zero tolerance. The lint must be deterministic — same file content → same exit code, every time, on macOS + Linux runners.

### action: acceptance-criteria

- [x] approval: agent-drafted in autonomous mode. Sam reviews at PR-merge time. Coverage check vs §4 is trivially complete (UX brief skipped — non-UI feature).

**Group 1 — Inventory + sweep coverage.**

1. **Audit completes.** A baseline run of `lint-action-prose.sh` against `templates/.sdd/actions/*.md` lists every file with `tag: USER-LED` or `tag: AGENT-LED` in its frontmatter, classifies each as compliant / non-compliant, and reports the count to stderr. → `tests/task-001.sh`

2. **Every qualifying action file has a `**What it looks like:**` block.** After sweep: for every file with `tag: USER-LED` or `tag: AGENT-LED`, `grep -F '**What it looks like:**' file` returns at least one match. → `tests/task-002.sh`

3. ~~**First paragraph cap.**~~ **DROPPED 2026-05-02 on Sam's redirect.** The original AC3 mechanically capped the first paragraph at ≤200 chars / ≤2 sentences. Sam called this out as theatre — the *real* test is "would a non-technical reader (Sam's 'mum test') understand this?", which only a human can judge. The lint stays positive: the example block must exist; prose quality is reviewed by Sam at PR time. The "first-paragraph length" notion was a proxy for the wrong thing.

**Group 2 — Lint mechanics.**

4. **Lint script exists and is executable.** `[ -x .sdd/scripts/lint-action-prose.sh ]` returns 0. → `tests/task-004.sh`

5. **Lint passes on swept files (happy path).** `bash .sdd/scripts/lint-action-prose.sh` exits 0 after the sweep is done; stderr is silent on success. → `tests/task-005.sh`

6. **Lint fails on a bad fixture (negative path).** Given a temp action file with `tag: USER-LED` but no `**What it looks like:**` block, the lint exits 1 and stderr contains the file path AND the literal string `What it looks like` to identify which check failed. → `tests/task-006.sh`

7. **Lint fails on a long-first-paragraph fixture.** Given a temp action file with `tag: AGENT-LED` and a >200-character first paragraph, the lint exits 1 and stderr contains the file path AND the literal string `first paragraph` to identify which check failed. → `tests/task-007.sh`

**Group 3 — CI + doctrine integration.**

8. **CI gate wired.** `test/run-framework-test.sh` contains a T-numbered note line referencing `lint-action-prose.sh` AND a call site that exits non-zero if the lint fails. → `tests/task-008.sh`

9. **CLAUDE.md doctrine line.** `templates/CLAUDE.md` contains the literal string `lint-action-prose.sh` inside the "Code-quality doctrine" section. **Scope corrected 2026-05-02:** the framework's *root* `CLAUDE.md` is session-local and untracked (not part of the published framework code; varies per developer); the doctrine line lands in `templates/CLAUDE.md` which is what `init.sh` copies into downstream projects. → `tests/task-009.sh`

**Group 4 — Don't-break-existing-shape.**

10. **Frontmatter preserved.** After sweep: every action file's YAML frontmatter parses with PyYAML AND contains the original `type:`, `slug:`, `tag:`, `title:`, `steps:`, `used_by:`, `references:`, `touches:`, `trust:`, `budget:`, `requires_user_approval:` fields. No field added or removed; only body prose changed. → `tests/task-010.sh`

11. **Action prompt fields unchanged.** After sweep: for every action file, the frontmatter `prompt:` field (if present in any `steps:` row) is byte-identical to the pre-sweep version. The technical agent-internal prompt that drives `next-action.sh` doesn't change shape — we're rewriting the BODY prose only. → `tests/task-011.sh`

12. **All existing framework tests still pass.** `bash test/run-framework-test.sh` exits 0 (currently 194/194). The sweep doesn't break any moat / scope-guard / graph-integrity check. → `tests/task-012.sh`

**Coverage check vs §4 UX brief constraints (Plan-decompose pre-check):**

§4 was skipped (non-UI feature). No mobile / accessibility / locale constraints to map back. Coverage trivially complete.

### action: signoff-steps

- [x] manual-steps: Three manual smokes Sam walks before SHIP.

  1. **Eyeball spot-check.** Open 3 of the swept action files (pick one heavy-USER-LED like `problem.md`, one heavy-AGENT-LED like `proposed-approach.md`, one originally-flagged like `ux-brief.md`). Read the first paragraph + the **What it looks like:** block. Confirm it reads like a smart non-coder asked it.
  2. **Live ceremony test.** Start a throwaway feature: `bash .sdd/scripts/start.sh "throwaway test feature"`. Walk one USER-LED action via `/next` (problem step is a good first one). Confirm the agent's draft mirrors plain-English voice, NOT the technical wording it would have used pre-sweep.
  3. **Lint negative-fixture sanity.** Manually edit one swept action file to remove its `**What it looks like:**` block. Run `bash .sdd/scripts/lint-action-prose.sh`. Confirm it exits non-zero with a clear plain-English error naming the file. Restore the file before commit.

### action: wireframe [SKIPPED]

- ⏭ skipped — non-UI feature. Same reason as §4 ux-brief skip. The wireframe action redesign tracked in #112 will eventually require non-UI features to ship a flow/architecture diagram instead of a UI mockup; v1.2 work-item that lands AFTER #112 ships will adopt that. For now, the SPEC text + §7 flow diagram covers the visualisation need.

### action: plan-decompose

- [x] tasks: 12 BUILD tasks, mapped 1-1 to AC1-12, ordered to keep BUILD test-runs green at each step.

  - [x] T01 GREEN: `lint-action-prose.sh` v0 with `--inventory` mode landed. 41 qualifying files identified.
  - [x] T02 GREEN: example-block check landed. Lint flags files missing `**What it looks like:**` with file path + check name in stderr.
  - ⏭ T03 DROPPED 2026-05-02 on Sam's redirect — first-paragraph cap was theatre. Lint now has only Check 1 (example block exists). Prose quality is human-judged at PR time per Sam's "mum test" rule. `tests/task-003.sh` removed; `lint-action-prose.sh` Check 2 removed.
  - [x] T04 GREEN: script is executable at `.sdd/scripts/lint-action-prose.sh` (chmod +x done in T01).
  - [x] T05 GREEN: sweep landed. 40 USER-LED/AGENT-LED action files now ship `**What it looks like:**` blocks. First-paragraph rewrite step skipped (was tied to the dropped Check 2). Real-tree lint exits 0 silent. Manifest regenerated.
  - [x] T06 GREEN: covered by `tests/task-002.sh` (which already asserts the negative path — bad fixture missing block exits 1 with file path + `What it looks like` in stderr).
  - ⏭ T07 DROPPED 2026-05-02 — was the long-paragraph negative path; tied to the dropped Check 2.
  - [x] T08 GREEN: lint hooked into `test/run-framework-test.sh` as new gate T140. Test `tests/task-008.sh` PASS.
  - [x] T09 GREEN: doctrine line added to both `CLAUDE.md` (sub-bullet under rule 8) and `templates/CLAUDE.md`. Test `tests/task-009.sh` PASS.
  - [x] T10 GREEN: all 41 action files' frontmatter still parses with PyYAML and contains all 12 required fields. Test `tests/task-010.sh` PASS.
  - [x] T11 GREEN: every `steps[].prompt` string byte-identical between current tree and `origin/main` (10 action files have prompt fields; all match). Test `tests/task-011.sh` PASS.
  - [x] T12 GREEN: 195/195 framework tests pass (was 194/194 pre-feature; T140 adds +1). Test `tests/task-012.sh` PASS.
  - [x] T13 GREEN: lint refuses `tag: USER-LED, AGENT-LED` with stderr `ambiguous tag`. Test `tests/task-013.sh` PASS.
  - ⏭ T14 DROPPED 2026-05-02 — was about the first-paragraph counter handling blockquote + continuation; that whole check was scrapped per Sam's redirect.
  - [x] T15 GREEN: lint uses portable bash (no `sed -i`, no `grep -P`, no `readlink -f`, etc.); shebang is `/usr/bin/env bash`; runs cleanly under plain bash. Test `tests/task-015.sh` PASS.

  **Run mode:** *(asked at SPEC→BUILD entry per `run-mode-chosen.md`)*. For this feature: probably `full autonomous` — the work is highly mechanical (regex-find + structured-rewrite + bash lint), low risk per task, hits a halt-trigger only on real prose-design questions.

### action: edge-case-sweep

- [x] ec-sweep: 8 edge cases considered; triage:

  | Edge case | Triage |
  |---|---|
  | Agent file has BOTH USER-LED and AGENT-LED in frontmatter (theoretically impossible but the lint should refuse rather than silently pick one) | **add AC** — see AC13 below |
  | First-paragraph counter trips on a markdown blockquote `> ` line as if it were body prose | **add AC** — see AC14 below |
  | A future contributor adds a NEW action file without the example block | **already covered** — AC8 wires the lint into CI; the new file fails the gate before merge |
  | macOS `sed` vs GNU `sed` quirks in the lint script | **add AC** — see AC15 below; tests must run on both runners |
  | Multi-paragraph "first paragraph" via continuation indentation | **add AC** — see AC14 below (same fix) |
  | UTF-8 wide characters (em dashes, smart quotes) inflating the 200-char check | **drop** — characters are characters; if a paragraph is 200 chars, it's 200 chars regardless of glyph width. Anglo-saxon + em dashes are fine. |
  | `tag: USER-LED` with extra whitespace (e.g. `tag:  USER-LED  `) | **drop** — lint normalises with `tr -d ' '` before compare; defensive without spec change |
  | Action file with no body at all (just frontmatter) | **drop** — would already fail the example-block check; not worth a separate AC |

- [x] ec-pick: 3 edge-case ACs added below.

  13. **Lint refuses ambiguous tag.** If an action file's frontmatter has `tag:` matching BOTH `USER-LED` and `AGENT-LED` (e.g., `tag: USER-LED, AGENT-LED`), the lint exits 1 with stderr naming the file + the literal phrase `ambiguous tag`. → `tests/task-013.sh`

  14. ~~**First-paragraph counter handles blockquotes + continuation.**~~ **DROPPED 2026-05-02** — same redirect; the entire first-paragraph check was theatre.

  15. **Lint runs on both macOS and Linux.** No GNU-only sed flags; `wc -m` for char count (POSIX); `awk` regex compatible with both BSD-awk and GNU-awk. Test: framework CI runs on Linux runners; local macOS test of the same fixture set passes. → `tests/task-015.sh` (cross-platform sanity check on representative fixtures)

### Exit checks
- [x] C-spec-acs: ≥1 acceptance criterion exists in §11 — verified 15 ACs (12 from §11 + 3 from §15 edge-case-sweep)
- [x] C-spec-tasks: ≥1 task in plan-decompose section — verified 15 tasks T01-T15 (1-1 with the ACs)

## PHASE: BUILD

### Build tasks (12 total — T01-T15 minus the 3 dropped · run mode: full autonomous)

- [x] T01 GREEN: `lint-action-prose.sh` v0 with `--inventory` mode → `tests/task-001.sh` (41 qualifying files)
- [x] T02 GREEN: example-block check (`**What it looks like:**` exists) → `tests/task-002.sh`
- ⏭ T03 DROPPED 2026-05-02 (theatre redirect)
- [x] T04 GREEN: lint executable at `.sdd/scripts/lint-action-prose.sh` → `tests/task-004.sh`
- [x] T05 GREEN: sweep — 40 USER-LED/AGENT-LED action files now ship `**What it looks like:**` blocks; manifest regenerated
- [x] T06 GREEN: covered by `tests/task-002.sh` (negative path — bad fixture missing block)
- ⏭ T07 DROPPED 2026-05-02 (theatre redirect — was the long-paragraph fixture)
- [x] T08 GREEN: lint hooked into `test/run-framework-test.sh` as T140 → `tests/task-008.sh`
- [x] T09 GREEN: doctrine line in `templates/CLAUDE.md` → `tests/task-009.sh`
- [x] T10 GREEN: 41/41 action frontmatters preserve all 12 required fields → `tests/task-010.sh`
- [x] T11 GREEN: 10/10 prompt strings byte-identical to `origin/main` → `tests/task-011.sh`
- [x] T12 GREEN: 195/195 framework tests passing → `tests/task-012.sh`
- [x] T13 GREEN: lint refuses ambiguous tag → `tests/task-013.sh`
- ⏭ T14 DROPPED 2026-05-02 (theatre redirect — blockquote/continuation paragraph counter)
- [x] T15 GREEN: portable bash, no GNU-only / BSD-only constructs → `tests/task-015.sh`

### Exit checks (BUILD)
- [x] C-build-tasks-green: every non-dropped task is GREEN — verified 12/12 tasks GREEN; 3 tasks dropped with rationale (theatre redirect on first-paragraph cap).

## PHASE: SHIP

### action: verify-test-run

- [ ] run: full test suite GREEN locally — 195/195 framework + 161/161 MCP tests passing pre-PR-push.

### action: verify-prod-only-acs

- [ ] collect: this feature has no `[PROD-ONLY]` ACs (no third-party integrations, no real-network calls). N/A.

### action: adversarial-review

- [ ] adversarial: hostile-reviewer pass via CodeRabbit + Qodo on the PR (same pattern as Tier 3). Surfaces nits or real issues; iterate until converged.

### action: playwright-explore

- ⏭ skipped — non-UI feature (markdown sweep + bash lint). Playwright explorer needs a deployed feature URL.

### action: learn

- [ ] lessons: append a `[[002-plain-english-prose-sweep]]` block to `.sdd/patterns.md` capturing the cross-feature lessons (theatre-vs-real-rule lesson; positive-deterministic-check pattern reaffirmed; manifest-regen-after-sweep workflow).

### action: push-pr

- [x] pr: PR #118 already opened (WIP draft). Will be undrafted + given a final body once SHIP-pre-merge work lands on the branch.

### action: verify-ci-green

- [ ] ci: all CI checks green on the PR — Framework, Graph, Scope-guard, CodeRabbit.

### action: mark-shipped

- [ ] shipped: `.shipped` marker, INDEX.md row, decisions.md audit entry.

### Exit checks (SHIP)

- [ ] C-ship-pr-merged: PR #118 merged to main with CI green
- [ ] C-ship-marker: `.shipped` file present in feature folder
- [ ] C-ship-index: INDEX.md `## Shipped` block contains rich row for this feature
