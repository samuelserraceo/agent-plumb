---
playbook: feature
---

# hook merge-commit exception (closes #220)

[PHASE: BUILD]

**Active blocker:** §14 T01 (lenient-mode in pre-commit-rules.sh)

## PHASE: SPEC

### action: brief-intake

- [x] brief: GitHub issue #220 IS the brief (4 ACs explicitly listed; fix shape sketched)

#### §0 Brief

**Source:** https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/220 — *"Pre-commit hooks need merge-commit exception (append-only + cofile-block both refuse legitimate parallel-stream merges)"* {verify-by: T-001 — AC1 tests the merge case now commits cleanly}

**Concrete failure observed:** Hit while merging `origin/main` into `sdd/009-feature-playbook-v2-brief-driven-spec-entry` (PR #219) after F008's #214 + #211 walking-skeleton merged to main. Resolved working tree had no conflict markers and `decisions.md` preserved HEAD's bytes as a strict prefix — but both pre-commit hooks fired anyway. Sam authorized a one-time bypass via `git commit-tree` plumbing (recorded in dae7758's commit message + this issue).

**Fix shape from the issue:** Detect merge-in-progress via `.git/MERGE_HEAD` (also `REBASE_HEAD`, `CHERRY_PICK_HEAD`) and apply lenient checks. The append-only check should still verify HEAD bytes ARE a strict prefix (the merge case explicitly satisfies this); cofile-block should skip entirely under merge (merges span classes by nature).

### action: problem

- [x] who: framework users running parallel feature branches that both touch shared notebooks (`decisions.md`, `INDEX.md`)
- [x] why-now: F009 ship surfaced the friction live — Sam authorized a `git commit-tree` bypass to merge dae7758, and the same shape will block any future cross-feature merge that touches shared append-only files
- [x] what-breaks: 3 concrete failure modes — append-only false-positive on legitimate merges where HEAD-bytes ARE a prefix; cofile-block false-positive on merges that legitimately span CLAIM+POLICY classes; users forced into `git commit-tree` plumbing bypass which loses the safety property the hooks exist to provide {verify-by: T-003 — AC3 tests genuine tampering still refused}

#### §1 Problem

#### who-has-it

Framework users (Sam et al.) running parallel feature branches that both touch shared append-only notebooks (`decisions.md`, `INDEX.md`, `patterns.md`). The problem fires whenever a feature branch needs to pull `main` forward to pick up a parallel feature's ship — exactly the workflow F009 hit when F008 + #211 landed mid-flight.

#### why-now

The F009/PR-#219 ship on 2026-05-10 hit the failure live. Sam authorized a one-time bypass via `git commit-tree` plumbing to land the merge — that bypass is now in main's history (commit `dae7758`) and is the documented workaround until v1.7. Without a fix, every future cross-feature merge that touches shared notebooks will need the same authorized-bypass ceremony — meaning the framework's safety hooks are routinely bypassed, eroding the trust property they exist to provide. The longer this stays unfixed, the more bypasses accumulate in main's history and the harder it becomes to distinguish "legitimate bypass" from "tampering bypass" in a forensic review.

#### what-breaks

Three concrete failure modes drawn from the issue body:

1. **Append-only false-positive on legitimate merges.** The `pre-commit-rules.sh` enforcement of `file_rules.append_only` on `decisions.md` checks that the staged blob's bytes start with HEAD's bytes. A merge commit that resolved cleanly with HEAD's bytes preserved as a strict prefix LOGICALLY satisfies this — but the current implementation refuses anyway because it doesn't differentiate "regular commit edited prior bytes" from "merge commit appended parallel stream's bytes after HEAD". {verify-by: T-001 — AC1 demonstrates the false-positive case is fixed}
2. **Cofile-block false-positive on merge commits spanning classes.** The cofile-block rule (CLAIM × POLICY) was designed for hand-crafted commits that should be split for auditability. A merge commit spans classes by nature — F008's `verification.json` (CLAIM) gets pulled in alongside F008's `manifest.json` + action files (POLICY) — and refusing it forces the bypass.
3. **Bypass-via-plumbing loses the safety property.** When users use `git commit-tree` to skirt the hooks, the entire pre-commit moat doesn't fire. That's appropriate for a one-off Sam-authorized incident, but UNDERMINES the framework's trust model if it becomes routine.

### action: success [SKIPPED]

- ⏭ metric: skipped — out of scope — §2 Success removed from the feature playbook in v1.6 PR-A (#219) per #207 Part 2; success metrics fold into §11 ACs by default

#### §2 Success [SKIPPED]

**Skipped on purpose** — out of scope — `success` action was removed from the feature playbook in v1.6 PR-A (#219, see CLAUDE.md `Never skip a non-skippable section` note for the backward-compat shape). Success metrics for this redesign fold into §11 ACs.

### action: user-stories

- [x] stories: 3 personas — Sam-shape (active framework user hitting the friction), parallel-session collaborator, future framework forensic reviewer

#### §3 User Stories

#### Story 1 — Sam-shape user merging main into a feature branch (primary)

> *As a framework user merging `main` into my feature branch after a parallel feature ships, I want the pre-commit hooks to recognise the merge case and accept the resolved working tree without bypass — so I don't have to authorize a `git commit-tree` plumbing detour every time.*

**Primary persona.** Direct fix for the failure mode that hit F009. If this story doesn't ship working, the v1.7 anchor hasn't shipped.

#### Story 2 — Parallel-session collaborator (Marco/Lucia-shape)

> *As a teammate running a parallel SDD session on a different feature, I want our two branches to merge cleanly when one ships — so we don't accumulate authorized-bypass commits that confuse the audit trail.*

This is the multi-user generalisation of Story 1. Same fix; broader applicability. Important for the SDD-on-pi cohort (post-F008) where multiple model-backed sessions can run in parallel.

#### Story 3 — Future framework forensic reviewer (audit-shape)

> *As someone auditing the framework's append-only contract a year from now, I want to be able to distinguish "legitimate parallel-merge byte-prefix-preserving append" from "tampering attempt that bypassed the hook" — so the framework's trust model holds up to scrutiny.*

The negative-space story: the fix should NOT make merges silently invisible to the audit trail. The lenient mode is GATED on `.git/MERGE_HEAD` etc., and the hook still LOGS that it ran in lenient mode (so an auditor can tell after the fact).

### action: ux-brief

- [x] brief: pre-commit hook UX — error message disappears for legitimate merges; appears for genuine violations; no agent-facing UX surface change

#### §4 UX & Design brief

**Primary surface(s):** the user-facing surface is the **pre-commit hook output** — what they see when `git commit` (after a merge) succeeds vs fires a refusal message.

| Surface | Old shape (pre-fix) | New shape (post-fix) |
|---|---|---|
| **Successful legitimate merge** | refused with multi-line "append-only violation" / "cofile-block" message → user must use `git commit-tree` bypass | clean exit; commit succeeds; merge lands in history |
| **Genuine non-merge tampering** | refused with multi-line plain-English explanation | UNCHANGED — still refused, same message |
| **Hook log line** | `[moat] append-only refused — staged bytes don't start with HEAD bytes` | (in merge mode) `[moat] merge-mode lenient: byte-prefix preserved, allowing` (NEW) |

**Tone / voice constraints (inherited):**

| Doctrine | Status |
|---|---|
| Plain English; jargon translated on first use | inherited from existing hook UX |
| Plain-English failure messages with concrete fix | inherited |
| Hook log lines short + audit-friendly | inherited |

**Visual / device constraints — N/A.** Pre-commit hook stderr renders in the user's terminal; no UI change.

**Mobile / desktop / responsive:** N/A.

### action: proposed-approach

- [x] approach: AUTONOMOUS DRAFT — single-cycle hook surgery in pre-commit-rules.sh + commit-msg, gated on `.git/MERGE_HEAD` / `REBASE_HEAD` / `CHERRY_PICK_HEAD`. No new files. ~30 lines added across 2 files. 4 ACs from the issue body, 1:1 with 4 BUILD tasks.

#### §5 Proposed approach

**Approach (chosen): single-cycle hook surgery, gated on `.git/MERGE_HEAD`.**

Add a merge-detection block at the top of `pre-commit-rules.sh` and `commit-msg` (the two hooks that hit the false-positive):

```bash
# Lenient mode: relax append-only + cofile-block under merge / rebase / cherry-pick.
if [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ] \
  || [ -f "$(git rev-parse --git-dir)/REBASE_HEAD" ] \
  || [ -f "$(git rev-parse --git-dir)/CHERRY_PICK_HEAD" ]; then
  LENIENT_MODE=1
  echo "[moat] merge/rebase/cherry-pick in progress — lenient mode" >&2
else
  LENIENT_MODE=0
fi
```

Then:

- **Append-only check:** in lenient mode, REPLACE the "staged bytes don't start with HEAD bytes" refusal with an EXPLICIT byte-prefix verification. If HEAD's bytes ARE a strict prefix of the staged bytes → allow (with a "byte-prefix preserved, allowing" log line per §4 UX). If HEAD's bytes are NOT a prefix → refuse — a merge that REWROTE prior entries is just as bad as a regular commit doing the same. {verify-by: T-003 — AC3 covers the tampering-still-refused case}
- **Cofile-block check:** in lenient mode, SKIP entirely. Merge commits span classes by nature (CLAIM + POLICY get pulled together routinely).
- **Manifest-pin check** (commit-msg): in lenient mode, KEEP the existing repin-marker requirement when manifest.json is staged. Merges that bring in upstream manifest changes legitimately ARE repins and SHOULD declare the marker. (Reasoning: the hook already requires the marker for intentional repins; merge-pulled repins are intentional in the same way.)

**Risk register:**
- **Lenient-mode bypass risk** — what if someone hand-crafts a `.git/MERGE_HEAD` file to trigger lenient mode without a real merge? Mitigation: the file is git-managed; tampering with it requires either git plumbing (which the user could already use to bypass the hook directly) or filesystem write (which means they have full repo access anyway). The lenient mode adds NO new bypass surface beyond what already exists.
- **REBASE_HEAD scope** — rebases CAN legitimately rewrite history. If we apply lenient mode to rebases, a malicious rebase could rewrite `decisions.md`. Mitigation: the byte-prefix check in lenient mode STILL FIRES for the append-only file. A rewriting rebase fails it; a fast-forward rebase passes it.
- **CHERRY_PICK_HEAD scope** — cherry-pick of a single commit is essentially a 1-commit merge. Same byte-prefix logic applies.

**Alternatives considered + rejected:**

1. **Just whitelist merge commits via SKIP_PRE_COMMIT env var.** Rejected: relies on the user remembering to set the env var on every merge; the friction Sam hit on F009 was that the merge happens in the IDE/CLI without ceremony.
2. **Require an explicit `--allow-merge` flag on the commit.** Rejected: breaks the "merge just works" UX; same friction as #1.
3. **Loosen the append-only check unconditionally to "byte-prefix preserved" (no merge gating).** Rejected: weakens the regular-commit property — a hand-crafted commit that appends after rewriting would slip through if the prefix happens to match by accident. The merge-mode gating preserves the regular-commit strictness while fixing the merge UX.

**4 sub-stages of work (T01-T04 below in §14):**
- T01: pre-commit-rules.sh — add MERGE_HEAD detection + lenient-mode logic for append-only
- T02: pre-commit-rules.sh — add lenient-mode skip for cofile-block
- T03: commit-msg hook — add MERGE_HEAD detection + verify it doesn't break the manifest-repin marker requirement
- T04: regression test (T217 framework test fixture) covering AC1-AC4

#### What this approach explicitly is NOT

- Not a redesign of the append-only contract — the byte-prefix check stays; only the merge-case interpretation changes.
- Not a removal of cofile-block — the rule still fires for non-merge commits.
- Not a relaxation of the manifest-repin marker — that one stays strict because legitimate merge repins SHOULD declare the marker.

**Status:** AUTONOMOUS DRAFT. Sam re-approves on return.

### action: data-contract

- [x] approval: AUTONOMOUS DRAFT — no new entities; behaviour change to existing 2 hook scripts only

#### §6 Data contract

**No new entities.** The fix is a behavioural change to two existing hook scripts:

- `.claude/hooks/pre-commit-rules.sh` — modified to add MERGE_HEAD detection + lenient-mode logic
- `.claude/hooks/commit-msg` — modified to add MERGE_HEAD detection (currently only relevant if the manifest-repin gating needs reconsidering — see §5)

No `.sdd/data-model.md` changes — no new tables, fields, relations, edge cases at the data layer.

**Status:** AUTONOMOUS DRAFT.

### action: flows

- [x] flows: 2 critical flows — legitimate merge + genuine tampering refused

#### §7 Flows

**Flow 1 — Legitimate parallel-feature merge succeeds without bypass (NEW behaviour, fixes the F009 friction):**

```text
User: git checkout sdd/<feature-branch>
User: git fetch origin main
User: git merge origin/main
Git: auto-merges decisions.md (HEAD bytes preserved as strict prefix; parallel content appended)
User: git commit  (or auto-commit if no conflicts)
Hook (pre-commit-rules.sh): detects .git/MERGE_HEAD → LENIENT_MODE=1
Hook: emits "[moat] merge/rebase/cherry-pick in progress — lenient mode" to stderr
Hook: append-only check verifies HEAD bytes ARE a strict prefix → PASS (was previously FAIL)
Hook: cofile-block check SKIPPED in lenient mode → PASS (was previously FAIL)
Hook: exits 0
Git: merge commit lands cleanly in history; no bypass needed
```

**Flow 2 — Genuine non-merge tampering still refused (regression-protection):**

```text
User: git commit  (regular commit, no merge in progress)
Hook (pre-commit-rules.sh): no .git/MERGE_HEAD detected → LENIENT_MODE=0
Hook: append-only check runs in strict mode (existing logic)
Hook: cofile-block check runs (existing logic)
If staged content REWROTE prior decisions.md entries:
  → append-only refuses with the existing plain-English error
If staged content mixes CLAIM + POLICY:
  → cofile-block refuses with the existing plain-English error
```

Implements **Story 1** (Sam-shape merge), **Story 2** (parallel-session collaborator), **Story 3** (forensic-reviewer audit trail preserved via the stderr log line in lenient mode).

**Status:** AUTONOMOUS DRAFT.

### action: dependencies

- [x] deps: zero new external services; pure bash + git plumbing already available

#### §8 Dependencies

**Zero new external dependencies.** The fix uses:

- `git rev-parse --git-dir` (already available; standard git plumbing)
- `[ -f path ]` (bash built-in)
- `>&2` redirect (bash built-in)

No new framework deps. No new services. Cost math: $0 — pure bash logic on existing toolchain.

**Status:** AUTONOMOUS DRAFT.

### action: out-of-scope

- [x] list: 4 explicit deferrals
- [x] approval: AUTONOMOUS DRAFT — Sam re-approves on return

#### §9 Out-of-scope

5 explicit deferrals for v1.7+ that this PR does NOT address:

1. **`stash` / `bisect` / `am` modes.** Other git operations could theoretically benefit from lenient mode, but they're rare in the SDD workflow. If they surface friction, file as separate issue.
2. **Lenient-mode telemetry / metrics.** The fix emits a stderr log line per invocation in lenient mode; we don't aggregate stats. If we want "how often is lenient mode used?" data, file a separate idea.
3. **Manifest-repin marker auto-detection in merge mode.** The fix KEEPS the existing requirement that manifest-repin commits declare the `[SDD] manifest: repin` marker — even in merge mode. If a merge brings in an upstream manifest repin, the merge commit message must include the marker. Auto-detecting "this is an inherited repin from main" is more complex than necessary for v1.7.
4. **Generalising lenient-mode to other future rules.** The fix adds 2 specific lenient-mode escape hatches (append-only, cofile-block). If future hooks need merge-aware behaviour, they'll add their own gates. We don't generalise prematurely (foundation 3: `never assume`).
5. **Documentation pass on merge UX in CLAUDE.md.** A short "merge-mode lenient hook behaviour" subsection could go in CLAUDE.md's Hooks section. Out of scope for the fix PR; could ship as a follow-up doc-only PR.

**Status:** AUTONOMOUS DRAFT.

### action: non-functional

- [x] constraints: no perf / security / compliance changes; pure bash logic in hooks

#### §10 Non-functional constraints

**Performance:** the merge-detection block adds 3 file-existence checks (`[ -f ... ]`) at the top of each hook invocation. Negligible. No new processes, no network, no sleep. {best-effort: 3 stat-style file checks per invocation; not benchmarked}

**Security:** the lenient-mode gate is `.git/MERGE_HEAD` etc., which are git-managed files. An attacker who can write to `.git/` to fake a merge can already bypass the hooks via `git commit-tree` directly — so the lenient gate adds no new attack surface. The byte-prefix check in lenient mode preserves the append-only property for the legitimate-merge case AND refuses tampering merges that rewrite prior entries. {verify-by: T-003 — AC3 tests the tampering-refused path}

**Compliance:** the audit trail is preserved via the stderr `[moat] merge-mode lenient: ...` log line. Forensic reviewers can grep `git log --grep` for merge commits and correlate with the hook log to see "this merge ran in lenient mode and the byte-prefix was verified".

**Status:** AUTONOMOUS DRAFT.

### action: acceptance-criteria

- [x] approval: 4 ACs verbatim from issue #220 body; all mechanically verifiable via T217 framework test fixture

#### §11 Acceptance criteria

The 4 ACs from issue #220 body, with `{verify-by:}` annotations:

- [ ] AC1: `git merge` of a parallel feature branch (where both branches appended to `decisions.md`) commits cleanly without bypass when the resolved working tree preserves HEAD's bytes as a strict prefix of `decisions.md`'s bytes {verify-by: T-217a} — `tests/task-001.sh` runs a fixture merge and asserts the hook exits 0
- [ ] AC2: A merge commit that mixes CLAIM (e.g., `verification.json`) + POLICY (e.g., `manifest.json`) files commits cleanly without bypass {verify-by: T-217b} — `tests/task-002.sh` runs a fixture merge with CLAIM + POLICY both staged and asserts hook exits 0
- [ ] AC3: A REGULAR (non-merge) commit that violates either rule still gets refused — lenient mode is GATED on `.git/MERGE_HEAD` etc., not unconditionally relaxed {verify-by: T-217c} — `tests/task-003.sh` runs a regular commit that rewrites `decisions.md` (or mixes CLAIM+POLICY) and asserts hook exits 1 with the existing refusal message
- [ ] AC4: The bypass-via-commit-tree path used for PR #219's merge is documented in `patterns.md` as the workaround for pre-v1.7 framework versions {verify-by: T-217d-doc} — `tests/task-004.sh` greps `patterns.md` for the documented pattern entry

**Status:** AUTONOMOUS DRAFT. Section-locked at this hash on Sam re-approval.

### action: signoff-steps

- [x] manual-steps: 3 manual smokes Sam runs before merging the v1.7 anchor

#### §12 Sign-off Steps

3 manual smoke tests Sam runs before merging the v1.7-A PR:

1. **Real cross-feature merge end-to-end** — start a fresh feature branch, append to `decisions.md` on it, merge in main (which has its own appends since the branch diverged), verify the merge commits cleanly via the hooks WITHOUT any bypass ceremony. Replicates the F009 / dae7758 scenario.
2. **Genuine tampering still refused** — on a regular commit (no merge in progress), try to rewrite a prior `decisions.md` entry. Verify the hook still refuses with the existing plain-English error. {verify-by: T-003 — AC3 is the automated equivalent of this smoke}
3. **Lint check** — `bash test/run-framework-test.sh` and `bash test/run-claims-audit.sh` both pass. (Audit count expected to increase if this PR adds a regression-lock claim.)

**Status:** AUTONOMOUS DRAFT.

### action: wireframe [SKIPPED]

- ⏭ wireframe: skipped — pre-commit hook output (no UI surface). Doctrine-as-UX applies (existing hook stderr lines).

#### §13 Wireframe [SKIPPED]

**Skipped on purpose** — pre-commit hooks have no UI surface. The user-facing change is the stderr line `[moat] merge/rebase/cherry-pick in progress — lenient mode` on legitimate merges, replacing the previous multi-line refusal. That's documented in §4 UX brief; no wireframe.html needed.

### action: plan-decompose

- [x] tasks: 4 tasks T01-T04 mapped 1:1 to AC1-AC4

#### §14 Plan-Decompose

**Walking-skeleton ordering applied (per #211).** F010's stack is bash-hook code + bash-test fixtures only (1 architectural layer: the hook layer). Walking-skeleton check: pass (single layer; T01 inherently exercises it). T00 bootstrap: skip (no runtime to scaffold).

Tasks 1:1 with ACs from §11:

- [ ] T01: Add MERGE_HEAD detection + lenient-mode logic to pre-commit-rules.sh (append-only path) — touches: .claude/hooks/pre-commit-rules.sh + templates/.claude/hooks/pre-commit-rules.sh + .sdd/.cache/manifest.json + templates/.sdd/.cache/manifest.json. Test: tests/task-001.sh (fixture merge with parallel decisions.md appends; assert hook exits 0). AC1 mapped.
- [ ] T02: Add lenient-mode SKIP for cofile-block in pre-commit-rules.sh — touches: .claude/hooks/pre-commit-rules.sh + templates/.claude/hooks/pre-commit-rules.sh + manifests. Test: tests/task-002.sh (fixture merge mixing CLAIM + POLICY; assert hook exits 0). AC2 mapped.
- [ ] T03: Verify regular (non-merge) commit still refused — touches: tests/task-003.sh (no code change; pure regression test). Test: tests/task-003.sh (regular commit that rewrites decisions.md; assert hook exits 1 with existing refusal message; second case mixes CLAIM+POLICY). AC3 mapped.
- [ ] T04: Document bypass-via-commit-tree pattern in patterns.md — touches: .sdd/patterns.md + templates/.sdd/patterns.md. Test: tests/task-004.sh (grep patterns.md for the workaround entry). AC4 mapped.

**Effort estimates:**
- T01: M (real hook code + fixture test)
- T02: S (single-line skip in lenient mode + fixture test)
- T03: S (test-only; no code change)
- T04: XS (single patterns.md append)

Total: 1×XS + 2×S + 1×M = ~feature-shaped, smallest of the v1.6 anchor cohort.

**Status:** AUTONOMOUS DRAFT. Sam re-approves on return.

### action: edge-case-sweep

- [x] ec-sweep: 5 edge cases drafted
- [x] ec-pick: AUTONOMOUS DRAFT — Sam picks which edges to add as ACs on return

#### §15 Edge-case sweep

5 edge cases worth surfacing (Sam picks which become ACs):

1. **EC#1 — `.git/MERGE_HEAD` left over from a failed/aborted merge.** If a previous `git merge` was aborted but `.git/MERGE_HEAD` wasn't cleaned, a subsequent regular commit would falsely trigger lenient mode. Mitigation: this is a git bug not ours; documented in EC, accepted as low risk.
2. **EC#2 — Octopus merge (3+ parents).** `git merge` can take multiple branches. The detection logic still works (`.git/MERGE_HEAD` exists) but the byte-prefix check needs to handle the case where multiple parents contributed to the resolved bytes. Mitigation: byte-prefix check is HEAD-against-staged; if HEAD's bytes are a strict prefix of staged, it doesn't matter how many other branches contributed.
3. **EC#3 — Squash merge.** `git merge --squash` does NOT create a `.git/MERGE_HEAD` (it stages content but doesn't commit). The user's `git commit` after a squash merge runs in regular mode (no lenient mode). Append-only refuses if the squash rewrote any bytes. ACCEPTED — squash merges should still be auditable as regular commits. {verify-by: T-003 — AC3's regular-commit shape covers squash merges}
4. **EC#4 — Cherry-pick that introduces conflicts then resolved.** `.git/CHERRY_PICK_HEAD` exists during the resolution; lenient mode applies. Same byte-prefix logic. ACCEPTED.
5. **EC#5 — Rebase onto a divergent branch.** `.git/REBASE_HEAD` exists during the rebase. Each rewritten commit triggers lenient mode. The byte-prefix check fires per-commit; a rebase that rewrites prior bytes fails it. ACCEPTED — rebases that legitimately fast-forward pass; rebases that rewrite refuse. {verify-by: T-003 — same byte-prefix check covers the rebase rewrite path}

**Status:** AUTONOMOUS DRAFT — Sam picks which (if any) become ACs on return.

### Exit checks

- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full-autonomous — Sam's pre-approved overnight directive ("non-stop progress until I wake up")

**Run mode:** full-autonomous

### action: build-task

(driven by §14 tasks T01-T04 — each task lands as one commit; test-first per CLAUDE.md)

### exit_checks

- [ ] C-build-tasks-green: every task is GREEN (test passing, code committed) — `grep -cE '^- \[x\] T[0-9]+' "$SECTION_FILE"` matches the count of T-rows in §14
