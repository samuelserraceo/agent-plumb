---
playbook: feature
---

# promote-legacy-queued.sh migrator for pre-v1.5.2 PHASE state drift (closes #206)

[PHASE: SPEC]

**Active blocker:** §6 data-contract

## PHASE: SPEC

### action: brief-intake

- [x] brief: GitHub issue #206 IS the brief. Pre-v1.5.2 projects have backlog features stored as `[PHASE: SPEC]` instead of `[PHASE: QUEUED]`; ship a one-shot migrator + document it in CLAUDE.md.

#### §0 Brief

**Source:** https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/206 — *"Pre-v1.5.2 queued features show `[PHASE: SPEC, §1 done]` not `[PHASE: QUEUED]` (#169 retro-fix)"*

**Problem (verbatim from issue):** Projects scaffolded before v1.5.2 — which added the `[PHASE: QUEUED]` pre-active state via #169 — have backlog features written with `[PHASE: SPEC]` instead of `[PHASE: QUEUED]`. Their INDEX.md rows look like they're in flight at SPEC rather than queued waiting for `/promote-to-active`. `/next` would happily advance them.

**Affected project (live audit 2026-05-11):** pipelogic_v2's F02-F15 all carry `[PHASE: SPEC]` despite being backlog. Plus any other multi-feature project bootstrapped before v1.5.2.

**Fix shape (two-step):**
1. **One-shot migrator** `bash .sdd/scripts/promote-legacy-queued.sh` — scans every `.sdd/<work-item-folder>/<id>-<slug>/spec.md`; if the INDEX.md row marks the item as backlog/queued but the spec.md PHASE is not `QUEUED`, flip the PHASE marker AND update the INDEX.md row to the canonical `(scaffolded, PHASE: QUEUED)` shape.
2. **Documentation** in CLAUDE.md "Multi-feature parallel work" section: one paragraph noting the migration path and when to run it (after `sdd-migrate.sh --apply`).

**Severity:** Minor — only affects pre-v1.5.2 projects. New projects don't hit this.

**Target:** v1.7 patch line (alongside v1.7.0 hook merge-exception + v1.7.1 hash-bold-strip).

### action: problem

