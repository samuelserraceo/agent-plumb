---
playbook: feature
---

# ship hard-enforce CodeRabbit convergence closes 166 {verify-by: T272}

[PHASE: BUILD]

**Active blocker:** none — BUILD running.

## PHASE: SPEC

### action: brief-intake

- [x] brief: from GH issue #166 + Sam's pre-assignment prompt for F026 in this session. Issue body verbatim: "SDD has doctrine for handling CodeRabbit reviews but no mechanical enforcement at /ship time. The agent can forget to wait for CR, forget to nudge, or address findings inadequately — and `/ship`'s `verify-ci-green` check passes regardless because CI ≠ CR. PRs #158 and #161 both merged with CR review state showing CHANGES_REQUESTED."

### action: problem

- [x] who: Sam (and any SDD downstream using a CR bot in `parameters.review.bot`). When `/ship` runs `verify-ci-green` and proceeds to `mark-shipped`, no machine check has read CodeRabbit's `reviewDecision` on the latest commit SHA.
- [x] why-now: live in v1.4.x release sequence PRs #158 and #161 both merged under admin-merge with CR showing `CHANGES_REQUESTED`. The behavioural rule (`feedback_coderabbit_nudge.md`) does not bind the framework; only a script does.
- [x] what-breaks: CR-flagged Critical/Major findings ship to main without a paper trail; v1.4.x admin-merge pattern repeats; `/ship` mark-shipped's `requires_user_approval: false` lets autonomous tier flip the marker file silently.

### action: user-stories

- [x] stories: As an SDD operator running `/ship`, I want the framework to halt at `mark-shipped` when CodeRabbit's review on the latest SHA is `CHANGES_REQUESTED` {verify-by: T272}, so I don't silently ship past unresolved CR findings. As a downstream framework user who has not configured a CR bot, I want this check to skip cleanly, so I can keep shipping without a phantom dependency. As a project owner with a one-off legitimate bypass, I want a `parameters.review.bypass_cr_convergence: true` lever, so I can ship after I've recorded the override in `decisions.md`.

### action: ux-brief

- [x] brief: zero new UI. Two surfaces: (a) the action prose in `.sdd/actions/verify-cr-convergence.md` (read by the agent during SHIP); (b) the script's stderr line on exit-1 (one plain-English sentence naming the PR + the review SHA + the `bypass_cr_convergence` lever) {verify-by: T272}.

### action: proposed-approach

