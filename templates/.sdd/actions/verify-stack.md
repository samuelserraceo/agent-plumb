---
type: action
slug: verify-stack
tag: AGENT-LED
title: "Verify declared stack matches reality"
short_label: "Verify stack"
steps:
  - { id: probe, action: "run bash .sdd/scripts/verify-stack.sh and report any failures", field: "stack-verification" }
used_by: [feature, project, bug, refactor]
references: [setup-help]
touches: []
trust: framework
budget:
  max_minutes: 2
  max_tokens: 1000
  max_commits: 0
model_tier: mechanical
requires_user_approval: false
---

Run `bash .sdd/scripts/verify-stack.sh` from the project root to probe each tool the user declared during `/sdd-setup` and verify it's actually reachable / installed.

Background: `/sdd-setup` is a question-only wizard — it records answers to `.sdd/config.md` and `.sdd/stack.md`, but never verifies whether the answers reflect reality. This action runs at the end of `/sdd-setup` (or any time the user runs `/sdd-verify-stack`) to surface real gaps.

**Checks performed:**

- **CodeRabbit App** — when `parameters.review.bot: coderabbit` is set, probes `gh api repos/<repo>/installation`. If the App is not installed, surfaces the marketplace install URL so the user can fix it before assuming CR is reviewing every PR.
- **Ollama endpoint** — when `parameters.mcp.tier3.enabled: true` AND the provider is Ollama, HEAD-probes the configured endpoint with a 2-second timeout. Surfaces unreachable endpoints before the user assumes Tier 3 is working.
- **CI workflow files** — counts `.yml`/`.yaml` files in `.github/workflows/`. Warns if the directory is missing or empty (CI checks won't fire).
- **Branch protection** — `gh api repos/<repo>/branches/main/protection`. Warns if missing (so the user can enable required checks).

**Exit codes:**

- `0` — no FAIL entries (warnings allowed). The user's stack matches reality.
- `1` — one or more FAIL entries. The action prints the failed checks + remediation steps.

**Closes:** [#165](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/165) — the "I said I'd use CodeRabbit but never installed the App" failure mode.

**Anti-theatre note:** every check is mechanical (real API call or file presence). No judgement-based claims. The goal is to MAKE the setup gap visible, not to over-claim correctness.

**What it looks like:**

After the user runs `/sdd-setup` and answers "I'll use CodeRabbit" + "Tier 3 with Ollama" + "main branch protected", the wizard records those answers. Then `/sdd-verify-stack` actually probes each:

```
[verify-stack] coderabbit-app: ok — CodeRabbit App installed on samserra/myproject
[verify-stack] ollama-endpoint: fail — Ollama NOT reachable at http://localhost:11434 — start ollama (`ollama serve`) or update endpoint
[verify-stack] ci-workflows: ok — 3 workflow file(s) in .github/workflows/
[verify-stack] branch-protection: warn — main branch protection NOT configured on samserra/myproject — consider enabling required checks
```

Plain-English remediation per failed check — the user sees the gap and the fix path in one line. Exit code `1` because one FAIL is present; the user fixes Ollama (or unsets Tier 3) and re-runs.
