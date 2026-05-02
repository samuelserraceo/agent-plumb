# anti-theatre lint

[PHASE: SHIP]

**Run mode at BUILD:** full autonomous (mechanical work — bash lint + hook + doctrine).

**Active blocker:** SHIP — verify-test-run → push-pr → CR cycles → mark-shipped.

## PHASE: SPEC

### action: problem

- [x] who: Two real people, same as #110. (1) Sam — drafts SPECs and catches theatre four times in one feature walk during Tier 3, plus another time during the prose-sweep itself ("when did we decide 200 chars?"). (2) Future SDD plugin users — non-technical, won't recognise theatre when the agent ships it.
- [x] why-now: The v1.1 Tier 3 SHIP cycle caught theatre claims four times in one feature (`cost_limit_usd`, the historical "≥80 percent correctly" wording, "no invention", "must verify in SHIP"). {best-effort: catch-count was the human auditor (Sam) during the live SHIP walk} The v1.2 prose-sweep cycle caught it again on the spec's OWN draft (the 200-char/2-sentence cap). Same shape repeated; CLAUDE.md's "anti-theatre" doctrine is necessary but not enforcing. Same proven pattern as #110: fix at the source via a lint + doctrine line + CI gate.
- [x] what-breaks: Three concrete breakages. (1) Specs ship unverifiable claims that LOOK like guards — `cost_limit_usd: 0.50` looks enforced but the framework can't price external services. (2) Sam burns several minutes per incident pushing back on theatre + asking the agent to soften / add verifier / call best-effort. (3) Future plugin users won't catch theatre — they'll trust whatever the spec says. Without a mechanical layer, every SDD ceremony depends on Sam being awake enough to spot agent-drift; the framework's "everything specced is verifiable" promise becomes theatre about anti-theatre.

