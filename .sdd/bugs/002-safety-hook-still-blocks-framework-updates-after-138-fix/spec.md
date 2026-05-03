# safety hook still blocks framework updates after 138 fix

[PHASE: SPEC]

**Active blocker:** §4 (next action: bug-fix)

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

- [ ] approval: draft the minimal-diff fix, name files touched, get user approval

### action: bug-regression-test

- [ ] approval: draft a test that fails before the fix and passes after, get user approval

### Exit checks
- [ ] C-spec-repro: repro steps captured in §2
- [ ] C-spec-cause: root cause captured in §3
- [ ] C-spec-fix: proposed fix recorded in §4
- [ ] C-spec-regression: regression test drafted in §5
