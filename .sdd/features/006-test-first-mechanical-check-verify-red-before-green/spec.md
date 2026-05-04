# test-first mechanical check — verify RED before GREEN

[PHASE: SPEC]

**Active blocker:** §14 (next action: plan-decompose)

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

### action: signoff-steps

- [x] manual-steps: 3 manual checks before SHIP —
  1. Run a real BUILD task end-to-end on the framework itself; see the hook fire silently when the test legitimately fails-first.
  2. Manually craft a fake-test-first commit (stage code+test where test passes without code); see the hook refuse with the plain-English error.
  3. Read the refusal error; check it makes sense to a non-technical reader without further explanation. {best-effort: Sam at SHIP}

### action: wireframe

- [x] wireframe: drafted — non-UI flow (commit pipeline + Approach A/B branching), architecture (where the new hook sits relative to existing safety hooks), concrete example of a fake-test-first commit being stopped.

### action: plan-decompose

- [ ] tasks: convert acceptance criteria into ordered build tasks (one test file per task)

### action: edge-case-sweep

- [ ] ec-sweep: draft
- [ ] ec-pick: ask

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE" {verify-by: verify-stage.sh}
- [ ] C-spec-tasks: ≥1 task in plan-decompose section — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE" {verify-by: verify-stage.sh}
