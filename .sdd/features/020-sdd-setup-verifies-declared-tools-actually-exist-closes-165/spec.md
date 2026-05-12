---
playbook: feature
---

# sdd-setup verifies declared tools actually exist (closes #165)

[PHASE: BUILD]

**Active blocker:** §14 (BUILD action: run-mode-chosen)

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

- [x] approval: 10 ACs (AC1-AC10). 7 mechanical (AC1-AC7) each with `{verify-by: T500-T506}`. 1 best-effort with named-eye (AC8 plain-English failure-message audit at SHIP). 2 PROD-ONLY (AC9 auto-fire at /sdd-setup end, AC10 standalone /sdd-verify-stack). T500-T506 reserved for 7 mechanical T-tasks. Sam approved 2026-05-12.

**§11 Acceptance Criteria (10 total):**

- **AC1 — Default behaviour when no parameters declared.** Fresh project with empty `parameters.review.bot`, `parameters.mcp.tier3.*`, and no declared test runner → `verify-stack.sh` reports "no declared tools to verify" and exits 0. Backwards-compat: no-op when nothing's declared. {verify-by: T500}
- **AC2 — Check 1 CR App fires when reviewer is coderabbit.** `parameters.review.bot=coderabbit` → script runs `gh api repos/.../installation`; emits ✓ on install present, ✗ + GitHub Marketplace URL on missing. {verify-by: T501}
- **AC3 — Check 2 Copilot fires when reviewer is copilot.** `parameters.review.bot=copilot` → script probes repo Copilot settings via `gh api`; same pass/fail line shape as AC2. {verify-by: T502}
- **AC4 — Check 3 branch protection.** Script reads declared required-checks from stack.md, runs `gh api repos/.../branches/main/protection`, compares the set; emits ✓ on match, ✗ + fix command on mismatch. {verify-by: T503}
- **AC5 — Check 4 CI workflow files.** Script greps `.github/workflows/*.yml` for declared job names; emits ✓ when all declared names found, ✗ + missing-names list otherwise. {verify-by: T504}
- **AC6 — Check 5 Tier 3 provider reachable.** `parameters.mcp.tier3.enabled=true` AND `provider=ollama` → `curl localhost:11434/api/tags`; OR `provider=openai` → `[ -n "$OPENAI_API_KEY" ]`. ✓ on reachable/set, ✗ + install/env-var hint otherwise. {verify-by: T505}
- **AC7 — Check 6 test runner deps.** Script reads declared test-runner from stack.md (e.g. "Vitest", "Playwright"), grep `package.json` or `pyproject.toml` for the dep name; ✓ on present, ✗ + `npm install <pkg>` hint otherwise. {verify-by: T506}
- **AC8 — Plain-English failure messages.** Manual audit of each fail-path's stderr line confirms it names (a) what failed and (b) one concrete fix command or URL — readable by a non-technical first-time installer. {best-effort: Sam at SHIP — eye-check the 6 fail-path messages}
- **AC9 — Auto-fire at end of /sdd-setup.** In a real Claude Code session, running `/sdd-setup` end-to-end on a fresh fixture project triggers verify-stack.sh at the tail of the last brick; output appears inline in chat. {prod-only: requires live agent session at first SHIP}
- **AC10 — Manual /sdd-verify-stack works standalone.** In a real Claude Code session, typing `/sdd-verify-stack` invokes the same script from outside the setup wizard; same output shape. {prod-only: requires live slash-command dispatch}

### action: signoff-steps

- [x] manual-steps: 3 manual checks before SHIP — (1) fresh-install fixture smoke (AC9 PROD-ONLY — set up a brand-new SDD project, run `/sdd-setup`, confirm verify-stack auto-fires + outputs make sense); (2) standalone slash command (AC10 PROD-ONLY — type `/sdd-verify-stack` outside the wizard, confirm same output); (3) AC8 named-eye audit of the 6 fail-path stderr messages (each names what failed + concrete fix command/URL, readable by a non-technical first-time installer).

### action: wireframe

