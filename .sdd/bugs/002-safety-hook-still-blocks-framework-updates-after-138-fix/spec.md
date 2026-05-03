# safety hook still blocks framework updates after 138 fix

[PHASE: SPEC]

**Active blocker:** SHIP (BUILD done; T01 + T02 GREEN; 200/200 framework tests passing)

## PHASE: SPEC

### action: bug-problem

- [x] what: Even after the #138 fix, I still can't save updates to the framework's own files — two more bugs in the same safety hook are also getting in the way.

### action: bug-repro

- [x] steps: two repro recipes for two distinct bugs in `pre-commit-stage-verified.sh`.

  **Bug A repro** (multi-manifest path confuses the hook):
  1. Edit any framework file the manifest tracks (e.g. add a comment to `.sdd/scripts/start.sh`).
  2. Recompute its fingerprint and write the new value into BOTH `.sdd/.cache/manifest.json` AND `templates/.sdd/.cache/manifest.json`.
  3. Stage all three: `git add .sdd/scripts/start.sh .sdd/.cache/manifest.json templates/.sdd/.cache/manifest.json`.
  4. `git commit -m '[SDD] manifest: repin — testing'`.
  5. The save fails with `[moat] cannot extract staged manifest blob from index`. The hook's regex `(^|/)\.sdd/\.cache/manifest\.json$` (line ~70) matched both manifest paths, joined them with a newline, and `git show :<multi-line-path>` returned non-zero.

  **Bug B repro** (per-file HEAD vs staged-manifest hash check fires on every legitimate repin):
  1. Edit any framework file the manifest tracks (e.g. `.sdd/scripts/start.sh`).
  2. Recompute its fingerprint and write the new value into JUST `.sdd/.cache/manifest.json`. Leave the template manifest unchanged.
  3. Stage: `git add .sdd/scripts/start.sh .sdd/.cache/manifest.json`.
  4. `git commit -m '[SDD] manifest: repin — testing'`.
  5. The save fails with `[moat] One or more SDD framework files have changed... hash mismatch — HEAD (cross-commit attack? working tree looks clean but HEAD has tampered content)`. The check at line ~643 (`if head_actual != expected:`) compared HEAD's old `start.sh` content hash against the new staged manifest's `expected_sha256` — they differ, because that is what a legitimate repin IS. With or without the `[SDD] manifest: repin` marker. {verify-by: T-002-bug-b-repro}

  Confirmed live by the #138 author on 2026-05-03 via direct python-heredoc test against a temp git repo. Bug B fires regardless of marker presence; the marker check moving to commit-msg in #138 sits in the trust-baseline block (line ~317), not the file-integrity loop (line ~614+).

### action: bug-root-cause

- [x] cause: two distinct root causes in the same hook.
  - **Bug A:** the safety hook's search for the staged fingerprint list grabs both copies (live + template) when both are in one commit, producing a two-line value that breaks the next read step (`git show :<multi-line>` returns non-zero).
  - **Bug B:** the safety hook compares the OLD content of each framework file (from git history, via `git show HEAD:<path>`) against the NEW fingerprint (in the staged update) — but a legitimate repin is exactly when those two should differ, so the check trips on every real framework update. The marker check moving to commit-msg in #138 lives in the trust-baseline block, not the file-integrity loop, so #138 doesn't gate this path.

### action: bug-fix

