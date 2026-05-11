---
playbook: feature
---

# user-prompt-submit MCP-doctrine sentinel — first wire toward #210 context slice

[PHASE: BUILD]

**Active blocker:** SHIP — T01 GREEN, ready to PR

**Run mode:** full-autonomous

## PHASE: SPEC

### action: brief-intake

- [x] brief: GitHub issue #210 IS the brief. Minimal first wire — sentinel block in user-prompt-submit.sh telling the agent MCP graph queries are available when enabled.

#### §0 Brief

**Source:** https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/210 — *"Agent flow for /next should query get_backlinks(active-feature) before reading the full spec — context optimisation"*

**Problem (from issue):** The framework writes wiki-links into every notebook and ships 11 MCP query files, but during pipelogic_v2 F01 (33,838-line transcript) the agent did not call any MCP query (zero hits across all 7 query names) {best-effort: F01 transcript review}. The claimed token saving (per /sdd-setup brick 007 wording) promised at `/sdd-setup` brick 007 has not arrived because no playbook action / no hook / no slash command body says *"call this query at this step"*.

**Scope-trimmed fix-shape (v1.8.0 anchor, tonight):** add an **MCP-doctrine sentinel** to `templates/.claude/hooks/user-prompt-submit.sh`. When `.sdd/config.md` has `parameters.mcp.enabled: true`, the hook emits ONE extra line at the top of the `[FRAMEWORK INSTRUCTIONS]` block naming the available graph queries — so the agent SEES the queries are wired and can choose to call them BEFORE re-reading the full notebooks.

**Dependency satisfied:** #209 (MCP server registered at install time) — CLOSED.

**Out of scope (deferred to v1.8.x follow-ups):**
- Actually substituting full-file cats with query slices (per-file injection budgets work — `feat/per-file-injection-budgets` worktree is the parallel landing site).
- Measuring the claimed token drop (per the brief, pending substitution) {best-effort: Sam at SHIP smoke}.
- Auto-querying `get_backlinks(active-feature)` and folding the result into the inject block.

**Severity:** Major user-value (every turn loses a large share (claimed-significant per brick 007 wording) of useful context budget today {best-effort: Sam at SHIP smoke}). This PR is the MIN viable wire; the saving lands when the per-file-injection-budgets PR converges with this one.

**Target:** v1.8.0 anchor — first patch on the v1.8 line, opens after v1.7.3.

### action: problem

- [x] who: framework agents (every Claude Code SDD session) that have MCP enabled but do not call its 11 graph queries today (per F01 transcript review) — they re-read full notebooks every turn instead.
- [x] why-now: v1.7 four-pack landed; per-file-injection-budgets is in flight on a parallel worktree; this sentinel is the doctrine half that pairs with the per-file budgets and unlocks the claimed token saving (per brick 007 wording) once both ship {best-effort: Sam at SHIP smoke}.
- [x] what-breaks: 50+ lines of CLAUDE.md doctrine tells the agent "before you emit a wiki-link, run get_backlinks(slug)" but the agent's runtime context does not surface that MCP is on. Doctrine without runtime cue = ignored doctrine {verify-by: T-001}.

#### §1 Problem

#### who-has-it

Every Claude Code SDD session running on a project with the MCP extension enabled (`parameters.mcp.enabled: true` in `.sdd/config.md`). The pipelogic_v2 F01 transcript was the live audit: 33,838 lines, zero MCP query calls, full notebook re-reads on every `/next`.

#### why-now

The framework's 50+ lines of CLAUDE.md doctrine for MCP queries assume the agent knows the server is registered. But the agent's per-turn injection block has no signal — it just sees `[FRAMEWORK INSTRUCTIONS]` empty and `[PROJECT DATA]` with full notebook content. Adding a one-line sentinel naming the available queries flips the doctrine from theoretical to runtime-cued.

#### what-breaks

3 concrete failure modes {verify-by: T-001}:

1. **Agent re-reads patterns.md + data-model.md every turn.** Notebooks grow with every shipped feature. On a 6-month-old project these are ~50KB combined. 16K char injection cap then forces truncation of the active spec.md — the most relevant content.
2. **Wiki-links stay decorative.** `[[pattern:auth-retry]]` reads as plain markdown text because the agent does not query `get_pattern("auth-retry")` to expand it.
3. **The token-saving promise (per `/sdd-setup` brick 007 wording) is unmet today** {best-effort: F01 transcript review}. Sam's docs say it; the runtime doesn't deliver it; the gap is silent.

### action: user-stories

- [x] stories: 1 persona — framework agent on a SDD project with MCP enabled

#### §3 User Stories

> *As the agent reading the per-turn injected state on an MCP-enabled project, I want a one-line sentinel at the top of `[FRAMEWORK INSTRUCTIONS]` naming the available graph queries (`get_backlinks` / `get_neighbours` / `get_pattern` / `get_references` / `search_within`) so I know I should call them BEFORE deciding I need to re-read patterns.md or data-model.md in full.*

### action: ux-brief

- [x] brief: no UI surface — single-line addition to the per-turn `[FRAMEWORK INSTRUCTIONS]` block.

#### §4 UX & Design brief

**Primary surface:** the per-turn injected state block. The agent reads this every turn.

**Before fix (today — empty FRAMEWORK INSTRUCTIONS):**

```
[FRAMEWORK INSTRUCTIONS — trusted, follow as directive]
(no framework-trusted content injected this turn)
[END FRAMEWORK INSTRUCTIONS]
```

**After fix (MCP enabled — sentinel emitted):**

```
[FRAMEWORK INSTRUCTIONS — trusted, follow as directive]
[MCP graph queries available — prefer `get_backlinks` / `get_neighbours` / `get_pattern` / `get_references` / `search_within` over re-reading patterns.md or data-model.md in full]
[END FRAMEWORK INSTRUCTIONS]
```

**When MCP disabled (default for new projects):** no change. Sentinel suppressed.

### action: proposed-approach

- [x] approval: AUTONOMOUS DRAFT — minimal 4-line addition to user-prompt-submit.sh; grep `.sdd/config.md` for `mcp.enabled: true`; if found, emit the sentinel inside the FRAMEWORK INSTRUCTIONS block.

#### §5 Proposed approach

**Approach (chosen):** minimum-diff edit to `templates/.claude/hooks/user-prompt-submit.sh` (mirrored to `.claude/hooks/user-prompt-submit.sh`).

In the `emit_state()` function, inside the existing `[FRAMEWORK INSTRUCTIONS]` block, replace the line `(no framework-trusted content injected this turn)` with a conditional:

```bash
if grep -qE '^[[:space:]]*mcp\.enabled[[:space:]]*:[[:space:]]*true' .sdd/config.md 2>/dev/null; then
  echo "[MCP graph queries available — prefer \`get_backlinks\` / \`get_neighbours\` / \`get_pattern\` / \`get_references\` / \`search_within\` over re-reading patterns.md or data-model.md in full]"
else
  echo "(no framework-trusted content injected this turn)"
fi
```

**Two files ship (manifest-tracked):**
- `templates/.claude/hooks/user-prompt-submit.sh` (downstream-project copy)
- `.claude/hooks/user-prompt-submit.sh` (live framework copy)

Manifest repin in both `.sdd/.cache/manifest.json` + `templates/.sdd/.cache/manifest.json`.

**Alternatives considered + rejected:**

1. *Actually substitute full-file cats with `get_backlinks` query calls.* Deferred — collides with the parallel `feat/per-file-injection-budgets` worktree work; that's the right landing site for substitution. This PR ships the doctrine half.
2. *Emit the sentinel unconditionally even when MCP is off.* Rejected — would hallucinate to the agent that queries exist when they don't. Conditional gate matches reality.

**Status:** AUTONOMOUS DRAFT.

### action: data-contract

- [x] approval: AUTONOMOUS DRAFT — no new entities. Reads existing `parameters.mcp.enabled` config field.

#### §6 Data contract

No new entities. Reads existing `parameters.mcp.enabled` from `.sdd/config.md` (set by `/sdd-setup` brick 007). `data-model.md` unchanged.

