---
playbook: feature
---

# background while waiting

[PHASE: SPEC]

**Active blocker:** §1 (first action: problem)

## PHASE: SPEC

### action: problem

- [x] who: SDD project owner (Sam) dogfooding the framework on its own development loop — the immediate-and-only person hitting CR/CI deadtime today; downstream SDD users inherit benefit
- [x] why-now: v1.5+ improvement queue is bottlenecked on CR/CI idle time; #42 parallel-features already shipped giving the agent a concrete "next safe thing" target; landing 004 first compounds savings on every subsequent v1.6+ improvement
- [x] what-breaks: every shipped framework feature carries 15-30 min of agent + Sam idle wall-clock; the v1.5+ improvement queue ships much slower than it could; deadtime breaks Sam's flow and burns attention with nothing to do

### action: success

- [x] metric: engagement — 100% of CR/CI waits ≥3 min trigger ≥1 always-safe background action {verify-by: marker emit count in CR-poll loop == wait-event count, measured across next 5 framework features after 008 ships}; baseline 0% today (current poll loop is idle) {verify-by: grep .sdd/scripts/ for background-emit calls — expect zero matches at HEAD~0}

### action: user-stories

- [x] stories: 4 stories — Sam wants low-risk background work, pre-fetched next-feature context, and pre-written PR descriptions during CR/CI waits; downstream SDD users inherit the same behaviour post-ship

**User stories**

1. **As** Sam dogfooding SDD on the framework, **I want** the agent to fill CR/CI deadtime with low-risk background work, **so that** I don't watch a 15-min idle timer between every push and merge.
2. **As** Sam dogfooding SDD on the framework, **I want** the agent to pre-fetch the next feature's spec context while waiting on the current PR, **so that** the next loop starts with corpus already warm.
3. **As** Sam dogfooding SDD on the framework, **I want** the agent to draft the PR description while waiting on CodeRabbit, **so that** /ship is a one-button move the moment CR clears.
4. **As** an SDD user (post-ship), **I want** the same background behaviour applied to my own framework loops, **so that** my dev velocity inherits the same idle-time savings.

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — non-UI feature (agent behaviour change, no user-facing surface)

### action: proposed-approach

- [x] approval: B — doctrine + instrumentation (CLAUDE.md doctrine + background-while-waiting.sh trigger script + marker log for §2 metric)

**Recommended approach — B (doctrine + instrumentation)**

A small bash script (`.sdd/scripts/background-while-waiting.sh`) gets called by the existing CR-poll loop when it enters a wait window. The script emits a marker (for the §2 metric counter) and prints the safe-set actions for the agent to consider. The agent does the actual background work; the script is the trigger + measurement.

Doctrine lives in two places:

- `templates/CLAUDE.md` — ships to user projects via /sdd-setup
- `.sdd/CLAUDE.md` — framework's own dogfooding copy

Both list three sets:

- **Low-risk** — re-read corpus (patterns.md, decisions.md, data-model.md), pre-fetch next-feature context, draft PR description, draft commit messages
- **Judgement-required** — speculative responses to likely CR concerns
- **Out-of-scope** — edits outside current feature, force-push, changes to shared corpus files

Why this answers the brief:

- §1 problem (deadtime) → script triggers on deadtime entry
- §2 metric → marker emit count is the counted variable
- §3 stories — story 1 maps to the safe-set as a category; stories 2-4 are concrete instances inside it

**Alternatives considered**