- [x] who: users of SDD projects bootstrapped before v1.5.2 (#169's QUEUED state). Direct hit: Sam's pipelogic_v2 F02-F15.
- [x] why-now: framework now says `/next` should stop on QUEUED, but legacy specs still say `[PHASE: SPEC]` for backlog → silent state-machine drift {verify-by: T-001}.
- [x] what-breaks: `/next` on pipelogic_v2 F02 would advance instead of stopping; INDEX row says "queued" while spec.md says SPEC (source-of-truth ambiguity); backlog items read as in-flight {verify-by: T-001}.

#### §1 Problem

#### who-has-it

Users of SDD projects bootstrapped before v1.5.2 (the release that introduced the `[PHASE: QUEUED]` pre-active state via #169). Direct concrete hit: Sam's `pipelogic_v2` project — all 14 backlog features F02-F15 were scaffolded on 2026-05-05 (before v1.5.2's 2026-05-07 ship) and still carry `[PHASE: SPEC]` in their spec.md files even though their INDEX.md rows describe them as queued/backlog.

#### why-now

v1.5.2's #169 fix added QUEUED as a first-class state and `/next` is documented to stop on any work item whose spec.md says `[PHASE: QUEUED]` {verify-by: T-001 — the migrator's regression test confirms the stop fires on the canonical marker}. Plus the v1.4 `sdd-migrate.sh --apply` flow now ships, so old projects ARE being upgraded to the latest framework — and the moment they upgrade past v1.5.2, the documented behaviour doesn't kick in for their legacy backlog items because those items' PHASE markers are stale.

#### what-breaks

3 concrete failure modes {verify-by: T-001 / T-002 / T-003}:

1. **`/next` advances a queued feature silently.** Sam runs `/next` on `pipelogic_v2`. Framework reads `.sdd/features/002-X/spec.md`, sees `[PHASE: SPEC]`, doesn't stop, walks the agent through §1's `who` question — even though F02 is supposed to be parked {verify-by: T-001}.
2. **Source-of-truth ambiguity.** INDEX.md row `- features/002-X — Y (PHASE: QUEUED)` contradicts spec.md `[PHASE: SPEC]`. Which is right? `resolve-active.sh` reads the branch + INDEX, not the spec.md — but `pre-commit-stage-verified.sh` reads spec.md PHASE. Mixed signals when the two disagree.
3. **Reading INDEX after a ship looks wrong.** F01 just shipped, F02-F15 are listed below; user reads them as "all in flight at SPEC" instead of "parked at QUEUED waiting for promote-to-active" → false sense of progress.

### action: user-stories

- [x] stories: 2 personas — legacy-project upgrader (Sam-shape running sdd-migrate.sh on an old project) and INDEX reader (anyone trying to tell parked vs in-flight at a glance)

#### §3 User Stories

#### Story 1 — Legacy-project upgrader

> *As Sam (or any framework user) running `bash .sdd/scripts/sdd-migrate.sh --apply` on a pre-v1.5.2 project, I want to be told (after the upgrade) "run `bash .sdd/scripts/promote-legacy-queued.sh` to fix N legacy backlog items" — and after I run it, I want `/next` to start refusing on those backlog features the way the framework now documents.*

#### Story 2 — INDEX reader

> *As someone reading `.sdd/INDEX.md` after a feature ships, I want backlog features to show as `(scaffolded, PHASE: QUEUED)` — the canonical v1.5.2+ shape — so I can tell at a glance that F02-F15 are parked-waiting-for-promote, not in-flight at SPEC.*

### action: ux-brief

- [x] brief: no UI surface — backend script that exits with a plain-English summary. Success is "moat starts refusing on legacy backlog items after one `bash promote-legacy-queued.sh` run."

#### §4 UX & Design brief

**Primary surface:** the script's stdout summary after a run — what the user reads to confirm what changed.

**Output shape (target):**

```
[promote-legacy-queued] scanning .sdd/features/ + .sdd/bugs/ + .sdd/refactors/ ...
[promote-legacy-queued] inspected: 16 work items
[promote-legacy-queued] migrated:  14 items (F02-F15 spec.md PHASE flipped to QUEUED)
[promote-legacy-queued] INDEX.md:  14 rows updated to canonical (scaffolded, PHASE: QUEUED)
[promote-legacy-queued] unchanged: 2 items (F01 already SHIPPED; F16 already QUEUED)
[promote-legacy-queued] done. Commit the staged changes when you're ready.
```

**Tone:** terse, concrete, "what I changed vs what I left alone". No jargon. Counts at top so the user has a single number to react to (per the non-technical-user lens 'show a total').

**No HTML wireframe** — backend script, exit-status driven. Skip §13.

### action: proposed-approach

- [x] approval: APPROVED by Sam — one-shot `promote-legacy-queued.sh` migrator that flips spec.md PHASE + canonicalises INDEX row in the same pass; skip cold `.shipped` items; stage but don't auto-commit.

#### §5 Proposed approach

**Approach (chosen):** ship `bash .sdd/scripts/promote-legacy-queued.sh` as a one-shot opt-in migrator. Run it once per old project after `sdd-migrate.sh --apply` lands the latest framework. The script:

1. Walks `.sdd/features/`, `.sdd/bugs/`, `.sdd/refactors/` (the three work-item folders).
2. For each `<id>-<slug>/spec.md`, skips if `.shipped` marker exists (cold feature) {verify-by: T-003}.
3. Reads the first `[PHASE: X]` line after the H1 in `spec.md`.
4. Reads `.sdd/INDEX.md`. Locates the row whose path matches this folder.
5. If the INDEX row's text matches `queued|Backlog|backlog` AND the spec.md PHASE is not already `QUEUED` → flip both {verify-by: T-001}:
   - `spec.md`: `[PHASE: SPEC]` → `[PHASE: QUEUED]`
   - `INDEX.md` row: append `(scaffolded, PHASE: QUEUED)` if not already canonical {verify-by: T-002}.
6. Stages the changes via `git add` but does NOT commit. User inspects + commits via their normal workflow.
7. Prints a 5-line plain-English summary (inspected / migrated / INDEX-updated / unchanged / done).

**Two files ship (manifest-tracked):**
- `.sdd/scripts/promote-legacy-queued.sh` (live framework copy)
- `templates/.sdd/scripts/promote-legacy-queued.sh` (downstream-project copy — identical bytes)

Both copies' `expected_sha256` go into both manifests (`.sdd/.cache/manifest.json` + `templates/.sdd/.cache/manifest.json`) using the normalised SHA-256 the framework's other manifest entries use.

**Doc update (same PR):**
- `templates/CLAUDE.md` "Multi-feature parallel work" section: one paragraph naming the migrator + when to run it (after `sdd-migrate.sh --apply` on a pre-v1.5.2 project).
- `CLAUDE.md` (live framework copy): same paragraph.

**Alternatives considered + rejected:**

1. *Minimum-diff: just flip spec.md PHASE, leave INDEX.md alone.* Rejected — leaves INDEX row drifted from canonical shape; future `/status` runs read partially-migrated state.
2. *Auto-run at sdd-migrate.sh time (transparent migration).* Rejected — migration is a destructive-shape change to user-edited content; explicit one-shot opt-in is the framework's discipline for state-machine fixes (same pattern as `sdd-migrate.sh --apply`).

**Risk register:**
- **False positives:** a legacy project with non-standard INDEX shape — script detects nothing, exits clean, no damage {verify-by: T-002 — fixture without canonical rows leaves spec.md PHASE alone}.
- **Partial state:** INDEX row says queued but spec.md says BUILD (user manually advanced) — script LEAVES it alone, prints a warning row in the summary {verify-by: T-004}.
- **Re-run idempotence:** running twice on an already-migrated project is a no-op — second run reports 0 migrated, all canonical {verify-by: T-005}.

**Status:** APPROVED by Sam (turn confirmation; will append decisions.md in this commit).

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
