---
playbook: feature
---

# sdd-setup verifies declared tools (closes #165)

[PHASE: SHIP]

**Active blocker:** SHIP (first action: verify-test-run)

## PHASE: SPEC

### action: brief-intake

- [x] brief: agent-authored — `/sdd-setup` records the user's tool answers in `config.md` / `stack.md` but never verifies the answers reflect reality. Failure mode (Sam, 2026-05-05 PipeLogic V2 setup): user says "I'll use CodeRabbit" but never installs the GitHub App; agent assumes CR is reviewing every PR and waits silently for reviews that never come. This ships a post-wizard `/sdd-verify-stack` action that probes each declared tool against actual state (gh-api / curl-HEAD / filesystem presence) and surfaces failures with plain-English remediation. Closes #165.

### action: problem

- [x] who: Sam first (lived through PipeLogic V2 setup gap 2026-05-05). Every downstream user who runs `/sdd-setup` and records intent (CR / Ollama / branch protection / CI workflows) without doing the install step.
- [x] why-now: `/sdd-setup` is fully wired (v1.4+) and the question-only shape is now load-bearing. The gap between "I said I'd use it" and "the tool is actually installed/reachable" is the next-highest-friction onboarding loss.
- [x] what-breaks: silent agent assumption ("CR will review this PR" but App not installed → waits 5min × 5 polls = 25 min for nothing); user blames the framework; loses trust before first SHIP completes.

### action: user-stories

- [x] stories: 2 stories — Sam wants `/sdd-verify-stack` to surface install gaps before he hits the silent-wait; downstream user wants plain-English remediation links (install URL for CR, "start ollama serve" for Tier 3) so they can fix it in one click.

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — backend-only feature (one new script + one action prose + one slash command); no UI surface.

### action: proposed-approach

- [x] approval: New `templates/.sdd/scripts/verify-stack.sh` orchestrator + `templates/.sdd/actions/verify-stack.md` action + `templates/.claude/commands/sdd-verify-stack.md` slash command; mirrored to `.sdd/` live copy + `.claude/commands/`. Probes CodeRabbit App (gh-api), Ollama endpoint (curl HEAD with 2s timeout), CI workflow file count, branch protection (gh-api). Emit `[verify-stack] <check>: <ok|warn|fail> — <message>` lines; `--json` mode for tooling. Exit 0 if no FAIL (warnings allowed); 1 if any FAIL. Gracefully skip checks when their precondition isn't set (e.g. no CR check if `parameters.review.bot` is empty). All `gh` calls degrade if `gh` not on PATH.

### action: data-contract

- [x] approval: No new project-state entities. Reads `parameters.review.bot`, `parameters.mcp.tier3.enabled`, `parameters.mcp.tier3.provider`, `parameters.mcp.tier3.endpoint` from existing `config.md`. No writes. No new framework entities — this is a behavior-only addition.

### action: flows

- [x] flows: 1 critical flow — user runs `/sdd-verify-stack` after `/sdd-setup`. Script reads config.md keys, runs 4 checks in order (CR App / Ollama / CI workflows / branch protection), prints one line per check, exits 0 or 1 based on FAIL count. Each check's precondition gates whether it runs at all.

### action: dependencies

- [x] deps: Zero new external services. Reuses existing dependencies: `gh` CLI (already required by other framework scripts), `curl` (standard), `python3` + stdlib (already pulled in by resolve-parameters.sh etc.). PyYAML soft-fail: falls back to skipping the check if PyYAML missing.

### action: out-of-scope

- [x] list: 3 deferrals — (1) deep CodeRabbit config validation (PR-level review settings); (2) auto-install (script suggests URL, doesn't install for user); (3) full per-tool probe matrix (e.g. Slack webhook, custom CI providers) — keep to the 4 most-common tools.
- [x] approval: Approved 2026-05-12.

### action: non-functional

- [x] constraints: Performance — 4 probes, each ≤2s timeout. Total run-time bounded at ~10s. Security — read-only; no writes; no secrets logged. Compliance — no PII surface; gh-api calls go to user's existing GH credentials.

### action: acceptance-criteria

- [x] approval: 6 ACs drafted (AC1-AC6), each with `{verify-by: T280-T285}` annotation.

- [ ] AC1: `templates/.claude/commands/sdd-verify-stack.md` exists with the canonical command body invoking `verify-stack.sh`. {verify-by: T280}
- [ ] AC2: `templates/.sdd/actions/verify-stack.md` exists with `model_tier: mechanical` + `requires_user_approval: false` frontmatter. {verify-by: T281}
- [ ] AC3: `templates/.sdd/scripts/verify-stack.sh` exists, executable bit set, syntax-valid bash. {verify-by: T282}
- [ ] AC4: CR check returns `ok` when mocked `gh api repos/<r>/installation` returns 200. {verify-by: T283}
- [ ] AC5: CR check returns `fail` with install URL when mocked `gh api` returns 404. {verify-by: T284}
- [ ] AC6: Workflow-file check returns `ok` when `.github/workflows/` has ≥1 `.yml` file; `warn` when missing/empty. {verify-by: T285}

### action: signoff-steps

- [x] manual-steps: 2 smokes — (1) run `/sdd-verify-stack` on this repo (which has CR + workflows) and confirm all checks pass; (2) flip `parameters.review.bot` empty and confirm CR check skips silently.

### action: wireframe

- [x] wireframe: SKIPPED — backend script + 4 plain-English log lines; no UI to wireframe.

### action: plan-decompose

- [x] tasks: 6 BUILD tasks T280-T285, one per AC.

- [x] T280: slash command file exists with correct body — AC1
- [x] T281: action file exists with correct frontmatter — AC2
- [x] T282: verify-stack.sh exists, executable, syntax-OK — AC3
- [x] T283: CR check returns ok on mocked 200 — AC4
- [x] T284: CR check returns fail on mocked 404 — AC5
- [x] T285: workflow file count check works — AC6

### action: edge-case-sweep

- [x] ec-sweep: 4 candidates surveyed — gh not installed (graceful skip), curl not installed (graceful skip for Ollama), config.md missing (exit 1 with clear message), malformed config.md frontmatter (PyYAML parse error → fall back to skipping checks).
- [x] ec-pick: All 4 addressed inline in verify-stack.sh (no new ACs needed — defensive paths in the script body).

### Exit checks
- [x] C-spec-acs: ≥1 acceptance criterion exists in §11
- [x] C-spec-tasks: ≥1 task in plan-decompose section

## PHASE: BUILD

### action: build-task

- [x] tasks: All 6 BUILD tests T280-T285 wired into test/run-framework-test.sh; all GREEN locally.

## PHASE: SHIP

### action: verify-test-run

- [ ] tests: run framework test sweep one more time + push branch + open PR