- [x] wireframe: non-UI wireframe.html drafted from v1.2 wireframe-non-ui skeleton — shows the 6 checks (CR App / Copilot / branch-protection / CI workflows / Tier 3 provider / test runner), 3 example interactions (Sam fresh-install with all-pass / Sam fresh-install with CR-not-installed-yet / multi-machine laptop-B with Ollama-not-pulled), the 3 flows from §7 (auto at /sdd-setup tail / manual /sdd-verify-stack / targeted re-verify after /sdd-config), and the new-vs-existing matrix (verify-stack.sh new, verify-stack.md action new, /sdd-verify-stack slash command new, sdd-setup wizard tail modified, gh+curl deps unchanged). Populate during BUILD T507 or as ec-sweep follow-up; mirrors F011's wireframe shape.

### action: plan-decompose

- [x] tasks: 7 ordered T-tasks T500-T506, one per mechanical AC. T500 walking-skeleton (script exists + manifest pin + empty-params no-op). T501-T506 layer one check each onto the same script (single-file BUILD, framework-self-mod dance applies only to T500). AC8 named-eye + AC9/AC10 PROD-ONLY at SHIP — no T-task. Sam approved 2026-05-12.

**§14 Plan-decompose (7 BUILD tasks, one per mechanical AC):**

```
- [x] T500 GREEN: verify-stack.sh exists at templates path; manifest-pinned;
              with empty parameters.* + no stack.md declarations, the
              script exits 0 with one line "no declared tools to verify"
              (walking-skeleton)
              — proves AC1
- [x] T501 GREEN: check 1 fires when parameters.review.bot=coderabbit and
              gh-api install probe reports installed/missing correctly
              — proves AC2
- [x] T502 GREEN: check 2 fires when parameters.review.bot=copilot and
              probes Copilot review settings via gh-api
              — proves AC3
- [x] T503 GREEN: check 3 compares declared required-checks from stack.md
              against `gh api .../branches/main/protection` response
              — proves AC4
- [x] T504 GREEN: check 4 greps .github/workflows/*.yml for declared job
              names; reports missing
              — proves AC5
- [ ] T505 RED: check 5 Tier 3 — Ollama via curl localhost:11434/api/tags
              + OpenAI key env-var presence
              — proves AC6
- [ ] T506 RED: check 6 — declared test-runner dep in package.json
              (or pyproject.toml fallback)
              — proves AC7
```

**Order rationale:** T500 first (walking-skeleton — script exists + manifest pin + empty-params path). T501-T506 layer one check each on top; each independent (different `gh api` or filesystem probe). Per the F011/F014 pattern: framework-self-mod manifest dance applies to T500 only (script first lands in manifest); T501-T506 only add bash functions to the existing script (no manifest changes after T500).

**Walking-skeleton check:** T500 is the smallest end-to-end slice — script exists, can be invoked, returns the empty-params case. All subsequent tasks layer functionality without breaking T500's invariant.

**Wave dispatch (F010 unlock):** T501-T506 are independent functions in the same script — could theoretically `[WAVE: 1]` but they share `verify-stack.sh`, so wave-dispatch would have to handle in-file merge conflicts. v1: linear; per-task framework-self-mod dance is minimal (single-file script).

**No T-task for** AC8 named-eye prose audit (best-effort at SHIP), AC9 PROD-ONLY auto-fire-on-/sdd-setup-tail (live agent session), AC10 PROD-ONLY standalone slash command (live dispatch) — all 3 verified at SHIP via §12 sign-off steps.

### action: edge-case-sweep

