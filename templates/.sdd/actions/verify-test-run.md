---
type: action
slug: verify-test-run
tag: AGENT-LED
title: "verify-test-run"
short_label: "Test run"
steps:
  - { id: full-suite, action: "run the full test suite, mark all ACs as passing, or open a bug", field: "§verify-test-run" }
used_by: [feature, bug, refactor]
references: [acceptance-criteria, plan-decompose]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 15
  max_tokens: 4000
  max_commits: 1
requires_user_approval: false
---

All tasks should be GREEN by now. Run the **full test suite** to catch any regression, race condition, or flakiness that didn't surface during single-task runs.

**Action:** invoke the project's test runner (`npm test`, `pytest`, `cargo test`, `go test ./...`, etc.). Capture exit code and output.

**If any test fails (RED):**
- Identify which AC the failing test covers
- Re-mark that AC's `[ ]` checkbox in spec.md as RED
- Open a `[BUG]` task in plan-decompose for the fix
- HALT. Tell the user: *"Test X failed; AC Y is now back in BUILD as a BUG. Run `/next` after we fix it."*

**If all GREEN (excluding [PROD-ONLY] ACs):**
- Tick the `**All ACs pass (excluding PROD-ONLY):** [x]` box in spec.md
- Continue to the next action

**Output:** fill `spec.md` under `### verify-test-run` with `**All ACs pass (excluding PROD-ONLY):** [x]` (or `[ ]` + BUG task if any failed).

**End the turn with one line:** `Test suite GREEN — N/N passing.` (or BUG details if any RED).

**What it looks like:**

Before opening the PR, let me prove the whole test suite passes locally.

Example: *"Running `bash test/run-framework-test.sh` and the MCP test suite. All `<framework-passed>/<framework-total>` framework + `<mcp-passed>/<mcp-total>` MCP tests passing. If anything is RED I show you the exact failure and we fix it before pushing."* (The actual numbers go in the user-facing message; placeholders here keep the template from drifting as test counts grow.)
