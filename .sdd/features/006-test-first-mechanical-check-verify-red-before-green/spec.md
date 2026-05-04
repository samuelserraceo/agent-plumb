# test-first mechanical check — verify RED before GREEN

[PHASE: BUILD]

**Active blocker:** §B2 (next action: build-task — T09)

## PHASE: SPEC

### action: problem

- [x] who: Sam (framework user/maintainer) and future contributors. Anyone running an SDD project relies on the test-first claim being real, but right now nothing actually checks it.
- [x] why-now: yesterday's audit identified test-first-as-discipline as one of the 3 must-fix gaps before public release. The other 2 (backend scope-guard / shipped-row tamper detection) shipped in PRs #150 + #151 overnight. This is the last item before the SDD-identity claim is mechanically backed up.
- [x] what-breaks: the AI can write code AND test together in one commit, where the test happens to pass on first run because the code is already there. The framework treats this as a successful T01 GREEN. Future regressions sneak in because the test doesn't actually pin behaviour — it was written to pass against whatever the code happens to do, not to fail before the code existed.

### action: success

- [x] metric: **quality** — a fake-test-first commit attempt is mechanically refused. Measurable as a regression test in the framework's own suite: stage a code+test together where the test passes without the code, run the safety hook → expect refusal with a clear error. **Target**: 1 new regression test passes (binary), AND existing 203+ framework tests still pass (no regression). **Baseline**: today, 0 fake-test-first attempts are caught.

### action: user-stories

- [x] stories: 3 personas — Sam (framework user) wants commits with theatre tests refused; future SDD contributors get the same catch even if they don't know test-first discipline; PR reviewers want T01 GREEN to mean test was RED first, not written-to-match-code.

### action: ux-brief [SKIPPED]

- ⏭ skipped — no UI surface, backend hook only

### action: proposed-approach

