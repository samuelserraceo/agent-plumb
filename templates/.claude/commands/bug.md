---
description: Capture and fix a bug — uses the smaller bug rubric (skips UX/dependencies/etc, focuses on diagnosis + regression test).
---

$ARGUMENTS

Start a new bug-fix workflow. Bugs use a smaller rubric than features — see `.sdd/rubric-bug.md`.

## Trigger conditions

- Use this command when the user reports something broken in shipped or in-flight code.
- Do NOT use it for new functionality — that's `/next` (feature) territory.
- If during SPEC you discover the "bug" actually requires significant new design / multiple data-model changes, STOP and tell the user "this looks like a feature, not a bug — want to escalate via `/promote-bug-to-feature <id>`?".

## Bootstrap protocol (MUST follow this exact order)

Same shape as `/next`'s feature bootstrap, but using the bug rubric and bug branch naming.

**Step 1 — Confirm git is initialized + on main + clean.** Same as `/next` Section A. If not, halt and tell the user in plain English what to do.

**Step 2 — Pick the bug id and slug.**
- Scan `.sdd/features/` for the highest existing `NNN-` prefix (across all types — features and bugs share the numbering space). New id = highest + 1.
- Slug from the user's description, kebab-case, ≤40 chars, prefix with `bug-`.
- Final folder name: `<id>-bug-<slug>` (e.g., `005-bug-rate-limit-resets-on-hmr`).

**Step 3 — Create the bug branch FROM main BEFORE any file writes.**
```bash
git checkout -b sdd/<id>-bug-<slug>
```

**Step 4 — Create the bug feature folder.**
```bash
cp -R .sdd/features/_template .sdd/features/<id>-bug-<slug>
cp .sdd/rubric-bug.md .sdd/features/<id>-bug-<slug>/spec.md
```
Note: bug rubric does NOT include a wireframe section — leave the `_template/wireframe.html` in place but mark it `<!-- skipped: bug -->` if you touch it.

**Step 5 — Edit `spec.md` header.**
- Replace `<bug short name>` with the user's description
- Set `**Branch:**` to the new branch name
- Set `[TYPE: BUG]` and `[PHASE: SPEC]`
- Set `Active blocker` to `§1 Problem — what goes wrong`

**Step 6 — Update `.sdd/INDEX.md`.**
- `**Active:**` line → `features/<id>-bug-<slug>   [BUG]   [SPEC]   blocker: §1 Problem`
- Add to `## In flight` list with `[BUG]` tag

**Step 7 — Hold the bootstrap commit.**
DO NOT commit yet. The pre-commit-block hook would refuse because every section has `[ ]`. Instead: tell the user "Bug folder + branch ready. Now I need §1 Problem — can you reproduce it?". When they answer, commit scaffold + §1 fill together as `[SDD:<id>-bug-<slug>] spec: scaffold + §1 Problem`.

## Phases (different from feature)

Bug phases skip PLAN. Order: SPEC → BUILD → VERIFY → LEARN.

In BUILD:
- ONE regression test that FAILS on current code
- Write the fix
- Test PASSES
- Run the affected feature's full suite — must still pass
- Commit `[SDD:<id>-bug-<slug>] fix: <one-line summary>`

In LEARN:
- The §LEARN "Why we missed it" section feeds directly into `patterns.md` so the same class of bug doesn't ship again.

## End your turn

Per CLAUDE.md, end with the explicit next-action prompt:

> Bug `<id>-bug-<slug>` started on branch `sdd/<id>-bug-<slug>`. First question: §1 — what exactly is broken? Give me one sentence + the steps to reproduce.
