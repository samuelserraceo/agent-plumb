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

- [x] approval: 3 new artefacts (`verify-stack.sh` script manifest-pinned + `verify-stack.md` action + `sdd-verify-stack` slash command, each live + template). 0 new config fields. 0 new project-state entities. 1 new framework-level concept (`StackCheck`, typed string — NOT a data-model.md entity, analogous to F011's AutomationLevel + F014's Tier). 7 edge cases asked-and-answered (empty reviewer / Tier 3 off / no package.json / gh missing / curl missing / not-SDD-project / network unreachable). Sam approved 2026-05-12.

**Draft (awaiting Sam approval):**

- **New artefacts (3):** `templates/.sdd/scripts/verify-stack.sh` (the 6-check runner, mirrored live), `templates/.sdd/actions/verify-stack.md` (action prose, mirrored live), `templates/.claude/commands/sdd-verify-stack.md` (slash command body, mirrored live but the live `.claude/` is gitignored — only template is tracked).
- **Manifest pin:** verify-stack.sh joins the manifest-pinned scripts (same shape as advance.sh / hash-section.sh / resolve-parameters.sh / dispatch-wave.sh / promote-legacy-queued.sh). New entry in `.sdd/.cache/manifest.json` + template copy.
- **No new config field.** Script reads existing fields: `parameters.review.bot` (checks 1+2), `parameters.mcp.tier3.*` (check 5), declared required-checks from stack.md (checks 3+4), test runner from stack.md (check 6).
- **No new project-state entity** (spec.md / INDEX.md / decisions.md / patterns.md / data-model.md unchanged per-run; verify-stack outputs to stderr/stdout, does not write to any tracked file).
- **One new framework-level concept** (typed string, NOT a data-model.md entity): `StackCheck` — values `cr-app | copilot | branch-protection | ci-workflows | tier3-provider | test-runner`. Analogous to F011's `AutomationLevel` and F014's `Tier`.
- **Existing entities** (Playbook, Hook, Setup brick, Wave): no new fields. The `Action` ENTITY gains nothing — verify-stack is just a new action file slotting into the existing action shape (post-#248 with `tier:` frontmatter, this one classifies as `mechanical`).
- **Edge cases at the data layer:**
  1. `parameters.review.bot` empty — checks 1+2 skip silently (pass with no output line).
  2. Tier 3 disabled (`parameters.mcp.tier3.enabled: false`) — check 5 skips.
  3. No `package.json` (Python project, etc.) — check 6 looks at `pyproject.toml`; if neither, surface "no test-runner manifest found in this project — verify by hand" and continue.
  4. `gh` CLI not installed — checks 1/2/3 emit `gh not on PATH — install from cli.github.com` and continue with other checks.
  5. `curl` not on PATH — check 5 falls back to `wget`; if both absent, emit `curl/wget missing — Ollama probe skipped` and continue.
  6. User runs `/sdd-verify-stack` outside an SDD project (no `.sdd/`) — surface `not an SDD project — run /sdd-setup first` and exit 1.
  7. Network unreachable — checks 1/2/3/5 emit `network unreachable — re-run when online` and continue with local-only checks 4+6.
- **data-model.md sync:** none — StackCheck is a typed string, not an entity (per F011's `AutomationLevel` and F014's `Tier` precedent).

### action: flows

- [x] flows: 3 flows — Flow 1: Auto-fire at end of `/sdd-setup` (wizard tail invokes verify-stack.sh; surfaces gaps before first `/start`); Flow 2: Manual `/sdd-verify-stack` (standalone slash command; same script, same output); Flow 3: Re-verify after `/sdd-config` change (slash command tail invokes verify-stack for the just-changed parameter). Implements user stories #1 (first-installer), #2 (returning-adopter), #3 (multi-machine).

**§7 Flows (3 critical):**

1. **Flow 1 — Auto-fire at end of `/sdd-setup`** (user story #1 first-installer). Wizard walks through all bricks (existing behaviour). After the last brick records its answer, the wizard's prose calls out: "Setup answers recorded. Running `/sdd-verify-stack` to check declared tools exist..." → invokes `verify-stack.sh` → script reads `parameters.*` + stack.md, runs the 6 checks in sequence. Each check emits one line (✓ pass or ✗ fail + fix path). All-pass → wizard ends with "Ready to run `/start <feature-name>`." Any-fail → wizard ends with "Some declared tools are missing — fix the items above, then re-run `/sdd-verify-stack`." Same chat-as-UX shape as F011's automation-level brick + F014's models setup brick.

2. **Flow 2 — Manual `/sdd-verify-stack`** (user story #3 multi-machine). User on laptop-B types `/sdd-verify-stack`. Slash command body invokes the same `verify-stack.sh`. Same 6 checks, same output. Exit code 0 = all-pass; exit 1 = at least one fail. No state changes — purely a probe + report.

3. **Flow 3 — Re-verify after `/sdd-config` change** (user story #2 returning-adopter). User types `/sdd-config review-bot coderabbit` (or similar single-question re-answer via existing `/sdd-config` mechanism). The slash command body, at the tail of its existing flow, invokes the targeted check from verify-stack.sh — e.g. just check 1 (CR App installed) because that's the parameter that just changed. If fail, surfaces the fix path inline before the user runs their next `/ship`. Lighter touch than running all 6 checks every time `/sdd-config` is touched.

### action: dependencies

- [x] deps: three buckets. Hard deps — existing `gh` CLI (checks 1/2/3; framework already requires it for `/ship` push-pr); existing `curl` or `wget` (check 5 Ollama probe; one of the two typically present on macOS+Linux); existing `python3` / `bash` (script runtime); existing `parameters:` config structure in `.sdd/config.md` (script reads `review.bot` + `mcp.tier3.*`); existing `.sdd/stack.md` (script parses declared required-checks and test runner from it); existing `/sdd-setup` wizard tail (Flow 1 auto-runs verify-stack from there); existing `/sdd-config` slash command body (Flow 3 invokes targeted re-verify after a parameter change). Soft deps — `jq` (for richer gh-api JSON parsing; v1 can use plain grep + sed if jq isn't on PATH). Explicitly NOT depending on — no new MCP servers, no new npm packages, no new `data-model.md` entities, no new harness API (works identically on Claude Code + pi.dev), no commit-shape changes (verify-stack does not commit anything — purely a probe+report).

**§8 Dependencies (three buckets):**

**Hard deps (must exist for F020 to function):**
- **`gh` CLI** (already a framework dep for `/ship` push-pr) — checks 1 (CR App installation), 2 (Copilot review settings), 3 (branch protection rules). Surfaced install hint if missing.
- **`curl` OR `wget`** (one typically present on macOS+Linux out of box) — check 5 Ollama daemon probe `localhost:11434/api/tags`. Script tries curl first, falls back to wget, skips with `network probe tool missing` if both absent.
- **`python3` + `bash`** (framework's existing runtime requirements per CLAUDE.md "files you can `cat`" doctrine).
- **`parameters:` config block in `.sdd/config.md`** — script reads `review.bot`, `mcp.tier3.enabled`, `mcp.tier3.provider` to know which checks to run.
- **`.sdd/stack.md`** — script parses declared required-checks (check 4) and declared test runner (check 6) from this file.
- **`/sdd-setup` wizard tail** — Flow 1 auto-invokes verify-stack here.
- **`/sdd-config` slash command body** — Flow 3 invokes targeted re-verify after a parameter change.

**Soft deps (would help but not required):**
- **`jq`** — richer JSON parsing of `gh api` output. v1 falls back to plain grep + sed when jq isn't on PATH; nicer output when it is.

**Explicitly NOT depending on:**
- No new MCP servers (verify-stack is plain shell, no framework-runtime additions).
- No new npm packages (`node_modules` stays out; Pillar 1 simplicity).
- No new `data-model.md` entities (StackCheck is a typed string, per F011's AutomationLevel + F014's Tier precedent).
- No new harness API — works identically on Claude Code + pi.dev port; the script invokes the same `gh` / `curl` calls regardless of which harness drove `/sdd-setup`.
- No commit-shape changes — verify-stack does not commit anything; it's a probe + stderr/stdout report.

### action: out-of-scope

- [x] list: 6 explicit deferrals — (1) auto-fix mode; (2) CR-convergence check (#166 deferred per Sam's own gate); (3) periodic re-check; (4) user-defined check extensions; (5) currency-denominated Tier 3 budget validation; (6) multi-machine config sync.
- [x] approval: 6 deferrals locked (auto-fix mode, #166 CR-convergence, periodic re-check, user-defined extensions, currency-denominated Tier 3 budget, multi-machine config sync). Sam approved 2026-05-12.

**§9 Out-of-scope for F020 v1 (6 explicit deferrals):**

1. **Auto-fix mode** — script offers to install missing deps inline (e.g. "CR App not installed; install now? [y/N]"). Too invasive for v1; surface the install URL instead and let the user install themselves. Defer to v2 if friction surfaces.
2. **CR-convergence check** (issue #166) — deferred per Sam's own "Don't ship until 2-3 more failure modes" gate on #166. F020 is the wizard-side reality check; #166 is the SHIP-side enforcement. Different scope.
3. **Periodic re-check** (cron / timer running verify-stack every N hours) — ad-hoc manual `/sdd-verify-stack` covers the use case; periodic adds noise + complexity for marginal benefit.
4. **User-defined check extensions** (custom functions appended to `verify-stack.sh`) — v1 ships the 6 built-in checks from #165. Defer to v2 once we see what custom adopters actually need to verify; premature extensibility = Pillar 1 violation.
5. **Currency-denominated Tier 3 budget validation** — same anti-theatre constraint as F008's cost-ledger and F014's cost-ceiling deferral. Framework can probe "is Ollama reachable?" but cannot probe "does the OpenAI key have enough credit?" without per-provider pricing data the framework does not ship with {best-effort: Sam at SHIP — same constraint documented at F001 / F008 / F014}.
6. **Multi-machine config sync** — auto-port answers between laptop-A and laptop-B. Out of scope; manual sync via `git pull` on `.sdd/config.md` covers the case. v1 just probes each machine independently.

### action: non-functional

- [x] constraints: Performance — verify-stack run is bounded: 6 sequential checks, each one network probe (CR App, Copilot, branch-protection, Ollama) or local file probe (CI workflows, test-runner). Total wall-clock under 30s in the happy path {best-effort: Sam at SHIP — measure on a fresh-install fixture}; gracefully degrades on slow networks via per-check timeouts. No new compute beyond what `gh` / `curl` already do. Security — no secrets leaked (script reads only `parameters.*` from config.md, never logs env vars or auth tokens beyond pass/fail booleans); read-only by design (no writes to tracked files; only stderr/stdout output); same trust-boundary as existing slash commands. Compliance — MIT unchanged, no PII collected, no new telemetry; runs locally, talks to GitHub API and (optionally) localhost Ollama. No external service dependency beyond what the project already declared.

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
