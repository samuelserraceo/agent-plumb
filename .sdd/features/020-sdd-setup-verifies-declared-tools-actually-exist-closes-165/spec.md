---
playbook: feature
---

# sdd-setup verifies declared tools actually exist (closes #165)

[PHASE: SPEC]

**Active blocker:** §1 (first action: brief-intake)

## PHASE: SPEC

### action: brief-intake

- [x] brief: Sam-authored GitHub issue #165 (captured 2026-05-08, lived during PipeLogic V2 setup 2026-05-05) is the brief source. Pattern: `/sdd-setup` asks plain-English questions, records answers in stack.md/config.md, then moves on — there is no follow-up step that verifies the answers reflect reality. Failure mode lived during PipeLogic V2 install: user says "I'll use CodeRabbit" but had not installed the App; agent waited silently for reviews that did not arrive. Issue spec'd 6 concrete verify steps for a new post-wizard action `/sdd-verify-stack`: (1) CR App installed via `gh api repos/.../installation`; (2) Copilot review via gh api; (3) branch-protection on main matches declared required-checks; (4) required CI workflow files exist for declared job names; (5) Tier 3 LLM provider reachable (Ollama curl probe, OpenAI key env-var presence); (6) test runner deps present in package.json. Pre-fills §1 (who/why-now/what-breaks) + §3 (user-stories) + §5 (proposed-approach as a sketch only, awaiting your alternatives review) + §9 (out-of-scope deferrals already in issue body).

### action: problem

- [x] who: First-time SDD installers running `/sdd-setup` on a fresh project. Sam felt it during the PipeLogic V2 install (2026-05-05) when he answered "CodeRabbit" for reviewer but had not actually installed the GitHub App — agent then waited silently for reviews on subsequent PRs. Future adopters hit the same shape across Ollama / branch-protection / required CI checks / Tier 3 provider / test-runner deps.
- [x] why-now: Existing `feedback_setup_help_v12.md` memo flagged the Ollama-install gap a week ago. Issue #165 generalises that to 6 concrete tool classes (CR app, Copilot, branch protection, CI checks, Tier 3 provider, test runner). The plugin install-experience just got documented in PR #251 (cache cleanup README section) — natural pairing to add post-wizard verification on top of clean install. Without it, first-time installers silently misconfigure and discover the gap later when the agent's behaviour is mysterious.
- [x] what-breaks: Three concrete failure modes lived during PipeLogic V2 install. (1) User answered "CodeRabbit" for reviewer but had not installed the GitHub App; agent waited silently on every PR for reviews that did not arrive. (2) User said "Ollama for Tier 3" but had not pulled the model; agent's first MCP call failed with a cryptic upstream error. (3) Brief committed to "required CI checks: typecheck/test/build" but the repo had no matching workflow files; branch protection later refused merges with no plain-English path forward. Pattern across all six issue-listed checks: declared answer + no-real-thing = silent agent confusion.

**Who has this problem:** First-time SDD installers running `/sdd-setup`. Lived by Sam on PipeLogic V2 (2026-05-05). Future adopters following the published install path hit the same shape because the wizard records intent without verifying reality.

**Why now:** The plugin install path itself just got tightened in PR #251 (cache cleanup section). The wizard works for the happy path; the gap that remains is post-wizard reality-check. The `feedback_setup_help_v12.md` memo (one-week-old) flagged the Ollama case; issue #165 generalises to 6 tool classes. No new dependency needed — `gh api` and `curl` already in stack.

**What breaks if we do not solve it:**

1. **CodeRabbit answered but not installed.** Agent runs `/ship`, waits 15 min for review, nudges with `@coderabbitai full review`, times out, falls through to "no reviewer, proceeding" path. Sam's the one who pays — gets a merged PR with zero review, then a confused-looking commit history weeks later when someone asks "why no CR comments on this one?".
2. **Ollama answered but model not pulled.** Agent makes first MCP tier 3 call, gets `model not found`, surfaces a cryptic error. New adopter doesn't know whether their config is wrong or the framework is broken.
3. **Branch protection declared but unconfigured.** Agent commits to "required checks: X/Y/Z" but main has no protection rule. First admin-merge by Sam goes through without complaint; second one too. By the time someone notices, decisions.md has rows that say "branch-protected on main" but the actual repo has nothing.

### action: user-stories

- [ ] stories: Which personas matter? For each: 'As <persona>, I want <action>, so that <outcome>.' 1-5 stories total.

### action: ux-brief

- [ ] brief: infer the UX direction from problem, success, and user stories

### action: proposed-approach

- [ ] approval: draft the approach with 2 alternatives and tradeoffs, iterate with the user, get approval

### action: data-contract

- [ ] approval: draft the data contract, iterate with the user, sync data-model.md, get approval

### action: flows

- [ ] flows: draft 1-3 critical flows, each referencing the user story it implements

### action: dependencies

- [ ] deps: draft external services + pricing math scaled to success-volume targets

### action: out-of-scope

- [ ] list: What are we explicitly NOT building this round? 1-5 bullets, each: name + reason. Empty is fine.
- [ ] approval: user_approves

### action: non-functional

- [ ] constraints: draft performance, security, and compliance constraints

### action: acceptance-criteria

- [ ] approval: draft the acceptance criteria, run a constraint-coverage check vs §4, iterate, get approval

### action: signoff-steps

- [ ] manual-steps: What manual smoke tests do YOU need to do before SHIP, beyond the automated tests? 1-5 bullets.

### action: wireframe

- [ ] wireframe: draft wireframe.html — UI screens for UI features OR flow + architecture for non-UI features

### action: plan-decompose

- [ ] tasks: convert acceptance criteria into ordered build tasks (one test file per task)

### action: edge-case-sweep

- [ ] ec-sweep: draft
- [ ] ec-pick: ask

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"