### action: flows

- [x] flows: 1 flow — agent's per-turn injection on MCP-enabled project

#### §7 Flows

```text
User: types /next
Claude Code: fires UserPromptSubmit hook -> user-prompt-submit.sh
Hook: greps .sdd/config.md for `mcp.enabled: true`
  -> found -> emit sentinel "[MCP graph queries available — prefer ... over re-reading ... in full]"
  -> not found -> emit legacy "(no framework-trusted content injected this turn)"
Hook: continues with the rest of the injection (INDEX live, active spec, principles, stack, data-model, patterns)
Agent: reads the sentinel, sees MCP is on, can choose to call get_backlinks / get_neighbours / etc. instead of re-reading data-model.md + patterns.md in full
```

### action: dependencies

- [x] deps: zero new deps. Reuses existing bash + grep.

### action: out-of-scope

- [x] list: 3 explicit deferrals
- [x] approval: AUTONOMOUS DRAFT

#### §9 Out-of-scope

1. **Actual substitution of full-file cats with query slices** — that's the per-file-injection-budgets work happening in a parallel worktree (`feat/per-file-injection-budgets`). This PR's sentinel is the doctrine half; substitution is the mechanical half.
2. **Auto-calling `get_backlinks(active-feature)` and folding the result into the inject block** — depends on parsing the query's response shape and budgeting per-file. Deferred.
3. **Measuring the claimed token drop (per brick 007) end-to-end {best-effort: Sam at SHIP smoke}** — needs the substitution above. Deferred.

### action: non-functional

- [x] constraints: no perf/security/compliance impact (4 lines of bash + 1 grep; fires once per turn).

### action: acceptance-criteria

- [x] approval: AUTONOMOUS DRAFT — 1 AC (minimal viable wire).

#### §11 Acceptance criteria

- [ ] AC1: when `.sdd/config.md` has `mcp.enabled: true`, the user-prompt-submit.sh output includes the sentinel line *"[MCP graph queries available — prefer `get_backlinks` / `get_neighbours` / `get_pattern` / `get_references` / `search_within` over re-reading patterns.md or data-model.md in full]"* inside the `[FRAMEWORK INSTRUCTIONS]` block; when disabled, the legacy line stays {verify-by: T-001} — `tests/task-001.sh`

### action: signoff-steps

- [x] manual-steps: 1 manual smoke

#### §12 Sign-off

1. After this PR lands, on an MCP-enabled project, type `/next` and verify the agent's injected state block shows the MCP-sentinel line. {best-effort: Sam at SHIP smoke}

### action: wireframe

- [x] wireframe: skipped — backend hook prose, no UI

### action: plan-decompose

- [x] tasks: AUTONOMOUS DRAFT — 1 task T01 mapped 1:1 to AC1

#### §14 Plan-Decompose

- [x] T01: Replace the legacy line in `user-prompt-submit.sh` (live + templates) with conditional MCP-sentinel emission. Test: `tests/task-001.sh` GREEN. AC1 mapped. (Hook not manifest-tracked — no repin needed.)

**Status:** AUTONOMOUS DRAFT.

### action: edge-case-sweep

- [x] ec-sweep: 3 edge cases
- [x] ec-pick: AUTONOMOUS DRAFT

#### §15 Edge cases

1. EC#1 — `.sdd/config.md` missing. Bash `grep ... 2>/dev/null || true` swallows the error; legacy line fires.
2. EC#2 — `parameters.mcp.enabled: false` (explicit disable). Grep doesn't match `: true`; legacy line fires.
3. EC#3 — `mcp.enabled` spelled with quotes (`mcp.enabled: "true"`). Regex `:\s*true` matches; sentinel fires. Acceptable.

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full-autonomous

**Run mode:** full-autonomous

### action: build-task

(driven by §14 task T01)

### exit_checks

- [ ] C-build-tasks-green: every task is GREEN — `grep -cE '^- \[x\] T[0-9]+' "$SECTION_FILE"` matches T-row count in §14