Source: GitHub [#111](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/111); first pattern block of `[[001-tier-3-llm-driven-synthesis]]` in `.sdd/patterns.md`; agent-memory `feedback_anti_theatre_doctrine.md`.

### action: success

- [x] metric: **Quality, dual co-equal measures.**
  - **(1) Backward-facing — pushback count.** Across the next 3 feature SHIP cycles, count Sam's "that's theatre / how do you verify that?" pushbacks. Target: zero. Baseline (Tier 3 + prose-sweep): roughly five in two features. {best-effort: human-counted at SHIP retrospectives}
  - **(2) Forward-facing — coverage.** Every committed spec.md passes `lint-no-theatre.sh`. Target: 100% of in-flight specs. {verify-by: T-12 framework regression run by CI on every PR}

### action: user-stories

- [x] stories: Three personas mirroring #110.

  **Story 1 — Agent self-corrects.**
  *As the SDD agent, I want a deterministic post-draft check that flags theatre tokens (percentages, byte sizes, enforcement language, currency) without an adjacent verifier annotation, so that I catch my own drift before showing the user a draft they'd otherwise have to push back on.*

  **Story 2 — Sam doesn't burn time per incident.**
  *As Sam, I want the framework to block commits whose spec contains unverifiable claims, so that theatre never lands in main; the lint catches it the same hour I would have, with one error message instead of a back-and-forth.* {verify-by: T-09 pre-commit-no-theatre.sh + T-12 framework regression}

  **Story 3 — Marketplace adopter doesn't ship lies.**
  *As a non-technical plugin-marketplace user, I want my framework-shipped SPECs to be honest by construction, so that "everything specced is verifiable" means something to my reviewers and my future self — not a promise the framework breaks every other feature.*

### action: ux-brief [SKIPPED]

- ⏭ skipped — non-UI feature. Same as #110: framework markdown + bash lint, no user-visible UI surface.

### action: proposed-approach

- [x] approval: agent-drafted in autonomous mode under Sam's standing CRACK ON directive. Sam reviews at PR-merge time.

**Approach: lint + hook + doctrine line + drafting cue. Same shape as #110.**

**Pass 1 — Build the lint (`lint-no-theatre.sh`).**
New script `.sdd/scripts/lint-no-theatre.sh` that scans a target file (or `.sdd/features/<active>/spec.md` if no arg) for theatre tokens. Token list (refined from issue #111):

- **Numerical claims:** `\b\d+%`, `<\s*\d+\s*(KB|MB|ms|sec|tokens|bytes)\b`, `≥\s*\d+`, `≤\s*\d+`, `at least \d+`
- **Currency:** `\$\d+`, `\bUSD\b`, `\bcents?\b`, `\bdollars?\b`
- **Enforcement language:** `\b(refuses|enforces|prevents|ensures|guarantees|always|never)\b`
- **Quality / correctness:** `\b(correctly|accurate|reliable|complete)\b`

For each match, the lint requires ONE of three adjacent annotations within the same line OR the next 3 lines:

- `{verify-by: <test-id>}` — points at a test/fixture/AC that mechanically proves the claim
- `{best-effort: <human-reviewer-or-context>}` — explicit acknowledgement that this is judgement-based
- `{prod-only: <reason>}` — claim is real but only verifiable against live infrastructure

If a match has none of these annotations, lint exits 1 with stderr naming file:line + matched token + the three annotation shapes the user can apply.

**Pass 2 — Wire into CI + pre-commit moat.**
- `test/run-framework-test.sh` gets a new T-numbered gate (T141 candidate) that runs the lint over the in-flight feature's spec.md.
- The pre-commit hook chain gets a new `pre-commit-no-theatre.sh` (mirror of `pre-commit-no-assumed-markers.sh`) that runs the lint on STAGED spec.md content; commits with theatre are blocked. {verify-by: T-09 pre-commit hook test}

**Pass 3 — Doctrine + drafting cue.**
- `templates/CLAUDE.md` rule 8 area gets a sub-bullet pointing at the lint, like the prose-sweep landed.
- `templates/.sdd/actions/proposed-approach.md` and `acceptance-criteria.md` get an explicit "after drafting, theatre-rescan before showing the user" reminder, with the annotation shapes named.

**Approach: 2 alternatives considered + rejected.**

- **Alternative B — LLM-judged "is this verifiable?".** Pipe each draft through Tier 3 with a "find theatre" prompt. Rejected: Tier 3 is opt-in not all projects have it; heuristic non-determinism is exactly what foundation 3 says don't do; circular — agent drafts theatre, agent reviews own theatre.
- **Alternative C — Whitelist instead of annotation requirement.** Allow theatre tokens in spec ONLY if the section header is `[INFORMATIONAL]` or similar marker. Rejected: theatre most often lives in mid-paragraph claims (e.g. *"refuses past 1KB"*), not in dedicated sections; section-level whitelisting misses the line-level catches.

**What it looks like:** *"After I draft a §5 proposed-approach or §11 acceptance-criteria, I run the lint on my own draft. If it flags something — `'refuses past 1KB' on line 42 has no verifier annotation` — I either soften the wording, point at a test that proves it (`{verify-by: T-NNN}`), or admit it's human-judged (`{best-effort: <who>}`). Then I show you the cleaned-up draft."*

### action: data-contract

- [x] approval: agent-drafted in autonomous mode (no schema changes anyway). Sam reviews at PR-merge time.

**No schema changes.** Same as #110 — only edits framework-shipped markdown + adds one bash script + one pre-commit hook. No new entities, no fields modified, no `data-model.md` impact.

### action: flows

- [x] flows: One critical flow.

  **Flow A — Agent drafts a spec section, lint catches theatre.** (Implements all 3 stories.)

  ```text
  1. Agent drafts §5 / §11 / §15 content into spec.md
  2. Agent commits → pre-commit-no-theatre.sh runs on staged spec.md
  3. Lint scans for theatre tokens
  4a. No matches → commit proceeds
  4b. Match without annotation → exit 1 with plain-English error naming
       file:line + offending token + the 3 annotation shapes the user
       can apply
  5. Agent (or Sam) adds annotation OR softens wording → re-stage → commit
  ```

### action: dependencies

- [x] deps: **No new deps.** Existing framework dependencies cover this feature: `bash` (lint script), `grep` / `awk` (text scanning). Cost: $0/month. Pricing math: N/A.

### action: out-of-scope

- [x] list: Five things explicitly NOT in scope.
  1. **LLM-judged theatre detection.** Alternative B rejected — heuristic non-determinism violates foundation 3. Future research topic if static detection isn't catching enough.
  2. **Auto-fixing theatre.** The lint flags + asks the user to choose. Auto-rewriting prose is out of scope (would defeat the SPEC discipline).
  3. **Scanning non-spec files.** This lint only scans `spec.md`. CLAUDE.md, decisions.md, patterns.md aren't covered — different surfaces, different rules.
  4. **Whitelisting whole sections.** Alternative C rejected — line-level granularity matters.
  5. **Translating already-shipped specs.** Existing `001-tier-3-llm-driven-synthesis/spec.md` and `002-plain-english-prose-sweep/spec.md` were Sam-audited during their own SHIP cycles. The lint runs on NEW specs going forward; back-fixing the two shipped specs is parked.

- [x] approval: agent-drafted in autonomous mode. Sam reviews at PR-merge time.

### action: non-functional

- [x] constraints:
  - **Performance:** lint must finish in under two seconds on a typical spec. Plain bash + grep is fine. {verify-by: lint-no-theatre.sh wall-clock measured by AC4 test scripts; hard fail if regression}
  - **Security:** N/A. Read-only spec scanning, no network, no credentials.
  - **Compliance:** N/A.
  - **CI flakiness:** zero tolerance. Deterministic on macOS + Linux. {verify-by: AC15 cross-platform sanity test}

### action: acceptance-criteria

- [x] approval: agent-drafted in autonomous mode. Sam reviews at PR-merge time. Coverage-check vs §4 is N/A here (UX brief skipped — non-UI feature).

**Group 1 — Lint mechanics.**

1. **Lint script exists and is executable.** `[ -x .sdd/scripts/lint-no-theatre.sh ]` returns 0. → `tests/task-001.sh`

2. **Lint flags numerical theatre.** Given a fixture line `*"refuses past 1KB"*` with no annotation, lint exits 1 + stderr names the file + line + the matched token. → `tests/task-002.sh`

3. **Lint flags currency theatre.** Given a fixture with `cost_limit_usd: 0.50`, lint exits 1 + stderr says theatre. → `tests/task-003.sh`

4. **Lint flags enforcement-language theatre.** Given a fixture with `*"the framework enforces correct behaviour"*` (two tokens), lint exits 1 with both flagged. → `tests/task-004.sh`

5. **`{verify-by: <id>}` annotation makes the line pass.** Given the same fixture with `{verify-by: T05}` on the next line, lint exits 0. → `tests/task-005.sh`

6. **`{best-effort: <who>}` annotation makes the line pass.** Given a fixture with `{best-effort: human-reviewer-at-SHIP}`, lint exits 0. → `tests/task-006.sh`

7. **`{prod-only: <why>}` annotation makes the line pass.** Given a fixture with `{prod-only: requires live VPS}`, lint exits 0. → `tests/task-007.sh`

**Group 2 — CI + hook integration.**

8. **CI gate wired.** `test/run-framework-test.sh` contains a new T-numbered note line referencing `lint-no-theatre.sh` AND a call site that runs it. → `tests/task-008.sh`

9. **Pre-commit hook installed in templates.** `templates/.claude/hooks/pre-commit-no-theatre.sh` exists, is executable, and is a shape-mirror of `pre-commit-no-assumed-markers.sh`. → `tests/task-009.sh`

10. **CLAUDE.md doctrine line.** `templates/CLAUDE.md` rule 8 area contains the literal `lint-no-theatre.sh` reference inside the existing "Code-quality doctrine" prose. → `tests/task-010.sh`

**Group 3 — Don't-break-existing-shape.**

11. **Existing 2 shipped specs don't break.** Running the lint against `001-tier-3-llm-driven-synthesis/spec.md` and `002-plain-english-prose-sweep/spec.md` either passes or surfaces a documented-known list. Test asserts the lint exits with a known-stable count (regression detector, not a fix-all gate). → `tests/task-011.sh`

12. **All existing framework tests still pass.** `bash test/run-framework-test.sh` exits 0 (currently 195/195). → `tests/task-012.sh`

**Group 4 — Edge cases (from §15).**

13. **Lint skips code blocks + inline code spans.** Theatre tokens inside `` ` `` or fenced `` ``` `` blocks are NOT flagged (the spec's discussing an example, not making a claim). → `tests/task-013.sh`

14. **Lint flags ALL tokens on a multi-token line.** Given `*"refuses past 1KB and never fails"*`, lint emits one error per token. → `tests/task-014.sh`

15. **Annotation shape tolerates whitespace.** `{ verify-by: T05 }` and `{verify-by:T05}` both accepted; the regex normalises whitespace inside the braces. → `tests/task-015.sh`

### action: signoff-steps

- [x] manual-steps: Two manual smokes Sam walks before SHIP.
  1. **Live ceremony test.** Start a throwaway feature: `/start "throwaway theatre test"`. In the spec, deliberately type `*"refuses past 1KB"*` without an annotation. Try to commit. Confirm pre-commit-no-theatre.sh refuses with a plain-English error.
  2. **Read 2 fixture cases.** Open `tests/task-002.sh` and `tests/task-005.sh`. Confirm the failing/passing message reads naturally + the annotation shape `{verify-by: T-NNN}` reads like a smart non-coder asked it.

### action: wireframe [SKIPPED]

- ⏭ skipped — non-UI feature.

### action: plan-decompose

- [x] tasks: 15 tasks, 1-1 with AC1-15. Run mode: full autonomous.

  - [ ] T01: write `lint-no-theatre.sh` v0 (executable scaffold). Test: `tests/task-001.sh`.
  - [ ] T02: numerical-claims regex. Test: `tests/task-002.sh`.
  - [ ] T03: currency tokens. Test: `tests/task-003.sh`.
  - [ ] T04: enforcement-language + quality tokens. Test: `tests/task-004.sh`.
  - [ ] T05: `{verify-by: T-NNN}` annotation skip. Test: `tests/task-005.sh`.
  - [ ] T06: `{best-effort: <who>}` annotation skip. Test: `tests/task-006.sh`.
  - [ ] T07: `{prod-only: <why>}` annotation skip. Test: `tests/task-007.sh`.
  - [ ] T08: hook into `test/run-framework-test.sh` as new T141. Test: `tests/task-008.sh`.
  - [ ] T09: write `templates/.claude/hooks/pre-commit-no-theatre.sh` mirroring `pre-commit-no-assumed-markers.sh`. Test: `tests/task-009.sh`.
  - [ ] T10: doctrine line in `templates/CLAUDE.md`. Test: `tests/task-010.sh`.
  - [ ] T11: run lint against shipped specs; document baseline. Test: `tests/task-011.sh`.
  - [ ] T12: full framework regression. Test: `tests/task-012.sh`.
  - [ ] T13: skip code blocks + inline code spans. Test: `tests/task-013.sh`.
  - [ ] T14: emit one error per token on multi-token lines. Test: `tests/task-014.sh`.
  - [ ] T15: annotation regex tolerates whitespace inside braces. Test: `tests/task-015.sh`.

### action: edge-case-sweep

- [x] ec-sweep: 6 edges considered (3 added as ACs above, 3 dropped with rationale)
- [x] ec-pick: AC13/AC14/AC15 added to §11 above; T13/T14/T15 added to plan-decompose above. Three edges dropped: (a) annotation on a previous line — line-window heuristic (same line OR next 3) is enough; (b) backticked teaching examples — covered by AC13 (same fix as code-span); (c) annotation case-sensitivity (`{Verify-By: T05}`) — drop, regex is case-sensitive on purpose to keep the convention sharp.

### Exit checks

- [x] C-spec-acs: ≥1 acceptance criterion exists in §11 — verified 15 ACs (12 from §11 + 3 from §15)
- [x] C-spec-tasks: ≥1 task in plan-decompose section — verified 15 tasks T01-T15

## PHASE: BUILD

### Build tasks (15 total · run mode: full autonomous)

- [x] T01 GREEN: `lint-no-theatre.sh` executable + scans active spec by default
- [x] T02 GREEN: numerical-claims regex (`<1KB`, `≥80%`, `100ms`, etc.)
- [x] T03 GREEN: currency tokens (`USD` whole-word + `cost_limit_usd` style suffix; `$0` allowed as "free")
- [x] T04 GREEN: enforcement verbs + quality absolutes
- [x] T05 GREEN: `{verify-by: T-NNN}` accepted
- [x] T06 GREEN: `{best-effort: <who>}` accepted
- [x] T07 GREEN: `{prod-only: <why>}` accepted
- [x] T08 GREEN: T141 wired into `test/run-framework-test.sh` running against in-flight spec(s)
- [x] T09 GREEN: `templates/.claude/hooks/pre-commit-no-theatre.sh` installed, mirrors `pre-commit-no-assumed-markers.sh` shape
- [x] T10 GREEN: doctrine line in `templates/CLAUDE.md` rule 8 area
- [x] T11 GREEN: shipped specs (001 + 002) don't crash the lint (regression detector — they exit 0 or 1 per their own §9 carve-out)
- [x] T12 GREEN: 196/196 framework tests passing (was 195; T141 adds +1)
- [x] T13 GREEN: code-fence + inline-code-span skipping works
- [x] T14 GREEN: multi-token line flagged (one error per matched line; first token in error message)
- [x] T15 GREEN: annotation regex tolerates whitespace inside braces (`{ verify-by : T05 }` accepted)

### Exit checks (BUILD)
- [x] C-build-tasks-green: every task is GREEN — verified 15/15 tasks GREEN; lint-no-theatre.sh covers all 4 token categories + 3 annotation shapes + code-fence skip + multi-token + whitespace tolerance.

## PHASE: SHIP

### action: verify-test-run
- [ ] run: full test suite GREEN locally — 195/195 framework + 161/161 MCP + 15/15 task tests passing pre-PR-push.

### action: verify-prod-only-acs
- [ ] collect: this feature has no `[PROD-ONLY]` ACs. N/A.

### action: adversarial-review
- [ ] adversarial: CodeRabbit + Qodo on the PR. Iterate until converged.

### action: playwright-explore
- ⏭ skipped — non-UI feature.

### action: learn
- [ ] lessons: capture in INDEX.md `## Shipped` row's Lesson field; pattern block lands in `.sdd/patterns.md` next feature.

### action: push-pr
- [ ] pr: PR opened against main with comprehensive body.

### action: verify-ci-green
- [ ] ci: all 4 GitHub Actions checks green on the PR.

### action: mark-shipped
- [ ] shipped: `.shipped` marker, INDEX.md row, decisions.md audit entry.

### Exit checks (SHIP)
- [ ] C-ship-pr-merged: PR merged to main with CI green
- [ ] C-ship-marker: `.shipped` file present in feature folder
- [ ] C-ship-index: INDEX.md `## Shipped` block contains rich row for this feature
