# safety hook blocks legitimate framework updates

[PHASE: SHIP]

**Active blocker:** SHIP — push-pr → CR → mark-shipped.

## PHASE: SPEC

### action: bug-problem

- [x] what: I can't save fixes to the framework's own files, even when the fix is correct.

### action: bug-repro

- [x] steps: 5 reliable steps to reproduce on the framework's own repo (post-#137):
  1. Edit any framework file the manifest tracks (e.g. `.sdd/scripts/start.sh`).
  2. Run `python3 /tmp/regen_manifest.py` so the manifest's `expected_sha256` matches the new file.
  3. `git add .sdd/scripts/start.sh .sdd/.cache/manifest.json`
  4. `git commit -m '[SDD] manifest: repin — legitimate fix to start.sh'` from a terminal (NOT through Claude Code).
  5. The commit gets refused by the moat with `[moat] manifest repin refused — no approval marker`, even though the marker text is in `-m`.

### action: bug-root-cause

- [x] cause: native git pre-commit hook fundamentally cannot see `-m` text. Git only writes `.git/COMMIT_EDITMSG` AFTER pre-commit fires for `-m` commits — verified empirically on 2026-05-03 by adding a debug pre-commit hook that read `.git/COMMIT_EDITMSG`: file was missing at pre-commit time. The moat's marker check ran in pre-commit, where the message was unreadable, so legitimate `-m` repins always failed via the native-git path. The PreToolUse path (Claude Code's hook layer) DID see the message and worked correctly; only the native-git terminal-commit path was broken.

### action: bug-fix

- [x] approval: minimum-diff fix — move the marker check from pre-commit to a new commit-msg hook (which DOES receive the message file path as $1, fully readable). Files touched:
  - `templates/.claude/hooks/commit-msg` (new — extension-less native git hook)
  - `templates/.claude/hooks/pre-commit-stage-verified.sh` (gate the existing marker block behind `git_commit_cmd`-non-empty so it only fires on the PreToolUse path; native-git path now defers to commit-msg)
  - `test/run-framework-test.sh` (mkproj_v08 fixture copies the new commit-msg hook; T142 regression test added)

  Defence in depth preserved: PreToolUse path still enforces the marker via pre-commit; native-git path enforces via commit-msg. Either path eventually refuses without the marker.

### action: bug-regression-test

- [x] approval: T142 in `test/run-framework-test.sh` — simulates a real manifest repin (edits a tracked file, recomputes hash, updates manifest's `expected_sha256`, stages both), then invokes commit-msg with two messages: (a) no marker → expects exit 1 + plain-English refusal; (b) with `[SDD] manifest: repin — ...` marker → expects exit 0. Both cases verified locally.

### Exit checks
- [x] C-spec-repro: repro steps captured in §2
- [x] C-spec-cause: root cause captured in §3
- [x] C-spec-fix: proposed fix recorded in §4
- [x] C-spec-regression: regression test drafted in §5

## PHASE: BUILD

### Build tasks (1 total · run mode: fix-then-test)

- [x] T01 GREEN: commit-msg hook lands; pre-commit gated behind PreToolUse-path; T142 regression passes.

### Exit checks (BUILD)
- [x] C-build-task-green: 1/1 task GREEN (197/197 framework tests + 31/31 claims audit + 161/161 MCP tests).

## PHASE: SHIP

### action: verify-test-run
- [x] run: 197/197 framework + 31/31 claims audit + 161/161 MCP tests GREEN locally.

### action: adversarial-review
- [ ] adversarial: CodeRabbit on the PR. Iterate until converged.

### action: push-pr
- [ ] pr: PR opened against main.

### action: verify-ci-green
- [ ] ci: all CI checks green.

### action: mark-shipped
- [ ] shipped: `.shipped` marker, INDEX.md row, decisions.md audit.

### Exit checks (SHIP)
- [ ] C-ship-pr-merged: PR merged with CI green
- [ ] C-ship-marker: `.shipped` present
- [ ] C-ship-index: INDEX.md `## Shipped` row added