- [x] ec-sweep: 8 edge cases identified across gh-api-shape, network, and platform dimensions.
- [x] ec-pick: 8 ECs, 0 new ACs (§11 stays hash-locked at 10). 4 folded into T-tasks (#3 → T504, #7 → T501-T506 timeouts, #8 → AC6 fail-path). 4 documented at SHIP / in prose (#1 owner-vs-repo, #2 set-inclusion, #4 Ollama model-not-pulled, #5 OpenAI key-validity limitation). 1 already-covered (#6 by §9 #4 deferral). Sam approved 2026-05-12.

**§15 Edge-case sweep (8 cases):**

| # | Edge case | Severity | Handling |
|---|-----------|----------|----------|
| 1 | CR App installed at owner-level only, not repo-level | Low | `gh api repos/.../installation` 200 means installed for the repo; if 404, surface "install on this repo via Marketplace". Owner-vs-repo distinction is gh-api's responsibility. |
| 2 | Branch protection has MORE required-checks than declared | Low | Compare as set inclusion: declared ⊆ actual = pass. Extra protection beyond spec is fine; the verify is "are my declared things real?" not "exact match". |
| 3 | CI workflow file exists but the job name inside it doesn't match declared | Medium | Check 4 greps `name: <declared-job>` inside `.github/workflows/*.yml`, not just filename. If workflow file present but job name not found, emits "workflow file present but no job named `<X>` — check YAML key names". |
| 4 | Ollama running but model not pulled | Medium | `curl /api/tags` returns 200 with model list. After connectivity probe passes, optionally also probe for `parameters.mcp.tier3.model` in the returned list; if missing, emit hint `ollama pull <model>`. v1 can skip the model-presence probe; document as "connection only, model presence by hand". |
| 5 | OpenAI key env var set but invalid | Low | Script cannot probe key validity without making a paid call. Just check presence — `[ -n "$OPENAI_API_KEY" ]`. Document the limitation. {best-effort: Sam at SHIP — eye-check that "key presence only" is clearly stated in the pass-line} |
| 6 | Test runner dep present but version mismatch | Low | Out of scope per §9 #4 — verify-stack checks presence only. Version-mismatch is user's responsibility. |
| 7 | Network probe slow (Tier 3 endpoint behind VPN) | Low | Per-check timeout: `curl --max-time 5` on Ollama probe, `gh api --request-timeout 10` on github calls. Failure emits "network probe timed out; re-run when reachable". |
| 8 | User on Windows / WSL — localhost:11434 remap | Low | WSL2 has its own loopback; `localhost` may not reach Windows-side Ollama daemon. If check 5 fails AND `uname` contains `microsoft`, emit "WSL detected; try `host.docker.internal:11434` or run Ollama inside WSL". |

**ec-pick disposition (awaiting Sam approval):**

- **#1 CR owner-vs-repo** — Folded into AC2's pass/fail prose. No new AC.
- **#2 protection-set inclusion** — Folded into AC4 logic. No new AC.
- **#3 workflow-vs-job-name** — Folded into T504's fixture (test the grep includes `name:` not just filename). No new AC.
- **#4 Ollama model-not-pulled** — Folded into AC6 documentation. v1 ships connectivity-only; document model-presence as user's responsibility.
- **#5 OpenAI key-validity** — Documented limitation in AC6 pass-line prose. No mechanical fix.
- **#6 test-runner version-mismatch** — Already in §9 #4 deferral.
- **#7 slow network** — Folded into T501-T506 fixtures (each check has a timeout). No new AC.
- **#8 WSL detection** — Folded into AC6 fail-path message. No new AC.

**Net effect:** 0 new ACs (§11 stays hash-locked at 10 ACs). 4 folded into existing T-tasks (#3 → T504; #7 → T501-T506 timeout fixtures; #8 → AC6 fail-path). 4 documented at SHIP / in prose (#1, #2, #4, #5). 1 already-covered (#6 by §9 #4 deferral).

### Exit checks
- [x] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [x] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: Shell Ralph headless mode — Sam runs `cd <repo-root> && ./scripts/ralph.sh` in a fresh terminal session. Ralph iterates autonomously through T500-T506. Per F010/F014 lessons: ralph.timeout_per_iter is already 1800s (handles the 5-min pre-commit test suite + manifest repin on T500). Sam picked Shell Ralph 2026-05-12.

**Run mode:** Shell Ralph (headless, new terminal)

### action: build-task

(driven by §14 tasks T500-T506 — each task lands as one commit per atomic step: test (RED) / code / green-flip. Canonical task list lives in §14 plan-decompose above.)

### Exit checks

- [ ] C-build-tasks-green: T500-T506 all GREEN; framework tests pass {verify-by: verify-stage.sh}

## PHASE: SHIP

### action: verify-test-run

- [ ] run-tests: run-tests pass

### action: learn

- [ ] summary: one-paragraph plain-English summary of what shipped, why
- [ ] lessons: append patterns to .sdd/patterns.md

### action: push-pr

- [ ] push-and-open: push the branch + open a PR

### action: verify-ci-green

- [ ] ci: all CI checks GREEN on the PR

### action: mark-shipped

- [ ] shipped: INDEX.md updated, .shipped marker written, decisions.md appended

### Exit checks

- [ ] C-ship-pr-url: PR URL recorded in INDEX.md Shipped section {verify-by: verify-stage.sh}
- [ ] C-ship-marked: .shipped marker file exists in feature folder {verify-by: verify-stage.sh}