- [x] approval: SHIP-stage action between `verify-ci-green` and `mark-shipped`. Action body = "run `check-cr-convergence.sh`, tick the box on green, halt on red." Script reads `parameters.review.bot` from `.sdd/config.md`; empty → exit 0 (skip — projects without CR are clean). Reads `parameters.review.bypass_cr_convergence`; true → exit 0 (announce + skip). Otherwise:
  1. Read PR number from `.sdd/<active-feature>/.pr-number` (already written by `push-pr` action — verified) OR fall back to `gh pr view --json number -q .number` against the current branch.
  2. Read the latest commit SHA via `git rev-parse HEAD`.
  3. Call `gh api repos/{owner}/{repo}/pulls/{num}/reviews --paginate -q '...'` and find the latest review on that SHA from the configured bot login.
  4. If review state is `APPROVED` → exit 0.
  5. If review state is `COMMENTED` (CR's "I looked, no changes needed") → exit 0.
  6. If review state is `CHANGES_REQUESTED` on the latest SHA → exit 1 with plain-English stderr explaining how to either push the fix or set the bypass flag.
  7. If no review exists on the latest SHA → exit 1 with stderr suggesting `@coderabbitai full review` nudge.
  Tradeoff vs full nudge-loop: ship the gate first (the load-bearing piece), defer the auto-nudge poll loop to a follow-up. Issue #166's "don't ship until 2-3 more PRs show the failure mode" caveat applies to the polish, not the gate — the gate is the minimum that blocks the v1.4.x admin-merge pattern from recurring {verify-by: T272}.

### action: data-contract

- [x] approval: new config field `parameters.review.bypass_cr_convergence: false` (boolean, default false). No new entity. Schema additions on `verification.json`: none. The `.pr-number` file already lives at `.sdd/<feature>/.pr-number` per `push-pr` action.

### action: flows

- [x] flows: 4 critical flows — happy / refused / skip-no-bot / bypass — covering every branch the `check-cr-convergence.sh` gate runs.
  1. **Happy path** — operator runs `/ship`. `push-pr` opens PR, `verify-ci-green` polls until green, `verify-cr-convergence` runs `check-cr-convergence.sh`. CR has APPROVED on the latest SHA → script exits 0, action ticks its box, agent proceeds to `mark-shipped`.
  2. **Refused path** — CR review state is CHANGES_REQUESTED on the latest SHA. Script exits 1 with stderr: "verify-cr-convergence: CodeRabbit review state CHANGES_REQUESTED on commit <SHA>. Either push a fix that resolves the findings, or set `parameters.review.bypass_cr_convergence: true` in `.sdd/config.md` (and record the override in `decisions.md`)." Action halts {verify-by: T272}. mark-shipped does not fire {verify-by: T272}.
  3. **Skip path (no bot)** — `parameters.review.bot: ""` (empty). Script exits 0 immediately with one stderr line "verify-cr-convergence: skipped — parameters.review.bot is empty." No gh-api call.
  4. **Bypass path** — `parameters.review.bypass_cr_convergence: true`. Script exits 0 with stderr "verify-cr-convergence: bypassed — parameters.review.bypass_cr_convergence is true. Record the rationale in decisions.md." No gh-api call (no point — operator already opted out).

### action: dependencies

- [x] deps: `gh` CLI (already a hard SDD dep — every action that touches PRs uses it). `git` (already a hard SDD dep). `awk`, `grep` (bash 3.2 compat — already used across `.sdd/scripts/`). No new external services, no pricing math.

### action: out-of-scope

- [x] list: 4 explicit deferrals — auto-nudge poll loop, cr-decisions.md per-finding ledger, CLAUDE.md doctrine subsection, Critical-only refusal logic.
  - **Auto-nudge poll loop** — the "wait + post `@coderabbitai full review` after N minutes" sub-feature of issue #166. Reason: deferred per the issue's "don't ship until 2-3 more PRs show the failure mode" caveat; ship the gate first.
  - **`cr-decisions.md` per-finding ledger** — the issue suggests a separate file enumerating each CR finding with `resolved-as-stale-finding / resolved-by-commit-X / accepted-with-tradeoff`. Reason: the gate first; the ledger is doctrine on top of the gate. Add later if downstream projects need it. Bypass + `decisions.md` row is the v1 escape hatch.
  - **CLAUDE.md "CR convergence rules" subsection** — the issue's doctrine half. Reason: deferred. The action prose carries the operator-facing rule; the durable doctrine update lands when 2-3 PRs have run through the new gate.
  - **Critical-only refusal logic** — refusing only when CR has unresolved Critical/Major comments while APPROVED. Reason: API surface is messier; the v1 gate uses GitHub's `reviewDecision` directly which is the canonical signal. Re-visit if false-positive rate is high.
- [x] approval: user_approves

### action: non-functional

- [x] constraints: bash 3.2 compat; tests mock gh via PATH-prepend; anti-theatre lint passes; script idempotent; exit codes 0=pass, 1=refused, 2=usage; plain-English stderr.
  - Bash 3.2 compat (macOS default).
  - Tests mock `gh api` via PATH-prepend (so no real GitHub calls during framework-test run).
  - Anti-theatre lint passes (every numerical/enforcement claim verifiable; "checks CR" must be true after running the script, not just prose).
  - Script must be idempotent (re-running on same PR + same SHA returns the same exit code).
  - Exit codes: 0 = pass (or skip / bypass), 1 = refused, 2 = usage error.
  - Refusal stderr is one plain-English sentence + escape-hatch hint (Sam's plain-English doctrine).

### action: acceptance-criteria

- [x] approval: 6 ACs (AC1-AC6) — file presence, playbook position, 4 exit-code paths (refused / approved / skip / bypass).
- [ ] AC1: `.sdd/actions/verify-cr-convergence.md` + `templates/.sdd/actions/verify-cr-convergence.md` exist with frontmatter (`type: action`, `slug: verify-cr-convergence`, `tag: AGENT-LED`, `model_tier: mechanical`, `trust: framework`). {verify-by: T270}
- [ ] AC2: `templates/.sdd/playbooks/feature.md` lists `verify-cr-convergence` in the SHIP stage's `actions:` list, positioned exactly between `verify-ci-green` and `mark-shipped`. Live mirror matches. {verify-by: T271}
- [ ] AC3: `check-cr-convergence.sh` exits 1 when the mocked CR review state is `CHANGES_REQUESTED` on the latest SHA. {verify-by: T272}
- [ ] AC4: `check-cr-convergence.sh` exits 0 when the mocked CR review state is `APPROVED` on the latest SHA. {verify-by: T273}
- [ ] AC5: `check-cr-convergence.sh` exits 0 (skip path) when `parameters.review.bot` is empty in `.sdd/config.md`. {verify-by: T274}
- [ ] AC6: `check-cr-convergence.sh` exits 0 (bypass path) when `parameters.review.bypass_cr_convergence: true` in `.sdd/config.md`. {verify-by: T275}

### action: signoff-steps

- [x] manual-steps: 2 manual smokes {best-effort: Sam at SHIP} — confirm new gate fires on this PR's first /ship; confirm /ship flow does not regress for downstream projects with `parameters.review.bot: ""`.
  - Confirm `gh pr view` on this PR shows CR convergence working through the new gate the first time it runs (post-merge real-session walk).
  - Confirm `/ship` flow doesn't regress on a feature that has `parameters.review.bot: ""` (downstream-no-CR shape).

### action: wireframe

- [x] wireframe: non-UI feature. Flow shape:

```
/ship           push-pr  →  verify-ci-green  →  verify-cr-convergence  →  mark-shipped
                                                       │
                                                       ├─ bot empty?       → exit 0 (skip)
                                                       ├─ bypass true?     → exit 0 (bypass)
                                                       ├─ APPROVED on SHA? → exit 0 (pass)
                                                       ├─ COMMENTED on SHA? → exit 0 (pass)
                                                       └─ CHANGES_REQUESTED on SHA?
                                                                           → exit 1, stderr names bypass + decisions.md route
```

### action: plan-decompose

- [x] tasks: 6 ordered T-tasks T270-T275 — file + frontmatter, playbook insertion, 4 exit-code paths.
- [ ] T270: action file + frontmatter — write `.sdd/actions/verify-cr-convergence.md` and `templates/.sdd/actions/verify-cr-convergence.md` with the required frontmatter shape. Test asserts both files exist + grep finds required keys. {verify-by: tests/task-270*}
- [ ] T271: playbook insertion — edit `.sdd/playbooks/feature.md` + `templates/.sdd/playbooks/feature.md` SHIP `actions:` block to add `verify-cr-convergence` between `verify-ci-green` and `mark-shipped`. Test asserts ordering in both files. {verify-by: tests/task-271*}
- [ ] T272: refused path — `check-cr-convergence.sh` exits 1 with mocked CHANGES_REQUESTED on latest SHA. {verify-by: tests/task-272*}
- [ ] T273: approved path — exits 0 with mocked APPROVED. {verify-by: tests/task-273*}
- [ ] T274: skip path — exits 0 when `parameters.review.bot: ""`. {verify-by: tests/task-274*}
- [ ] T275: bypass path — exits 0 when `parameters.review.bypass_cr_convergence: true`. {verify-by: tests/task-275*}

### action: edge-case-sweep

- [x] ec-sweep: (a) PR number unfetchable (no `.pr-number` file, no current branch attached to a PR) — script falls back to `gh pr view --json number` and on failure exits 2 (usage error) so the operator gets a clear message rather than a stuck wait; (b) gh api returns malformed JSON — script defends with `set -uo pipefail` + grep-only parsing, treats parse failure as "no review found on latest SHA" → exit 1 with stderr suggesting the manual route; (c) latest commit SHA changed between `verify-ci-green` and `verify-cr-convergence` (operator pushed mid-flow) — the gate reads SHA at runtime so the new commit is the one checked, which is correct; (d) bot name case (CR posts as `coderabbitai[bot]` not `coderabbitai`) — script normalises by matching either form via grep.
- [x] ec-pick: (d) — the bot-name case difference is the most likely live failure mode. Test T273 explicitly uses the `coderabbitai[bot]` login in the fixture JSON so the matcher is locked.

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full-autonomous (per Sam's prefs)

### action: build-task

- [ ] task-loop: walk T270 → T275 RED-GREEN per task, commit per task.

## PHASE: SHIP

(scaffolded at phase-transition)
