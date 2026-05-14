# Cross-session audit — 2026-05-12 / 8-commit batch (1d55c85 → df032eb)

> Auditor: main-session agent (this conversation).
> Subject: parallel session in worktree `claude/clever-herschel-af8c27`, 8 commits to main between `1d55c85` and `df032eb`.
> Auditor instruction: *"Don't trust my framing. Verify the actual state."*
> Audit date: 2026-05-14 (post-merge of PR #260 / #261 / #262).

---

## 1. Summary verdict — **GREEN**

All 8 commits do what their messages claim. All 6 specific bugs they fix are independently verifiable. The framework-level change in `df032eb` (graph-integrity on push) is justified and CI-confirmed working. The stub-folder overlap with PR #260's `README.md` reconciled cleanly with no conflicts. No regressions found on main. PR #260 has since merged (commit `a5c3341`), PR #261 + #262 also merged.

One local-only false alarm during the audit (13 framework tests failing on my workstation) traced to a single uncommitted `templates/.sdd/actions/problem.md` modification — a literal `DRIFT-TEST-MARKER` line leaked by T120's own drift-detection test mid-run. Reverted via `git checkout HEAD --`; re-run is clean. **This is the same shape of leak that commit `1d55c85` itself cleaned up** — meaning T120 still has a cleanup-on-crash gap that should be filed as a fresh `/bug`.

---

## 2. Per-commit findings

### `1d55c85` — chore: remove DRIFT-TEST-MARKER stray
- ✅ **Confirmed working.** `grep -nE "DRIFT-TEST-MARKER" templates/.sdd/actions/problem.md` returns empty (exit 1) on main HEAD. The 4-line deletion lands cleanly. Pure cleanup, zero behavioural impact.
- *Tangent:* during my audit the marker re-appeared as a working-tree mod, confirming T120's cleanup-on-crash gap is still real. **Recommend fresh `/bug` to put T120's marker-cleanup in a bash `trap` so it survives mid-test crashes.**

### `5d9fb60` — [SDD] audit-close: backlog book closed
- ✅ **Confirmed working.** 5 new mark-shipped entries in `.sdd/decisions.md` (lines 603-619) for F021 / F024 / F025 / F026 / F027 dated 2026-05-12T12:03-12:17. Each references the correct PR (#254 / #255 / #256 / #257 / #258) and merge SHA. INDEX.md cleared (Active=none, In flight=empty, 5 entries in Shipped).
- ✅ **Append-only contract HELD.** `diff <(git show 5d9fb60^:.sdd/decisions.md | head -50) <(head -50 .sdd/decisions.md)` returns empty — strict prefix preserved. Lines grew from 601 → 625 (24 lines added, 0 lines edited or removed).
- *Note:* this commit also introduced the broken `[[2026-05-12-backlog-book-close]]` wiki-link that surfaced the framework-level fix in `df032eb`. The agent fixed its own bug — see §5.

### `2558a5d` — fix(F027 spec): add `{verify-by}` to exit-check lines
- ✅ **Confirmed working.** `.sdd/features/027-sdd-setup-verifies-declared-tools-closes-165/spec.md` has `{verify-by: T28X}` annotations on AC1-AC6 (lines 60-65) plus the §10 non-functional constraints line. `bash .sdd/scripts/lint-no-theatre.sh .sdd/features/027-.../spec.md` exits clean. T141 anti-theatre lint test still GREEN in the re-run.

### `2a7187d` — fix(playwright): pill assertion v1.6.0 → v1.9
- ✅ **Confirmed working.** `tests/playwright/walkthrough.spec.ts:21-27` now reads:
  ```js
  test("page loads with the v1.0→v1.9 shipped pill", async ({ page }) => {
    const pill = page.locator(".pill-v10").first();
    await expect(pill).toContainText("v1.0 → v1.9 shipped");
  ```
  Matches the actual walkthrough.html pill state. Playwright job on main HEAD: **success**.

### `4df7f39` — fix(claims-audit): 5 .shipped markers + slash-command ceiling bump
- ✅ **5 .shipped markers** present and 0 bytes each (F021/F024/F025/F026/F027). Verified via `ls -la`.
- ✅ **Slash-command ceiling bump justified.** Diff shows `[ "$count" -ge 9 ] && [ "$count" -le 12 ]` → `... -le 15 ]` with comment naming v1.9/F027 sdd-verify-stack.md as the trigger. Actual count today: 13 commands in `templates/.claude/commands/` (room for 2 more before next bump). Reasonable headroom.

### `d374aa6` — [SDD] graph-integrity stub for `[[2026-05-12-backlog-book-close]]`
- ✅ **Stub folder exists** at `.sdd/features/2026-05-12-backlog-book-close/` with `spec.md` (827 bytes, May 12) + `.shipped` (0 bytes, May 12). The spec.md body correctly identifies itself as a slug-stub pointing at decisions.md for the canonical record. Resolves the wiki-link.

### `df032eb` — ci(sdd-ci): graph-integrity on push too — **HIGHEST RISK COMMIT**
- ✅ **Diff is a single-line removal** (`if: github.event_name == 'pull_request'`) + 6 lines of explanatory comment. No other workflow logic touched.
- ✅ **scope-guard preserves its PR-only gate** at line ~387 (scope-guard diffs against base, so PR-only is correct for it — confirmed not changed).
- ✅ **CI evidence:** latest run on main HEAD (commit `1f18b00`, later `d96244c`) shows SDD CI = success with graph-integrity job included. Was previously skipped on push; now runs.
- ✅ **Framework-fix verdict: JUSTIFIED.** See §5 below for rationale.

---

## 3. Stub-folder reconciliation

Three files coexist cleanly at `.sdd/features/2026-05-12-backlog-book-close/`:

| File | Size | Mtime | Source |
|---|---|---|---|
| `spec.md` | 827 bytes | May 12 19:00 | parallel session (`d374aa6`) |
| `.shipped` | 0 bytes | May 12 19:00 | parallel session (`d374aa6`) |
| `README.md` | 695 bytes | May 14 | PR #260 (`a5c3341`) — independent redirect stub written when PR #260 hit a graph-integrity CI fail on its own branch |

Both files (`spec.md` + `README.md`) explain the redirect-stub purpose in different framings. **Mild redundancy but harmless** — `spec.md` follows the canonical `.sdd/features/<slug>/spec.md` shape used by other audit-close stubs (e.g. `.sdd/features/2026-05-11-ship-day-audit-close/`); `README.md` is a more human-readable explainer.

**Recommendation:** leave both. Deleting `README.md` would be a minor cleanup but doesn't affect graph-integrity (either file alone resolves the slug). If future audits accumulate similar stubs, codify the spec.md convention in the framework and remove README.md as part of that sweep.

---

## 4. Regression list

**None.** After reverting the local-only `DRIFT-TEST-MARKER` working-tree leak, `bash test/run-framework-test.sh` ran clean on main HEAD with 0 failures. Earlier 13-fail false alarm traced 100% to that one uncommitted-line drift in `templates/.sdd/actions/problem.md`.

---

## 5. Framework-fix verdict (`df032eb`)

**Justified.** The asymmetry it removes is real:

- **Before `df032eb`:** broken wiki-link added via direct push to main → CI green (graph-integrity skipped on push) → next PR opens against the broken state → that PR's CI fails on a link it didn't introduce. Surface area = "every future PR opener bears the cost of the earlier pusher's drift."
- **After `df032eb`:** broken wiki-link → push CI fails immediately, blocks the merge that introduced the drift. Cost falls on the right person.

Scope-guard correctly stays PR-only (it diffs against base, so push-without-base wouldn't have meaningful input). The fix is **minimum-diff** (one `if:` line removed + comment) and **conservative** (no new behaviour on PRs; just adds the same check to push events). Live evidence: SDD CI on `1f18b00` (df032eb-or-later) shows graph-integrity as a completed job, not skipped.

**Edge cases considered:**
- Push of a commit that's already in a merged PR (e.g. a hotfix straight to main bypassing CR): graph-integrity now catches drift before merge instead of next-PR-time. Strictly safer.
- A non-`.sdd/` push that doesn't touch wiki-links: graph-integrity runs but completes fast (~seconds) since the graph cache is content-addressed. Cost negligible.

---

## 6. PR #260 (+ #261 + #262) status

**All merged + tagged.** State as of audit time:

| PR | Merge SHA | Tag | Status |
|---|---|---|---|
| #260 (verify-stack +2 checks) | `a5c3341` | covered by v1.9 verify-stack suite | merged |
| #261 (walkthrough F027 → 6 checks) | `1f18b00` | doc-only | merged |
| #262 (README + stack.md + F027 visual) | `d96244c` | doc-only, just merged this session | merged |

Cross-audit for PR #260 already produced clean (see prior audit's "Verdict: clean / acceptable"). Walkthrough at line 854 has F027 entry with 6 checks + both new check names + PR #258 + #260 links + (post-PR #262) an inline SVG flow diagram showing user → script → 6-check grid → coloured terminal output.

---

## 7. Recommended follow-ups

### A. New `/bug`: T120 cleanup-on-crash gap

**Surface:** T120 (framework self-host drift detection) appends `DRIFT-TEST-MARKER` to `templates/.sdd/actions/problem.md`, asserts the drift detector fires, then removes it. If the test crashes between append + remove, the marker leaks into the working tree. `1d55c85` cleaned ONE such leak; I just cleaned ANOTHER during this audit. The pattern is recurring.

**Fix shape:** wrap T120's marker-append + cleanup in a bash `trap '...' EXIT INT TERM` so the cleanup fires even on crash / Ctrl-C. Same shape as F009's `corpus-signature-lock.sh` (closes #113) cleanup discipline.

### B. Optional cleanup: collapse redundant stub README

`.sdd/features/2026-05-12-backlog-book-close/README.md` and `spec.md` say the same thing in different framings. Either delete the README and codify the spec.md convention, or document the dual-stub pattern. Low priority; current state is harmless.

### C. T141 anti-theatre `{best-effort: <who>}` cleanup-on-crash

Same shape as A — T141 might also leak theatre tokens into test fixtures on crash. Worth a 5-minute audit pass on the test code.

---

## 8. 30-second summary for Sam

The 8-commit batch from the parallel session is clean. All bug fixes verified. The framework-level fix (graph-integrity on push) is justified and CI-confirmed. PR #260 / #261 / #262 all merged. Zero regressions. One nice-to-have follow-up: file a `/bug` for T120's drift-marker-leak-on-crash (I tripped it during this audit; same shape as the leak `1d55c85` cleaned up). No action needed unless you want T120's hardening.
