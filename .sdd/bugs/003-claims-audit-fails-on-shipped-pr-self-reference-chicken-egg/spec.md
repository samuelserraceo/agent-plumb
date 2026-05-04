# claims-audit fails on shipped-PR self-reference (chicken-egg)

[PHASE: SHIPPED]

**Active blocker:** SHIPPED.

## PHASE: SPEC

### action: bug-problem

- [x] what: `test/run-claims-audit.sh` claim `claim_shipped_pr_links_merged` fails on every PR's CI run whenever that PR is the one shipping a feature — the INDEX.md ## Shipped row added in the same PR points at the PR's own number, which is still OPEN at audit time. Symptom: 1/31 claims fails, CI red, merge needs admin override. First bit feature 006 / PR #153 (the first shipped PR after the audit harness landed in commit 80a47e2).

### action: bug-repro

- [x] steps: 1. /start a feature, walk SPEC + BUILD + SHIP. 2. mark-shipped writes a `## Shipped` row into INDEX.md with the still-OPEN PR's URL. 3. Push the mark-shipped commit. 4. CI re-runs `test/run-claims-audit.sh`. 5. The claim iterates `## Shipped` PR URLs, calls `gh pr view <num> --json state` for each — the just-added one returns `OPEN`. 6. Claim returns non-zero, CI is red. Concrete instance: PR #153 commit `2f1a130` mark-shipped → claims-audit failed with stderr `Shipped PRs not in MERGED state: #153 (state=OPEN)`.

### action: bug-root-cause

- [x] cause: the claim's iterator at `test/run-claims-audit.sh:750-794` (`claim_shipped_pr_links_merged`) treats every PR URL in `## Shipped` as needing MERGED state, with no exemption for "the PR currently being CI'd." On PR CI, that PR is OPEN by definition — so any PR that adds its own row in `mark-shipped` flunks the claim. Approved by Sam on 2026-05-04.

### action: bug-fix

- [x] approval: in `claim_shipped_pr_links_merged`, derive the current-PR-being-CI'd from GitHub Actions env vars (`$GITHUB_REF` matches `refs/pull/<num>/merge` on PR runs; or `$GITHUB_EVENT_NAME == 'pull_request'` + `$GITHUB_REF_NAME` carries the head). When iterating shipped PRs, skip the entry whose PR number equals the current one — that PR will be MERGED post-merge by definition. Files touched: `test/run-claims-audit.sh` (the claim function only). Approved by Sam on 2026-05-04.

### action: bug-regression-test

- [x] approval: T159 in `test/run-framework-test.sh` simulates the CI scenario — exports `GITHUB_REF=refs/pull/153/merge`, writes a temp INDEX.md whose ## Shipped row points at PR #153, runs `claim_shipped_pr_links_merged` from a stubbed environment (or shell wrapper that intercepts gh calls). Asserts: with the env var set, the claim returns 0; without it, the claim still calls gh for every PR (legacy behaviour). Approved by Sam on 2026-05-04. → tests captured in test/run-framework-test.sh T159

### Exit checks
- [x] C-spec-repro: repro steps captured in §2
- [x] C-spec-cause: root cause captured in §3
- [x] C-spec-fix: proposed fix recorded in §4
- [x] C-spec-regression: regression test drafted in §5


## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full autonomous — single-task bug, runs to GREEN.

**Run mode:** full-autonomous

### action: build-task

- [x] T01 GREEN: Fix landed. `claim_shipped_pr_links_merged` now reads `$GITHUB_REF` (shape `refs/pull/<num>/merge`), extracts the current PR number, and skips that entry during iteration. Source-guard added at top of `run-claims-audit.sh` so test harnesses can source the script without triggering the orchestrator (or the cd to PROJECT_ROOT). T159 added (216/216 framework tests passing); standalone audit run passes 31/31. → tests captured in test/run-framework-test.sh T159

### Exit checks
- [x] C-build-tasks-green: T01 GREEN (216/216 framework tests, 31/31 claims audit).

## PHASE: SHIP

### action: verify-test-run

- [x] run-tests: bash test/run-framework-test.sh → 216/216; bash test/run-claims-audit.sh → 31/31.

### action: learn

- [x] summary: shipped a one-line fix to the claims-audit harness — PR being CI'd is now exempted from the merged-state check, closing the chicken-egg that bit feature 006's PR #153.
- [x] lessons: appended a pattern to .sdd/patterns.md — claims that fire on PR CI must exempt the PR being reviewed from any "is this merged?" predicate, otherwise mark-shipped self-references fail until merge but merge is gated on CI passing.

### action: push-pr

- [x] push-and-open: branch pushed; PR https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/154 opened.

### action: verify-ci-green

- [x] ci: 6/6 CI checks GREEN on PR #154 cycle 3 — Browser (1m10s), Claims audit (1m59s), CR (review completed), Framework tests (1m31s), Graph (10s), Scope (7s). The fix's own claim audit passes — meta-validation that the chicken-egg is closed.

### action: mark-shipped

- [x] shipped: INDEX.md updated, .shipped marker written, decisions.md appended.

### Exit checks
- [x] C-ship-pr-url: PR https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/154 recorded in INDEX.md Shipped section
- [x] C-ship-marked: .shipped marker file exists in bug folder