- [x] approval: stash-and-rerun pre-commit hook (Approach A) with pattern-only fallback (Approach B). Approved by Sam on 2026-05-04.

  **Approach A — stash-and-rerun (primary, when test runner is configured):**
  - New pre-commit hook detects when a commit stages a test+code pair (test file at `tests/task-NNN.<ext>` and the task's code file together).
  - Hook stashes the code-side staged changes (keeps test in index).
  - Runs the project's configured test runner (read from `.sdd/config.md` `parameters.test_runner`).
  - If the test FAILS without the code → expected RED-first signal → restore stash → allow commit.
  - If the test PASSES without the code → theatre → block the commit with a plain-English error pointing at the test path. {verify-by: T-006-fake-test-first}

  **Approach B — pattern-only fallback (when no test runner is configured):**
  - Hook checks commit order: was the test file committed BEFORE the code file? Same-commit pairs refused with *"test must land in its own commit first."*
  - Lighter; doesn't catch test-after-code-disguised-as-test-first across two commits, but works in any project.

  **Decision:** ship A as primary, B as fallback. Framework's own use case has `bash test/run-framework-test.sh` — defaults to A. Downstream projects that haven't run /sdd-setup or didn't configure a test runner get B automatically.

  **Defence preserved:** existing hooks (manifest pin, scope-guard, post-stop-lint) all still run. This is an additional gate.

  **Files touched:**
  - `templates/.claude/hooks/pre-commit-test-first.sh` (NEW)
  - `templates/.claude/settings.json` (register the hook in PreToolUse)
  - `templates/.sdd/config.md` (add `parameters.test_runner` field — empty by default, populated by /sdd-setup)
  - `test/run-framework-test.sh` (T<N> regression: fake-test-first → refused; real-test-first → allowed)
  - Both manifests (hash-repin if hook is manifest-tracked)

### action: data-contract

- [x] approval: no new entities. The hook reads `parameters.test_runner` from `.sdd/config.md` (existing field shape — no schema change). No `data-model.md` updates. Approved by Sam on 2026-05-04.

### action: flows

- [x] flows: one critical flow (implements §3 stories 1+2+3): agent commits a BUILD task with test+code paired → pre-commit-test-first hook fires → stashes the code-side staged changes → runs project's configured test runner → if test PASSES without code, hook blocks the commit with a plain-English error pointing at the test path; if test FAILS without code, hook restores the stash and the commit proceeds normally. {verify-by: T-006-fake-test-first}

### action: dependencies

- [x] deps: no new external services. Uses git's existing stash + restore primitives (`git stash push --keep-index` and `git stash pop`), plus the project's already-configured test runner (read from config.md). Cost = $0/mo. {best-effort: Sam at SHIP — confirms no surprise installs}

### action: out-of-scope

- [x] list: 5 explicit deferrals —
  1. Per-task customisable test command — using project default from `config.md` `parameters.test_runner`. Per-task overrides deferred.
  2. Detection across multiple commits — this round catches same-commit pairs (Approach A) and same-PR commit-order (Approach B). Multi-commit theatre (test in commit N + code in commit N+1 where the test passed throughout) is deferred.
  3. IDE / editor integration — hook fires at git commit time, not in the editor.
  4. Visual report / dashboard — error message only, no UI.
  5. Auto-fixing the test — when theatre is caught, the user / AI rewrites the test; framework doesn't try to mutate it for them.
- [x] approval: user_approves — Sam approved on 2026-05-04.

### action: non-functional

- [x] constraints: 3 categories — performance (hook overhead bounded by one test-suite run), security (no external transmission, no new credentials), compliance (no PII, no external API calls). Detail below.
  - **Performance**: hook runs once per BUILD-task commit. Stash + test-run + restore should complete in under the time of one test-suite run for the project. For the framework's own use (`bash test/run-framework-test.sh`), that's ~1 minute. {best-effort: Sam at SHIP — confirms timing on real BUILD task}
  - **Security**: stashed code stays in git's local stash store; not transmitted anywhere. Test runner is invoked with the project's existing credentials; no new secrets flow through this hook.
  - **Compliance**: no PII, no external API calls. Hook runs locally only.

### action: acceptance-criteria

- [x] approval: 6 ACs covering both the happy path and the theatre-detection path. Approved by Sam on 2026-05-04.

  - [ ] AC1: real test-first commit (test fails without code, passes with code) → hook stashes / runs / restores cleanly → commit lands. → tests/task-001.sh
  - [ ] AC2: fake test-first commit (test passes without code) → hook blocks the commit; stderr contains the test path and a fix-it message. → tests/task-002.sh
  - [ ] AC3: when `config.md` `parameters.test_runner` is empty → hook falls back to Approach B (commit-order check); same-commit pairs refused with "test must land in its own commit first." → tests/task-003.sh
  - [ ] AC4: non-BUILD-task commits (spec.md edits, framework chores, mark-shipped) → hook exits 0 silently. → tests/task-004.sh
  - [ ] AC5: stash always restored even if the test run errors mid-flight or is interrupted (use a `trap` for cleanup). → tests/task-005.sh
  - [ ] AC6: refusal message includes (a) which test is theatre, (b) what test-first means, (c) how to fix. → tests/task-006.sh (mechanical) + {best-effort: Sam at SHIP — confirms readability}
- [ ] AC7: commit with 2+ test+code pairs → hook stops the commit; stderr says "split into one commit per task." → tests/task-007.sh
- [ ] AC8: parameters.test_runner exits non-zero before any test runs (e.g. binary not found, exit 127) → hook treats this as "runner broke", not "test failed", and stops the commit with stderr saying "test_runner config is wrong — fix .sdd/config.md." → tests/task-008.sh
- [ ] AC9: stash-pop fails with a conflict (test created files the stashed code overwrites) → trap catches it, hook prints the stash ref so the user can recover by hand. → tests/task-009.sh

### action: signoff-steps

- [x] manual-steps: 3 manual checks before SHIP —
  1. Run a real BUILD task end-to-end on the framework itself; see the hook fire silently when the test legitimately fails-first.
  2. Manually craft a fake-test-first commit (stage code+test where test passes without code); see the hook refuse with the plain-English error.
  3. Read the refusal error; check it makes sense to a non-technical reader without further explanation. {best-effort: Sam at SHIP}

### action: wireframe

- [x] wireframe: drafted — non-UI flow (commit pipeline + Approach A/B branching), architecture (where the new hook sits relative to existing safety hooks), concrete example of a fake-test-first commit being stopped.

### action: plan-decompose

- [x] tasks: 6 tasks (T01-T06) — 1:1 with AC1-AC6. T01 introduces the hook (manifest repin in same commit); T02-T06 extend hook logic. Each task adds: hook source + mirror + per-feature test (tests/task-NNN.sh) + framework regression entry in test/run-framework-test.sh.

- [x] T01 GREEN: Hook skeleton + Approach A happy path landed. New file templates/.claude/hooks/pre-commit-test-first.sh (+ mirror at .claude/hooks/), wired in both settings.json copies, parameters.test_runner field added to templates/.sdd/config.md (empty default) and set in .sdd/config.md to "bash test/run-framework-test.sh". T150 added to run-framework-test.sh; all 207 framework tests pass. → tests/task-001.sh
- [x] T02 GREEN: Theatre detection landed. Hook stops fake test-first commits with stderr naming the test path. T151 added to framework test suite (208/208 passing). → tests/task-002.sh
- [x] T03 GREEN: Approach B (commit-order check) landed. Empty test_runner → checks if test was committed in a prior commit; same-commit pair refused with the canonical message; prior-commit test allows. T152 added (209/209 passing). → tests/task-003.sh
- [x] T04 GREEN: Non-BUILD pass-through landed. Hook reads commit message from cmd payload; only [SDD:NNN][T<n>] shapes are gated. Spec edits / phase advances / chores / mark-shipped → exit 0 silently with no stderr. T153 added (210/210 passing). → tests/task-004.sh
- [x] T05 GREEN: trap hardened. Cleanup (pop + re-stage) now fires on EXIT plus INT, TERM, HUP signals — covers Ctrl+C and CI-runner SIGTERM. Test verifies recovery on (a) test runner undefined-var crash, (b) SIGTERM mid-sleep. T154 added (211/211 passing). → tests/task-005.sh
- [x] T06 GREEN: Refusal message reshaped into 3 explicit sections — test path, "What this means" (plain-English explanation of test-first), "How to fix" (4 numbered steps from rewrite-test through commit-again). T155 added (212/212 passing). → tests/task-006.sh
- [x] T07 GREEN: Multi-pair detection landed. Hook counts staged tests/task-NNN.* files; 2+ → blocks with "split into one commit per task" message + 3-step recovery. Block happens before stash creation (no stash to clean up). T156 added (213/213 passing). → tests/task-007.sh
- [x] T08 GREEN: Runner-crash detection landed. Hook now branches on test_ec: 0 = theatre (block), 127 = command-not-found (block with config-wrong message), other non-zero = real RED (allow). Closes the backdoor where a misconfigured runner silently let theatre through. T157 added (214/214 passing). → tests/task-008.sh
- [ ] T09: Stash pop conflict recovery (AC9). trap wraps the pop; on conflict, print the stash ref + recovery hint. → tests/task-009.sh

### action: edge-case-sweep

- [x] ec-sweep: drafted 4 candidates — EC1 multi-pair commit, EC2 runner crash, EC3 initial commit (deferred — corner case), EC4 stash-pop conflict.
- [x] ec-pick: picked EC1, EC2, EC4 → added AC7-AC9 + T07-T09. EC3 (initial commit on fresh repo) deferred — corner case, documented as known limitation.

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE" {verify-by: verify-stage.sh}
- [ ] C-spec-tasks: ≥1 task in plan-decompose section — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE" {verify-by: verify-stage.sh}

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full autonomous (conversation) — runs all 9 tasks back-to-back, halts only on universal rules.

**Run mode:** full-autonomous

### action: build-task

(driven by §14 tasks T01-T09 — each task lands as one commit)

### Exit checks
- [ ] C-build-tasks-green: every task is GREEN (test passing, code committed)