- [x] approval: minimum-diff fix in two places of `templates/.claude/hooks/pre-commit-stage-verified.sh` — approved by Sam on 2026-05-03.

  **Files touched:**
  - `templates/.claude/hooks/pre-commit-stage-verified.sh` (the fix; ~6 lines changed)
  - `test/run-framework-test.sh` (regression tests T143 + T144)

  **Bug A fix** — tighten the manifest path search.
  - Current: line 70 regex `(^|/)\.sdd/\.cache/manifest\.json$` matches both `.sdd/.cache/manifest.json` and `templates/.sdd/.cache/manifest.json`.
  - Change to: `^\.sdd/\.cache/manifest\.json$` (anchored to start; only the live manifest matches).
  - Why safe: the templates manifest is data — user projects don't read from it as their live manifest. The moat protects the live manifest only.

  **Bug B fix** — skip the per-file HEAD content check when both the manifest is being repinned AND the file is staged in this commit.
  - In the file-integrity loop around line 614, add a guard: pass the staged-files list into the python block as `STAGED_FILES` env var (newline-separated), parse as a set, and `continue` past the HEAD check **only when `staged_manifest_path` is non-empty AND `rel` is in `staged_files_set`** (the dual condition).
  - Why safe: the cross-commit attack the HEAD check defends against is exactly *"HEAD has tampered content + working tree reverted to clean + manifest unchanged"* — in that attack the manifest is NOT staged, so `staged_manifest_path` is empty and the dual condition fails, so the HEAD check still fires. Only when BOTH the manifest is being repinned AND the file is in the staged set is the HEAD check skipped — that's the signature of a legitimate repin. T45 (cross-commit attack defence) was used to verify: an earlier single-condition version of this fix (skip if file is staged, regardless of manifest) broke T45 because `git checkout HEAD~1 -- file` stages the revert; the dual condition closes that bypass while still fixing the false-positive on legitimate repins. {verify-by: T143 + T144 + T145 + T45}

  Defence-in-depth preserved on both fixes: WT hash check + manifest trust-baseline check + marker requirement (in commit-msg) all still apply.

### action: bug-regression-test

- [x] approval: T143 (Bug A) + T144 (Bug B) in `test/run-framework-test.sh`. Approved by Sam on 2026-05-03.

  **T143 — Bug A regression** (multi-manifest path)
  - Fixture: temp project via `mkproj_v08`. Edit a tracked framework file. Recompute its fingerprint. Write the new value into BOTH `.sdd/.cache/manifest.json` AND `templates/.sdd/.cache/manifest.json`. Stage all three.
  - Run: `pre-commit-stage-verified.sh` with synthetic stdin `{"tool_input":{"command":"git commit -m '[SDD] manifest: repin — testing'"}}`.
  - Before fix: exit non-zero, stderr contains `cannot extract staged manifest blob from index`.
  - After fix: exit 0, no stderr.

  **T144 — Bug B regression** (HEAD content vs new fingerprint)
  - Fixture: temp project. Edit a tracked framework file. Recompute its fingerprint. Write the new value into JUST `.sdd/.cache/manifest.json`. Stage the file edit + the live manifest update only.
  - Run: same hook, same synthetic command with the marker.
  - Before fix: exit non-zero, stderr contains `hash mismatch — HEAD (cross-commit attack`.
  - After fix: exit 0, no stderr.

  Both tests verify RED before fix and GREEN after, per the framework's mutation-verified test discipline.

### Exit checks

- [x] C-spec-repro: repro steps captured in §2
- [x] C-spec-cause: root cause captured in §3
- [x] C-spec-fix: proposed fix recorded in §4
- [x] C-spec-regression: regression test drafted in §5

## PHASE: BUILD

### Build tasks (2 total · run mode: tests-then-fix)

- [x] T01 GREEN: T143 + T144 land in `test/run-framework-test.sh`; Bug A regex tightening + Bug B staged-files guard applied to `templates/.claude/hooks/pre-commit-stage-verified.sh`; mirror copied to `.claude/hooks/`. Verified RED before the fix (both new tests failed on the original hook with their expected error strings), then GREEN after — full suite 199/199 passing, including T45 cross-commit attack defence still firing on the genuine-attack scenario.
- [x] T02 GREEN: T145 added. Bug D (4th bug surfaced during real-world Tier 0 validation) fixed. The native-git shim sends synthetic `{"tool_input":{"command":"git commit"}}` (non-empty but no -m / -F visible). The #138 fix gated the trust-baseline marker check behind `git_commit_cmd` truthy, but synthetic is truthy too, so legitimate terminal repins still got refused. Fix: also require a message-flag (-m / -F / --message / --file) in the cmd before running the marker check; defer to commit-msg when absent. Verified RED before fix (T145 failed with "manifest repin refused"), GREEN after. Full suite 200/200 passing.

### Exit checks (BUILD)

- [x] C-build-task-green: 2/2 tasks GREEN — 200/200 framework tests passing.
