# graph-cache multi-line code span fix

[PHASE: SHIP]

**Run mode at BUILD:** full autonomous.

**Active blocker:** SHIP — push-pr → CR cycles → mark-shipped.

## PHASE: SPEC

### action: problem

- [x] who: Downstream SDD users writing CommonMark-compliant prose with multi-line backtick spans containing wiki-link syntax — and the graph-integrity CI gate that would falsely flag them.
- [x] why-now: Deferred from PR #104 (graph-integrity gate) per Sam's pre-merge call (option C — ship the gate, fix this edge case as a follow-up). The framework's own `.sdd/` tree has zero multi-line spans containing `[[…]]` today, so no current breakage; but a downstream user writing CommonMark-spec-conformant prose would see false positives.
- [x] what-breaks: A multi-line backtick span like `` `[[pattern:fake]] keeps going` `` (where the closing backtick is on a later line) registers `pattern:fake` as a real wiki-link edge. Either trips invariant 8 (broken-link error) or pollutes the graph with a phantom edge. Both undermine the graph-integrity gate's correctness promise.

Source: GitHub [#105](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/105); CR cycle-7 on PR #104; existing implementation in `extensions/sdd-mcp-server/queries/_graph_cache.py:266` (`_INLINE_CODE_RE` is single-line by construction — `[^backtick-or-newline]+` excludes newlines).

### action: success

- [x] metric: A markdown fixture containing a multi-line backtick span with `[[pattern:fake]]` produces zero wiki-link edges. {verify-by: T01 graph-cache test in `extensions/sdd-mcp-server/tests/`}

### action: user-stories

- [x] stories: Two personas.

  **Story 1 — Downstream user's CommonMark prose doesn't trip the gate.**
  *As a downstream SDD user writing prose with multi-line code spans (CommonMark §6.1 allows it), I want the graph-integrity CI gate to recognise them as code, so my legitimate CommonMark-compliant docs don't fail CI on a false-positive broken-link error.*

  **Story 2 — Framework parsing matches CommonMark spec.**
  *As the framework's MCP server (graph-cache builder), I want the inline-code stripper to match CommonMark §6.1 fully (single-line AND multi-line spans), so the graph I build is what CommonMark says the document means.*

### action: ux-brief [SKIPPED]

- ⏭ skipped — non-UI feature (MCP server bug fix).

### action: proposed-approach

- [x] approval: agent-drafted in autonomous mode under Sam's standing CRACK ON directive.

**Approach: pre-mask multi-line spans before line-by-line walk.**

Restructure `_strip_inline_code` to operate on the FULL content (not one line at a time) before splitting into lines:

1. Build a content-level `_INLINE_CODE_MULTILINE_RE` that allows newlines inside the span (use `[\s\S]` instead of `[^backtick-or-newline]` for the inner content; keep the same backtick-count matching rules).
2. New helper `_mask_inline_code_in_content(content)` runs the multi-line regex over the full content and replaces each match with same-length whitespace BUT preserves newline characters within the match (so line numbers downstream stay correct). {verify-by: T03 line-number accuracy test}
3. Existing per-line `_strip_inline_code(line)` stays — it now handles only post-masking line-level cleanup.
4. Update the main walk loop in `_graph_cache.py` to call `_mask_inline_code_in_content(content)` BEFORE `content.split("\n")`.

**Approach: 1 alternative considered + rejected.**

- **Alternative B — re.DOTALL on the single regex.** Use `re.DOTALL` and `.` as inner-content matcher. Rejected: doesn't handle the line-number preservation requirement on its own — we still need the mask-with-whitespace-but-keep-newlines post-step.

**What it looks like:** *"Today the inline-code stripper walks one line at a time. A backtick that opens on line 5 and closes on line 7 isn't recognised as code — both lines slip through to the wiki-link regex, which sees `[[pattern:fake]]` and registers a phantom edge. The fix: scan the whole document first for multi-line backtick spans, replace them with whitespace (keeping newlines), then walk line-by-line as today. Line numbers stay correct because we kept the newlines."*

### action: data-contract

- [x] approval: no schema changes. Single-function rewrite + new helper.

### action: flows

- [x] flows: One. Graph-cache build walks every markdown file → pre-mask multi-line code spans on full content → split into lines → existing per-line `_strip_inline_code` + wiki-link regex → register edges.

### action: dependencies

- [x] deps: **No new deps.** Python `re` module already used. Cost: zero.

### action: out-of-scope

- [x] list: Three things explicitly NOT in scope.
  1. **Full CommonMark inline-element parsing.** Masking inline-code spans only; emphasis, links, autolinks, etc. stay handled by existing regex.
  2. **Reflow / formatting changes** to the `.sdd/` tree's existing prose. None of the framework's own files have multi-line spans containing `[[…]]` today; this fix is for downstream correctness.
  3. **Backtick-escape sequences** like backslash-backtick inside spans. Edge case; CommonMark spec-conformant but vanishingly rare. Park as v1.3 candidate if a real case shows up.
- [x] approval: agent-drafted in autonomous mode.

### action: non-functional

- [x] constraints:
  - **Performance:** the pre-mask pass adds one full-content regex match per markdown file. For a typical project with around fifty markdown files of around five hundred lines each, this adds well under a second total to graph-cache build. {best-effort: wall-clock measured during framework regression run; informal assertion, no hard threshold}
  - **Determinism:** same input must always produce the same masked output. {verify-by: existing graph-cache tests use deterministic fixtures}
  - **Line-number accuracy:** edges reported with line numbers must STILL point at the correct source line after masking. {verify-by: T03}

### action: acceptance-criteria

- [x] approval: agent-drafted in autonomous mode. Coverage check vs §4 N/A here (UX brief skipped).

1. **AC1 — multi-line span doesn't fire wiki-link.** A markdown fixture with a backtick span opening on line N and closing on line N+2, containing `[[pattern:fake]]`, produces zero outgoing edges in the graph. → `tests/task-001.sh`

2. **AC2 — single-line spans still work.** Existing single-line span regression: `` `[[pattern:fake]]` `` on one line still produces zero edges. → `tests/task-002.sh`

3. **AC3 — line numbers preserved.** A fixture with a real `[[001-waitlist]]` wiki-link on line N (outside any code span) reports `edge.from_line == N` after the masking pass. {verify-by: T03} → `tests/task-003.sh`

4. **AC4 — framework regression.** All MCP unit tests + framework tests still pass. → `tests/task-004.sh`

### action: signoff-steps

- [x] manual-steps: Single smoke. Build the graph against a fresh fixture file with a multi-line span containing `[[pattern:fake]]` and confirm `_graph_cache.find_node(graph, "pattern:fake")` returns None (matches the actual `find_node(graph, slug)` API signature; no phantom edge).

### action: wireframe [SKIPPED]

- ⏭ skipped — non-UI feature.

### action: plan-decompose

- [x] tasks: 4 tasks, 1-1 with AC1-4. Run mode: full autonomous.

  - [ ] T01: write multi-line span fixture + content-level mask helper. Test: `tests/task-001.sh` runs MCP graph-cache against the fixture + asserts zero outgoing edges.
  - [ ] T02: regression — single-line spans still produce zero edges. Test: `tests/task-002.sh`.
  - [ ] T03: line-number accuracy after masking. Test: `tests/task-003.sh`.
  - [ ] T04: full framework + MCP regression. Test: `tests/task-004.sh`.

### action: edge-case-sweep

- [x] ec-sweep: 3 edges considered.
  - Triple-backtick spans — already handled by existing 4-3-2-1 backtick alternation; multi-line variant inherits.
  - Span starting on a fenced-line — fenced lines are already excluded earlier in the walk.
  - Span containing escaped backticks — CommonMark says backslash escapes don't apply inside code spans, so no special handling needed.
- [x] ec-pick: 0 edge-case ACs added; all 3 are inherited or non-issues.

### Exit checks

- [x] C-spec-acs: 4 ACs in §11
- [x] C-spec-tasks: 4 tasks in plan-decompose

## PHASE: BUILD

### Build tasks (4 total · run mode: full autonomous)

- [x] T01 GREEN: `_INLINE_CODE_MULTILINE_RE` + `_mask_inline_code_in_content` helper landed in `_graph_cache.py`; fixture with multi-line span containing `[[pattern:fake]]` produces 0 phantom edges
- [x] T02 GREEN: single-line span regression — still produces 0 edges
- [x] T03 GREEN: line numbers preserved after masking (newlines kept in mask output)
- [x] T04 GREEN: 196/196 framework + 161/161 MCP regression passing

### Exit checks (BUILD)
- [x] C-build-tasks-green: 4/4 tasks GREEN

## PHASE: SHIP

### action: verify-test-run
- [ ] run: framework + MCP + task tests passing.

### action: verify-prod-only-acs
- [ ] collect: N/A — no `[PROD-ONLY]` ACs.

### action: adversarial-review
- [ ] adversarial: CodeRabbit on the PR. Iterate until converged.

### action: playwright-explore
- ⏭ skipped — non-UI feature.

### action: learn
- [ ] lessons: lesson captured in INDEX.md `## Shipped` row's Lesson field.

### action: push-pr
- [ ] pr: PR opened against main.

### action: verify-ci-green
- [ ] ci: all 4 GitHub Actions checks green.

### action: mark-shipped
- [ ] shipped: `.shipped` marker, INDEX.md row, decisions.md audit.

### Exit checks (SHIP)
- [ ] C-ship-pr-merged: PR merged with CI green
- [ ] C-ship-marker: `.shipped` present
- [ ] C-ship-index: INDEX.md `## Shipped` row added
