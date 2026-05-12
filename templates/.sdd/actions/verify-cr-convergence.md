---
type: action
slug: verify-cr-convergence
tag: AGENT-LED
model_tier: mechanical
title: "verify-cr-convergence"
short_label: "CR converged"
steps:
  - { id: poll-cr, action: "run check-cr-convergence.sh; halt if CR review state is CHANGES_REQUESTED on the latest SHA", field: "§verify-cr-convergence" }
used_by: [feature, bug, refactor]
references: [push-pr, verify-ci-green]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 10
  max_tokens: 1000
  max_commits: 1
requires_user_approval: false
---

Check that CodeRabbit's review on the latest commit has converged — APPROVED or COMMENTED — before letting `mark-shipped` flip the `.shipped` marker. Closes the gap issue #166 documented: `/ship`'s `verify-ci-green` action passes on green CI even when CR has posted `CHANGES_REQUESTED` on the latest SHA. CI ≠ CR.

**Action:** run `bash .sdd/scripts/check-cr-convergence.sh`. The script reads `parameters.review.bot` and `parameters.review.bypass_cr_convergence` from `.sdd/config.md`, finds the PR number from `.sdd/<active>/.pr-number` (written by `push-pr`), reads the latest SHA via `git rev-parse HEAD`, queries `gh api repos/<owner>/<repo>/pulls/<num>/reviews`, and exits 0 on pass / 1 on refused / 2 on usage error.

**What the script checks:**

1. **Skip** — if `parameters.review.bot` is empty, exit 0 (downstream project without a CR bot — nothing to gate on).
2. **Bypass** — if `parameters.review.bypass_cr_convergence: true`, exit 0 (operator opted out; rationale belongs in `decisions.md`).
3. **Pass** — the latest review from the configured bot on the latest SHA is `APPROVED` (or `COMMENTED` — CR's "I looked, no changes" state).
4. **Refused** — the latest review on the latest SHA is `CHANGES_REQUESTED`, or no review on the latest SHA at all.

**If PASS (exit 0):** tick `**CR converged:** [x]` in spec.md under `### verify-cr-convergence` and continue.

**If REFUSED (exit 1):** the script prints a plain-English stderr naming the PR + the review SHA + the bypass lever. HALT. Two recovery routes:

- Push a fix that resolves the CR findings, then re-run `/next` — the script reads the new HEAD SHA and re-checks.
- If the findings are genuinely declinable (stale review, append-only constraint, intentional trade-off), set `parameters.review.bypass_cr_convergence: true` in `.sdd/config.md` AND append a row to `.sdd/decisions.md` explaining the bypass. Same precedent as F009 / F010's `decisions.md` audit-log discipline for any admin-merge.

**If USAGE ERROR (exit 2):** the script couldn't find a PR number or `gh` is unauthenticated. Fix the underlying issue (`/start` writes `.pr-number` at `push-pr`; `gh auth login` for auth) and re-run.

**Output:** fill `spec.md` under `### verify-cr-convergence` with `**CR converged:** [x]`.

**What it looks like:**

Watch CodeRabbit's review on the PR. If it's APPROVED, tick the box. If it's CHANGES_REQUESTED, halt — either push a fix or set the bypass flag and log the rationale.

Example: *"Reading the latest review state from CR on commit aaaa1234. APPROVED — converged. Ticking the box."* Or: *"CR posted CHANGES_REQUESTED on aaaa1234 — I can't mark this shipped. Either push a fix or set `parameters.review.bypass_cr_convergence: true` and log the bypass in decisions.md."*

**End the turn with:** `CR converged.` (or REFUSED details if exit 1). On GREEN: *"Run `/next` to mark shipped."*