- **Approach A — doctrine only.** Same CLAUDE.md sections, no script. Simpler, fewer moving parts. *Why not recommended:* §2's metric requires a mechanical marker emit count. Without the script we'd be shipping a metric we can't verify — anti-theatre territory.
- **Approach C — A + B + parallel-feature integration.** B plus: when INDEX shows 2+ features in flight (#42 territory), the script proactively suggests "advance feature N+1 by one safe step." *Why not recommended:* #42 just shipped; "advance N+1 by one step" is undefined behaviour. Better to ship B, learn how the loop behaves, then layer C in a follow-up if savings warrant.

**What we trade off**

- A small bash script's worth of new surface area — adds something that could break (mitigation: regression test added in plan-decompose)
- One extra log line per wait window in `.sdd/.cache/` (minor noise)

**Key technical choices for sign-off**

- **Language:** plain bash — no new dependencies, runs wherever SDD already runs (macOS / Linux)
- **Marker log format:** append-only JSONL under `.sdd/.cache/background-emit.log` per session — easy to count for the §2 metric
- **Behaviour boundary:** the script *lists candidates*, doesn't *do* the work — the agent picks. No surprise actions outside the agent's awareness
- **Trigger point:** existing CR-poll loop's wait function — single integration point, no parallel new infrastructure

### action: data-contract

- [x] approval: no new data-model.md entries — single new internal telemetry log (.sdd/.cache/background-emit.log, JSONL, gitignored)

**Recommended: no new data-model.md entries.**

One new data structure: `.sdd/.cache/background-emit.log` — append-only JSONL telemetry, gitignored, per-session, consumed by the §2 metric counter tooling. Internal telemetry (similar shape to existing hook logs and lock files in `.sdd/.cache/`). data-model.md tracks user-visible and cross-feature shared entities; an internal telemetry log doesn't belong there.

**Log schema (one JSON object per line):**

```
{"ts": "<ISO-8601>", "session_id": "<8-char-hex>", "wait_type": "cr-poll|ci-poll|other", "action_chosen": "re-read-corpus|pre-fetch-next-feature|draft-pr-description|draft-commit-msgs|speculative-cr-response|none-skipped"}
```

Field meanings:

- `ts` — timestamp at emit, ISO-8601 UTC, chronologically sortable
- `session_id` — 8 hex chars, generated per session — lets per-session counts compute
- `wait_type` — the trigger that fired (initial set: cr-poll, ci-poll, other)
- `action_chosen` — what the agent did during that wait window. The §2 metric counts rows where `action_chosen != "none-skipped"`

**Out of §6 scope:**

- New user-facing entities
- Changes to existing entities
- Data migration
- Multi-row queries (the metric is grep-and-count over the log file)

### action: flows

- [x] flows: 3 critical flows — wait-window-enter→action-chosen (Story 1), pre-fetch-next-feature (Story 2), draft-pr-description (Story 3)

**Flow 1 — Wait window enters → background action chosen** (Story 1)

1. Agent runs `git push` or `gh pr create` — kicks off CR/CI
2. Agent's existing CR-poll loop enters wait
3. CR-poll loop calls `.sdd/scripts/background-while-waiting.sh` with `wait_type` as arg
4. Script emits a marker line to `.sdd/.cache/background-emit.log` (`action_chosen: pending` initially), then prints safe-set candidates
5. Agent reads candidates, picks one (or `none-skipped` if context-inappropriate)
6. Agent does the action
7. Marker line updated with actual `action_chosen`
8. Wait window ends; agent resumes normal flow

**Flow 2 — Pre-fetch next-feature context** (Story 2)

1. During wait window (Flow 1 step 5), agent picks `pre-fetch-next-feature`
2. Reads `.sdd/INDEX.md` `## In flight` for the next feature (if any)
3. Reads that feature's spec.md into working context
4. Re-reads patterns.md / decisions.md / data-model.md against the new feature's lens
5. Marker line: `action_chosen: pre-fetch-next-feature`
6. When current PR merges and `/start` runs the next, corpus is warm

**Flow 3 — Draft PR description while CR runs** (Story 3)

1. During wait window (Flow 1 step 5), agent picks `draft-pr-description`
2. Reads current feature's spec.md + recent commit log
3. Drafts PR title + body summarising what changed and why
4. Saves to `.sdd/<feature>/pr-description.md` (per-feature, gitignored, rebuilt on each push)
5. Marker line: `action_chosen: draft-pr-description`
6. When CR clears and `/ship` runs, it reads the cached description and submits

**Out of §7:**

- Actual `gh pr create --body-file` integration — that is a build task, not a flow concern
- Speculative CR-response drafting — judgement-required set, separate flow when added

### action: dependencies

- [x] deps: external services — none. New code surface ships inside SDD's existing infra (CR-poll loop, `.sdd/.cache/`). Local-disk telemetry log writes; no cloud writes, no API calls, no rate-limited services.

**External services**

None. The feature ships within SDD's existing infrastructure:

- Existing CR-poll loop (extended in place; one new script call)
- Existing `.sdd/.cache/` directory (gitignored)
- Existing CodeRabbit + GitHub Actions for the SDD repo's own dev loop (observed by the wait-detection logic; their behaviour is unchanged)

**Pricing math**

The new code path writes a small JSONL telemetry log to local disk. The §2 metric reporting tooling is grep + count — local computation. No cloud write, API call, or rate-limited service is added by this feature {best-effort: Sam at SHIP — verify by reading the diff}.

**Out of §8**

- Future "advance-N+1" parallel-feature work (deferred from §5 Approach C) might need cross-worktree coordination, but that is out of scope here
- Real metric reporting infrastructure (dashboards, etc.) — telemetry stays local for now

### action: out-of-scope

- [x] list: 5 items — speculative CR-response drafting, cross-worktree advance-N+1, auto-execution without agent declaration, remote metric dashboards, pre-fetch beyond next feature
- [x] approval: confirmed — 5 deferrals locked (speculative CR responses, cross-worktree N+1, auto-execution, remote dashboards, deeper pre-fetch)

**Out of scope for v1**

1. **Speculative CR-response drafting** — listed in §5 as the judgement-required set. "What would CR likely say" is speculation that could waste cycles or surface wrong concerns. Deferred until the safe-set behaviour is proven in real CR cycles.
2. **Cross-worktree advance-N+1 parallel work** — Approach C territory from §5. Reaches into #42's just-shipped parallel-feature infrastructure. Ship the safe-set first, learn how the loop behaves, then add C as a follow-up if savings warrant.
3. **Auto-execution of background actions without agent declaration** — the script LISTS candidates; the agent picks and declares (visible in commit log + chat). Auto-execution is deferred to keep user awareness in the loop.
4. **Remote metric dashboards / cross-machine aggregation** — local JSONL log only. Telemetry stays on the user's machine; remote writes, team-level aggregation, and visualisation tooling are deferred.
5. **Pre-fetching beyond the immediate next feature** — Flow 2 pre-fetches feature N+1. Pre-fetching N+2, N+3, etc. would balloon context for limited gain — deferred.

### action: non-functional

- [x] constraints: marker-emit latency budget {verify-by: regression test in plan-decompose}; no-shell-escape on user-provided strings {verify-by: shellcheck in CI}; gitignored telemetry, no PII

**Performance**

- The marker-emit script call adds latency to the existing CR-poll loop. Budget: emit should complete inside the existing poll interval (the CR-poll loop already waits seconds between polls; an emit that takes more than ~50ms would be a regression) {verify-by: regression test added in plan-decompose times the script's duration in a synthetic invocation and asserts under budget}.
- Marker log file size grows append-only; the JSONL log is rotated per session (cleared on session start), so the file stays small enough for grep-and-count of the §2 metric.

**Security**

- The script reads and writes only inside `.sdd/.cache/` plus reads `.sdd/INDEX.md` / spec.md / patterns.md / decisions.md. No remote calls. No shell escape on user-provided strings (action_chosen / wait_type are picked from a closed-enum) {verify-by: shellcheck on the script in CI}.
- The agent's safe-set actions (re-read corpus, draft PR description, draft commit messages) operate on local files inside the working tree. Forbidden actions (force-push, shared-corpus edits) are surfaced in §5 doctrine and excluded from the safe-set candidate list the script prints.

**Compliance**

- Telemetry log contains: timestamp, session_id (random hex), wait_type (closed enum), action_chosen (closed enum). Has no user-identifying fields, no source code, no commit content. Gitignored — the log stays on the user's machine.
- Open-source license: matches the rest of the SDD framework (existing repo license — bash script is added under the same terms).

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
