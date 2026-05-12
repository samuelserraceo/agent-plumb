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

- [x] stories: 3 stories — first-time installer (verify what I declared actually works before depending on it), returning adopter changing stack (re-verify after `/sdd-config` flip), multi-machine adopter (catch per-machine gaps like Ollama on laptop-B).

**User stories (3 total):**

1. **First-time installer — verify before depending.** As a fresh SDD installer running `/sdd-setup` for the first time, I want a follow-up `/sdd-verify-stack` step that probes each declared answer against reality (CR App installed, Ollama reachable, branch protection in place, required CI files exist), so my first `/start` does not silently misbehave because of a setup gap.

2. **Returning adopter changing stack — re-verify after a flip.** As Sam re-answering one wizard question via `/sdd-config <question-id>` (e.g. flipping reviewer from `none` to `coderabbit`), I want the same verify-stack run automatically on the changed answer, so the new declaration is paired with a reality-check at the moment I commit to it.

3. **Multi-machine adopter — catch per-machine gaps.** As an SDD adopter who works on laptop-A (with Ollama pulled) and later on laptop-B (without it), I want `/sdd-verify-stack` (or a session-start probe of the same shape) to surface missing per-machine deps so the agent does not blow up mid-walk on a machine that has not been fully set up yet.

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — non-UI feature (post-wizard CLI step + new slash command `/sdd-verify-stack`; output is plain-English stderr / chat lines, not visual UI). Visualisation lives in §13 wireframe (flow + architecture + concrete example output) per the v1.2 wireframe-redesign rule, same pattern as F011 / F014.

### action: proposed-approach

- [x] approval: Approach A — single post-wizard action `/sdd-verify-stack`. One shell script `templates/.sdd/scripts/verify-stack.sh` + action file + slash command. 6 checks (CR App, Copilot, branch protection, required CI workflows, Tier 3 LLM provider, test runner deps). Auto-fires at end of `/sdd-setup`; manual via slash command. Plain-English pass/fail per check, fail surfaces fix path. Each check is its own bash function (Lego). Backward-compat (no-op when relevant `parameters.*` is empty). Builds on existing `gh` + `curl` deps. Sam approved 2026-05-12.

**Draft (awaiting Sam approval — pick A, B, or C):**

**Approach A wins — Single post-wizard action `/sdd-verify-stack` (RECOMMENDED):**

One new SDD action `verify-stack` runs the 6 issue-listed checks as a single sequenced batch. Plain shell script under `templates/.sdd/scripts/verify-stack.sh` invoked by the action prose. Each check returns one line of plain-English output: pass (`✓ CodeRabbit App installed`) or fail with fix path (`✗ CodeRabbit App not installed — install at https://github.com/marketplace/coderabbitai`). Action exits 0 if all checks pass; exits 1 if any check fails. Action runs:

- (auto) at the tail of `/sdd-setup`'s last brick — wizard completes, verify-stack fires, surfaces any gaps before the user runs their first `/start`
- (manual) standalone via new slash command `/sdd-verify-stack` whenever the user re-runs `/sdd-config` or changes machines
- (referenced) the action is also called out in `session-start.sh` doctrine as the right thing to run when the user reports "agent waited forever" or "MCP call failed"

The 6 checks (all from #165):
1. **CodeRabbit App** — `gh api repos/<owner>/<repo>/installation` if config says `review.bot=coderabbit`
2. **GitHub Copilot review** — `gh api ...` settings probe if `review.bot=copilot`
3. **Branch protection** — `gh api repos/<owner>/<repo>/branches/main/protection` against declared required-checks
4. **Required CI workflow files** — grep `.github/workflows/*.yml` for declared job names
5. **Tier 3 LLM provider** — Ollama: `curl localhost:11434/api/tags`; OpenAI: `[ -n "$OPENAI_API_KEY" ]`
6. **Test runner deps** — `package.json` (or pyproject.toml) contains declared test-runner package

**Trade-offs:**

- ✅ Smallest delta — one new shell script + one action file + one slash command + one auto-run hook into `/sdd-setup` finale. No new daemons, no MCP, no `node_modules`.
- ✅ Composable — each of the 6 checks is its own bash function in the script; users with custom stack additions can extend by adding their own functions later.
- ✅ Auto + manual — the same script powers both the post-wizard auto-run and the standalone slash command (no logic duplication).
- ✅ Plain-English failures — every check's stderr is a one-liner the user can act on without reading source.
- ⚠️ One-time audit of which stack questions need which check (probably already correct from issue body; cheap).

**Approach B — Inline verify after each wizard question (rejected):**

As the wizard answers Q3 reviewer, immediately probe `gh api .../installation`. Pros: catches the gap at the moment of answering. Cons: heavier touch to the wizard flow; multiplies network probes by N questions; harder to skip when user is offline at install time; couples each brick's prose to its own verifier logic (Lego foundation violation). Defer to v2 if Approach A's batch-at-end shape feels too late.

**Approach C — Session-start probe (rejected):**

Run the 6 checks every session-open via `.claude/hooks/session-start.sh`. Pros: continuous reality-check. Cons: noisy (fires on every session even after a clean install); blocks session-start on network probes (slow Tier 3 ping = slow session-open); over-engineered when a one-shot post-wizard run + manual re-run cover the actual use cases.

**Why Approach A wins:**

1. **Pillar 1 (Simplicity).** Smallest delta to the framework: one shell script + one action file + one slash command. No new daemons, no new MCP servers, no new entities.
2. **Pillar 2 (Lego).** Each of the 6 checks is its own bash function — composable; extensible by future stack additions slotting in another function without changing the dispatcher.
3. **Backwards compatible.** No-op on projects where the relevant stack answer is `none` (e.g. `review.bot=""` skips check 1+2; no Tier 3 = skip check 5). The script reads `parameters.*` from config.md and gates each check accordingly.
4. **Reversible.** Removing the action prose + slash command + the post-wizard hook reverts to today's behaviour with no other changes.

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
