---
playbook: feature
---

# session-start hook prints a bootstrap-success signal (closes #164 bug 4)

[PHASE: BUILD]

**Active blocker:** §14 T01 (add success-signal echo to session-start.sh)

**Run mode:** full-autonomous

## PHASE: SPEC

### action: brief-intake

- [x] brief: GitHub issue #164 bug 4 IS the brief. SessionStart hook is silent on success; only `ls .sdd/` confirms bootstrap fired. Adds ONE bash line so users see a clear success cue post-install.

#### §0 Brief

**Source:** https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/164 — *"Smooth plugin first-install UX"*, bug 4: *"No 'did install actually work?' signal — SessionStart hook output is silent on success; only way to verify bootstrap fired is `ls .sdd/`."*

**Fix shape (scope-trimmed to bug 4 only):** one bash line added to `templates/.claude/hooks/session-start.sh` (and mirror) that echoes `[SDD bootstrap] ready — .sdd/ scaffold ready` to stdout when the hook detects a freshly-initialised SDD project (`.sdd/INDEX.md` exists and `.shipped` marker count == 0). When .sdd/ already has shipped content, the signal suppresses (returning users don't need the cue).

**Out of scope (deferred to follow-ups in same #164):**
- Bug 1: two-restart bootstrap UX
- Bug 2: three separate caches when upgrading
- Bug 3: v1.4.0 → v1.4.3 cascade (already fixed)

**Target:** v1.8.2 patch.

### action: problem

- [x] who: framework first-installers (`/plugin install sdd@sdd-marketplace` then SessionStart bootstraps); they see nothing in chat to confirm it worked.
- [x] why-now: v1.7 four-pack + v1.8 anchor done; first-install UX is the surface most new users see; signal-on-success is a 1-line fix with zero risk.
- [x] what-breaks: user runs the install, gets a silent prompt, doesn't know whether to retry or proceed. Anecdotal "did it work?" question every install. {verify-by: T-001}

#### §1 Problem

#### who-has-it

First-time SDD users running `/plugin install sdd@sdd-marketplace` on a fresh project. The SessionStart hook fires next session and runs `bin/sdd-init.sh` which scaffolds `.sdd/`. Without a printed success line the user can't tell whether the bootstrap landed.

#### why-now

#164 bug 4 surfaced live during Sam's v1.4.x install dance (2026-05-05). 4 v1.4 patches in 2 hours all turned on silent failures. Fixing the signal cue closes the "did it work?" anxiety in one line.

#### what-breaks

1. **Silent install** — user types `/plugin install`, sees no confirmation, retries.
2. **No way to tell first-install from upgrade** — both fire SessionStart silently {verify-by: T-001}.
3. **Anecdotal install support burden** — each "did it work?" message in chat is recoverable noise.

### action: user-stories

- [x] stories: 1 persona — first-install user

#### §3 User Stories

> *As a first-time SDD user, after `/plugin install` finishes, I want a clear one-line cue in the chat that says "[SDD bootstrap] ready — .sdd/ scaffold ready" so I know it worked and can move to my first `/sdd-setup` step without re-trying or asking the agent "did it work?".*

### action: ux-brief

- [x] brief: no UI surface — one line of stdout from the hook.

#### §4 UX & Design brief

**Primary surface:** chat output post-install.

**Before fix:** silent. Only `ls .sdd/` confirms.
**After fix:** `[SDD bootstrap] ready — .sdd/ scaffold ready` (single line, on first install only).

### action: proposed-approach

- [x] approval: AUTONOMOUS DRAFT — one-line echo in session-start.sh, gated on first-install detection.

#### §5 Proposed approach

In `templates/.claude/hooks/session-start.sh` (mirror to live), after the existing bootstrap logic, detect the first-install signal: `.sdd/INDEX.md` exists AND no `.sdd/features/*/.shipped` markers AND no `.sdd/.cache/manifest.json` modifications since scaffold. When true, echo `[SDD bootstrap] ready — .sdd/ scaffold ready` to stdout.

**Two files ship:**
- `templates/.claude/hooks/session-start.sh`
- `.claude/hooks/session-start.sh` (mirror)

Both manifest-tracked? Need to check; per F014 I learned hooks may not be in the manifest.

**Risk:** none material. The signal is purely additive; existing behaviour unchanged.

### action: data-contract

- [x] approval: AUTONOMOUS DRAFT — no entities.

#### §6 Data contract

No new entities. Reads existing `.sdd/INDEX.md` + `.sdd/features/` to detect first-install state.

### action: flows

- [x] flows: 1 flow

#### §7 Flows

```text
User: /plugin install sdd@sdd-marketplace
Claude Code: SessionStart hook fires next session
Hook: scaffolds .sdd/ (existing behaviour)
Hook: detects first-install (INDEX.md exists, zero .shipped, fresh manifest)
Hook: echoes "[SDD bootstrap] ready — .sdd/ scaffold ready"
User: sees cue; runs /sdd-setup
```

### action: dependencies

- [x] deps: zero new deps.

### action: out-of-scope

- [x] list: 3 deferrals
- [x] approval: AUTONOMOUS DRAFT

#### §9 Out-of-scope

1. #164 bug 1 (two-restart bootstrap UX) — different surface; deferred.
2. #164 bug 2 (three cache locations on upgrade) — different concern; deferred.
3. Signalling on upgrade (not just first-install) — separate need; deferred.

### action: non-functional

- [x] constraints: no perf/security impact (one echo line).

### action: acceptance-criteria

- [x] approval: AUTONOMOUS DRAFT — 1 AC

#### §11 Acceptance criteria

- [ ] AC1: When session-start.sh runs on a freshly-scaffolded `.sdd/` (INDEX.md exists, zero `.shipped` markers), stdout contains the literal line `[SDD bootstrap] ready — .sdd/ scaffold ready`. When `.shipped` markers exist (returning user), the signal suppresses. {verify-by: T-001} — `tests/task-001.sh`

### action: signoff-steps

- [x] manual-steps: 1 smoke

#### §12 Sign-off

1. Run `/plugin install sdd@sdd-marketplace` on a fresh project. Confirm the success line appears in chat. {best-effort: Sam at SHIP smoke}

### action: wireframe

- [x] wireframe: skipped — backend hook, no UI

### action: plan-decompose

- [x] tasks: AUTONOMOUS DRAFT — 1 task T01

#### §14 Plan-Decompose

- [ ] T01: Add first-install detection + success-signal echo to session-start.sh (templates + live mirror). Test: `tests/task-001.sh` GREEN. AC1 mapped.

### action: edge-case-sweep

- [x] ec-sweep: 2 EC
- [x] ec-pick: AUTONOMOUS DRAFT

#### §15 Edge cases

1. EC#1 — partially-scaffolded `.sdd/` (INDEX.md missing but features/ exists). Out of scope; treat as fresh install OK.
2. EC#2 — upgrade from old SDD project (existing `.shipped` markers). Signal suppresses. Verified by T-001 negative case.

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
