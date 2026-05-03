---
type: config
sdd_version: 1.0.0
playbooks_available: [feature, project, bug, refactor]
default_playbook: feature
extensions: {}
parameters:
  budget:
    max_minutes: 5
    max_tokens: 4000
    max_commits: 1
  voice:
    plain_english: true
    translate_jargon_on_first_use: true
  pace:
    halt_on_red_after_attempts: 3
  ralph:
    max_iters: 50
    timeout_per_iter: 600
  review:
    bot: ""              # "coderabbit" | "sourcery" | "" (none)
    poll_interval: 180   # seconds; 180s × 5 polls = 15 min default for CodeRabbit
    max_polls: 5
    nudge_command: ""    # e.g. "@coderabbitai full review" — comment posted if no review after max_polls
    manual: false        # true = wait for human review only; agent doesn't poll for bots
  mcp:
    enabled: false       # populated by /sdd-setup brick 007 — true if user wants the SDD MCP server (40-60% across-session token saving)
    semantic_search:     # opt-in semantic search over .sdd/ — embeds notebooks once, ranks chunks by cosine similarity. See extensions/sdd-mcp-server/README.md.
      enabled: false
      provider: ""              # REQUIRED — set to "openai" (OpenAI-compatible shape — works with Ollama in compatible mode, vLLM, etc.) or "ollama-native" (older Ollama). No silent default; search() rejects an unset provider per the framework's "no baked-in defaults for external services" doctrine.
      endpoint: ""              # http(s)://host:port — base URL, the path is appended per provider
      model: ""                 # embedding model name (e.g. "nomic-embed-text" or "bge-small-en-v1.5")
      top_k: 5                  # how many results to return per search
      max_chunks_per_run: 1000  # cost ceiling — refuses to embed more chunks than this in one call
      auth_header: ""           # optional. To keep tokens OUT of tracked config, use ${ENV_VAR_NAME} indirection (e.g. "${SDD_MCP_AUTH}") and put the literal token in the env var. Literal values still work. Empty = no auth header sent.
    tier3:               # opt-in Tier 3 LLM-driven synthesis over .sdd/ corpus — chat-style answers with cite-checked wiki-link citations. v1.1 wizard-supported provider: Ollama+Gemma running locally. Other providers (OpenAI / Anthropic / etc.) settable manually but not wizard-supported until v1.2+. See extensions/sdd-mcp-server/README.md and [[001-tier-3-llm-driven-synthesis]].
      enabled: false
      provider: ""                       # v1.1 wizard: "ollama-chat" (Gemma); manual: openai / anthropic / etc. (v1.2+ widens wizard). REQUIRED when enabled — no silent default per foundation 3.
      endpoint: ""                       # http(s)://host:port — base URL the chat AI lives at
      model: ""                          # chat model name (e.g. "gemma2:2b" for Ollama)
      max_calls_per_run: 10              # exact integer counter — refuses past this
      max_input_tokens_per_call: 8000    # exact — refuses to send larger context to the AI
      max_total_tokens_per_run: 100000   # exact — stops once running total crossed
      auth_header: ""                    # optional. To keep tokens OUT of tracked config, use ${ENV_VAR_NAME} indirection. Literal values still work. Empty = no auth header sent. NOTE: v1.1 default Ollama+Gemma local doesn't need this; load-bearing for v1.2+ paid providers.
      # Anti-theatre note (Sam's catch 2026-05-01): there is no `cost_limit_usd` field. The framework can't enforce dollar amounts without a per-provider pricing table or a live spending ledger — neither exists. Token caps above are the mechanical enforcement. Dollar guidance for picking a provider lives in the spec, not here.
file_classes:
  CLAIM:
    - '(^|/)verification\.json$'
    - '^\.git/sdd/approvals\.jsonl$'
  POLICY:
    - '^\.sdd/\.cache/manifest\.json$'
    - '^\.sdd/playbooks/[^/]+\.md$'
    - '^\.sdd/actions/[^/]+\.md$'
    - '^\.sdd/extensions/[^/]+\.md$'
    - '^\.sdd/scripts/[^/]+\.sh$'
    - '^\.claude/hooks/[^/]+\.sh$'
    - '^\.claude/settings\.json$'
    - '^CLAUDE\.md$'
co_stage_block:
  - [CLAIM, POLICY]
file_rules:
  ".sdd/decisions.md":
    append_only: true
  ".sdd/patterns.md":
    size_warn: 200
    size_block: 400
    advice: "Run /compress patterns to consolidate duplicates and snapshot old entries to .sdd/archive/."
  ".sdd/INDEX.md":
    size_warn: 200
    size_block: 400
    advice: "Old shipped entries should move to .sdd/archive/. /ship will offer this once a quarter."
  ".sdd/data-model.md":
    size_warn: 200
    size_block: 400
    advice: "Consider splitting into a data-model/ directory (one file per entity)."
  "CLAUDE.md":
    managed_section:
      open: "SDD-MANAGED-START"
      close: "SDD-MANAGED-END"
      bump_marker: ".sdd/CLAUDE.version"
      on_edit: warn
state_rules:
  - id: no-open-blockers-on-phase-advance
    when: phase_advance_with_open_blockers
    refuse: true
    message: |
      Phase-advance blocked: the source phase (the one you're leaving)
      still has open `[ ]` blockers. Per-section commits during a phase
      are allowed — only the phase-advance commit is gated.

      Fill the open blockers (or skip a [SKIPPABLE] section inline via
      /next), then retry.
folder_rules:
  default_action: warn
  deferred_paths:
    - ".sdd/topics/"
    - ".sdd/archive/"
  root_allowed:
    - "CLAUDE.md"
    - "README.md"
    - ".gitignore"
    - ".sdd"
    - ".claude"
    - "package.json"
    - "package-lock.json"
    - "node_modules"
    - "tsconfig.json"
    - "playwright.config.ts"
    - "playwright.config.js"
    - "Makefile"
    - "Dockerfile"
    - "docs"
    - "src"
    - "test"
    - "tests"
    - "templates"
    - ".github"
    - "extensions"
scope_guard:
  # Per-project scope-guard configuration (closes #16). The CI's scope-guard
  # job checks that newly-added UI copy strings (≥ copy_min_chars) appear in
  # spec.md or wireframe.html, and that new traceable files (UI + backend)
  # carry a `// spec:` comment. Defaults below cover the v0.13.x Next.js
  # shape PLUS common backend conventions (api routes, db migrations,
  # server code) so the "code traces back to spec" claim holds for both
  # UI and backend changes. Override per project.
  #
  # Variable name `ui_dirs` is legacy from the v0.13.x UI-only era — kept
  # as-is so existing downstream projects don't break on schema rename.
  # The list now covers backend traceable dirs too.
  file_extensions: [tsx, jsx, ts, js, py, rb, go, sql]
  ui_dirs: [app, components, pages, src/app, src/components, src/pages, app/api, pages/api, routes, migrations, server, src/api, src/server, lib/db, db]
  copy_min_chars: 30
events:
  section_approved:
    actions:
      - { target: ".sdd/decisions.md",         action: append }
      - { target: ".sdd/<work-item>/verification.json", action: record_section_hash }
  phase_transition:
    actions:
      - { target: ".sdd/decisions.md",         action: append }
      - { target: ".sdd/INDEX.md",             action: rewrite_active_block }
      - { target: ".sdd/<work-item>/spec.md",  action: scaffold_next_phase }
  ship_complete:
    actions:
      - { target: ".sdd/decisions.md",         action: append }
      - { target: ".sdd/patterns.md",          action: append_lesson }
      - { target: ".sdd/INDEX.md",             action: rewrite_shipped_block }
      - { target: ".sdd/<work-item>/.shipped", action: create_marker }
---

# SDD project configuration

This file is your one knob for telling SDD what's available in this project. The framework reads it on every `/start` and `/next` to know which playbooks you can pick from and which optional extensions to apply.

## What each switch means (plain English)

### `sdd_version: 1.0.0` (or current ship)

Which version of the SDD framework this project was created against. The framework warns on mismatch so you can re-run a migration if you upgrade.

### `playbooks_available: [feature, project, bug, refactor]`

Which workflows you can pick from when you run `/start`. As of v1.0, four playbooks ship:

- **`feature`** — the "build something new" journey. Use for a single shippable feature (~10-15 BUILD tasks). The default; what you get when you run `/start "<title>"` without a `--playbook=` flag.
- **`project`** — the "plan a multi-feature initiative" journey. Use when the work is bigger than one feature (a CRM, a marketplace, a full new app). Produces a roadmap + queues 3-12 features into INDEX.md backlog, auto-starts the first one. Run via `/start --playbook=project "<initiative title>"`.
- **`bug`** — the "fix something broken" journey. 5-section SPEC: problem → repro → root cause → minimal-diff fix → regression test. Run via `/start [BUG] "<title>"` (auto-routes) or `/start --playbook=bug "<title>"`. Skips the parts of `feature.md` that don't fit a bug fix (user stories, data contract, UX brief, ACs).
- **`refactor`** — the "clean up code without changing behaviour" journey. 4-section SPEC: scope → regression coverage → approach → minimal-diff verify (halts at SPEC end when additions−deletions is positive). Run via `/start --playbook=refactor "<title>"`.

Future playbooks (`idea`, `question`) ship later; they'll appear here automatically when you upgrade and pick "yes, install the new playbook" during migration.

### `default_playbook: feature`

If you run `/start "do the thing"` without `--playbook=`, this is the one used. Set to `project` if your usual `/start` is project-scope work (rare — most teams keep this on `feature` because feature is the more common shape).

### `extensions: {}`

Empty — v0.9 ships zero extensions. The framework's hooks already enforce the moat locally; CI extension (`.github/workflows/sdd-ci.yml`) ships server-side enforcement on PRs out of the box. Marketplace-style extensions (`obsidian-sync`, `slack-notifications`, etc.) are deferred to a future phase.

When extensions become available, this section will look like:

```yaml
extensions:
  ci_moat_enforcement: on    # or "off" if you don't want CI verification
```

You'll never have to write the YAML by hand — `/start` and the migration scripts edit this file for you.

### `size_thresholds:` (optional, not shown above)

Override the framework's default warn/block thresholds for your memory files (defaults are baked into the `file_rules:` block below — `size_warn: 200` and `size_block: 400` for `patterns.md`, `INDEX.md`, `data-model.md`). Most projects don't need to touch this. Add it if your project has a working pattern of, say, an unusually large `data-model.md` that the framework keeps complaining about.

### `file_classes:` + `co_stage_block:` (path-based file classes for cofile-block rule)

Declares named classes of files (by regex pattern) and which class pairs cannot be staged in the same commit. The framework's central tampering defence — without it, an adversary could weaken policy in commit N (e.g., neuter a hook) and ship a fabricated CLAIM in commit N+1; the per-commit moat wouldn't catch the cross-commit pair.

Two named classes ship in the template:

- **`CLAIM`** — files that ASSERT state (the agent's claim that it did the work). Includes `verification.json` and `.git/sdd/approvals.jsonl`.
- **`POLICY`** — files that DEFINE the rules being claimed against. Includes the manifest, all `playbooks/`, `actions/`, `extensions/`, `scripts/`, `hooks/`, `settings.json`, and `CLAUDE.md` itself.

`co_stage_block:` is a list of `[ClassA, ClassB]` pairs. Each pair declares "any commit that stages files from BOTH classes is refused." The framework ships with `[CLAIM, POLICY]` — forcing any policy edit and any claim edit into separate auditable commits.

To add a new class: add a name + pattern list to `file_classes:`. To add a new co-stage rule: add a new pair to `co_stage_block:`. Both are read by F1 generic enforcer (Phase C-5); no hook code changes.

### `file_rules:` (per-file content rules)

Per-file rules the framework enforces at commit time. Each key is a path; each value is a map of rules. Currently one rule type ships with the template:

- **`append_only: true`** — staged version of the file must start with HEAD's content byte-for-byte. Modifying or removing prior content blocks the commit. Reason: append-only files are the audit trail (`decisions.md`); rewriting history breaks the trust model. **No documented escape hatch:** if the file becomes genuinely corrupt, recovery is a manual operation outside the framework's contract (restore from a known-good commit, don't squash forward).

Defaults shipped in the template: `.sdd/decisions.md` is append-only. Other shipped rules:

```yaml
file_rules:
  ".sdd/patterns.md":   { size_warn: 200, size_block: 400 }
  ".sdd/INDEX.md":      { size_warn: 200, size_block: 400 }
  "CLAUDE.md":          { managed_section: { open: "<!-- SDD-MANAGED-START", close: "<!-- SDD-MANAGED-END -->", on_edit: warn } }
```

Adding a new file-rule = a new key in this map + a new rule-handler in `pre-commit-rules.sh`. The handler is the only code change; the schema is declarative.

### `state_rules:` (state-condition refusal rules)

Generic refusal rules driven by the project's current state. Each entry has the same shape; the framework's F1 enforcer reads them and applies a matching condition recogniser. This is **Option B-lite** from Sam's Q&A round — one rule today, schema ready for future ones.

Schema:

```yaml
state_rules:
  - id: <slug>                    # human-readable rule name
    when: <condition-name>        # closed-enum condition the enforcer recognises
    refuse: true                  # block the commit on match
    message: |                    # plain-English explanation shown to the user
      Why this is blocked + how to fix.
```

Today's only entry, **`phase_advance_with_open_blockers`** — refuses any commit that flips `[PHASE: X]` in spec.md while the source phase (the one being left) still has open `[ ]` step rows. Per-section commits during a phase pass through unchanged; only the phase-advance commit is gated. The rule prevents the framework's central drift mode: "I'll come back to those" advancing the phase with unfinished work.

Future condition names (sketches — none implemented yet, schema is ready):
- `ship_commit_with_red_acs` — refuse SHIP-final commit when any AC line is still RED
- `phase_advance_with_stale_approval` — refuse phase advance when a previously-approved section's hash mismatches (today the moat handles this; could subsume into state_rules)
- `commit_during_halt` — refuse any commit while a halt-trigger marker file is present

Adding a future rule = a new `state_rules:` entry + a new condition recogniser in pre-commit-rules.sh's handler. The schema doesn't change.

### `folder_rules:` (canonical-folder enforcement; Option B)

Pairs with the "Where things live" doctrine in `CLAUDE.md`. Two soft enforcement rules ship in v0.9, both **warn-only by default** (`default_action: warn` — no commit blocks); project owners can flip to `block` per their tolerance for drift.

- **`deferred_paths:`** — folders that have shapes designed but no Phase-C work yet (`.sdd/topics/`, `.sdd/archive/`). Writing into them today is almost always a sign the agent invented a workaround instead of asking. The framework warns when staged files land here. (`.sdd/bugs/` was deferred pre-v1.0 and graduated to active in v1.0 with the `bug.md` playbook — it's a normal work-item folder now.)
- **`root_allowed:`** — explicit allow-list of top-level paths. Anything new at the project root that isn't on this list triggers a warn pointing the user at `.sdd/ideas/` (one-off thoughts) or the relevant per-feature folder (anything scoped to a work item).

This is intentionally light — Phase C ships the *signal* (the warn), not the block. After watching how it lands in real projects, future phases may add `on_violation: block` per-rule and a richer per-folder allow-list (`<NNN>-<slug>/spec.md`, `<NNN>-<slug>/wireframe.html`, etc.).

### `events:` (event → file-action map, F2 slimmed)

Maps the framework's three known events to the file changes they imply. When an action's step declares `triggers: [section_approved]` (in its frontmatter), the framework fires the event; the `events:` block declares **what happens** when the event fires — which files get appended, hashed, rewritten, or marked.

Three events ship with the template:

- `section_approved` — fires when the user approves a section that requires approval (`proposed-approach`, `acceptance-criteria`, `out-of-scope`, `data-contract`). Appends a one-paragraph entry to `.sdd/decisions.md` and records the approved-section hash in the work item's `verification.json`.
- `phase_transition` — fires on SPEC → BUILD → SHIP → SHIPPED. Appends to `decisions.md`, rewrites the active-block in `INDEX.md`, scaffolds the next phase headings in `spec.md`.
- `ship_complete` — fires on the final SHIP commit. Appends to `decisions.md`, appends the new lesson to `patterns.md`, rewrites the shipped block in `INDEX.md`, creates the `.shipped` marker file.

Path placeholders (`<work-item>`) are resolved at runtime against `INDEX.md`'s `**Active:**` line. You can add new events by adding a key here — the F1 generic enforcer (Phase C) reads this map to validate that staged commits match the declared events. Action frontmatter step rows reference events via `triggers:`, so adding an event flow is a 2-line change (one entry here + one `triggers:` reference in the action that fires it).

### `parameters:` (project-level defaults)

Tuning knobs that cascade down to every step in every work item. **F5 cascading parameters** lets you set sensible defaults once and override only where needed. The cascade order (lowest priority → highest):

1. `parameters:` here in `config.md` (project default)
2. `overrides:` in `spec.md` frontmatter (per work item)
3. `overrides:` in `playbooks/<slug>.md` per-stage block (per stage)
4. `overrides:` in `actions/<slug>.md` frontmatter (per action)
5. `overrides:` on a single step row (most specific)

Each level only needs to declare the keys it changes — unspecified keys inherit. Three known sub-blocks:

- `budget:` — `max_minutes`, `max_tokens`, `max_commits`. Ceiling on per-step effort. The framework warns at the limit; doesn't block. Override at action level for actions that genuinely need more (e.g., `proposed-approach: max_minutes: 30` because drafting + iterating takes longer than answering a yes/no).
- `voice:` — `plain_english: true` (no jargon without translation), `translate_jargon_on_first_use: true`. The agent reads these every turn and adjusts its phrasing.
- `pace:` — `halt_on_red_after_attempts: 3`. The agent stops trying to fix a failing test after this many attempts and asks the user.
- `ralph:` — `max_iters: 50` (cap on total BUILD-task iterations the auto-loop runner can chew through before halting), `timeout_per_iter: 600` (seconds — the loop kills any single iteration that hangs past this). Read by `scripts/ralph.sh` (the headless BUILD run mode). Lower these if you want a tighter leash on autonomous runs; raise them if you've signed off on a long-running iteration shape and don't want the loop to stop early.
- `review:` — populated by `/sdd-setup` step 3 (PR-reviewer choice). `bot` is the chosen reviewer (`"coderabbit"` / `"sourcery"` / empty for none). `poll_interval` (seconds) × `max_polls` is how long the agent waits for the bot's review on a PR before nudging or moving on (default 180 × 5 = 15 min for CodeRabbit). `nudge_command` is the exact comment the agent posts if no review has arrived (e.g., `"@coderabbitai full review"`). `manual: true` disables bot polling entirely — the agent waits for a human reviewer.

Add new sub-blocks as your project's needs grow — the resolver passes any keys through unmodified, so your action overrides can introduce custom keys (e.g., `approval_threshold: stricter` for high-stakes work items).

## What you can edit directly

This whole file. It's plain Markdown with YAML frontmatter — no special tooling. Edit, save, run `/next`, the framework picks up the changes.

The one rule: **don't reference a playbook or extension that doesn't exist** (no file in `.sdd/playbooks/<slug>.md` or `.sdd/extensions/<slug>.md`). The loader will catch you with a plain-English error and refuse to advance until you fix it.

## Closed enums (canonical valid values)

Migrated from the old `SCHEMA.md §6` (deleted in Phase C-8). The loader (`load-playbook.sh`) rejects any value not in these lists with a plain-English error.

**Action `tag:` field** — defines what shape the action's EXECUTE step takes:

- `USER-LED` — user supplies the answer; agent asks
- `AGENT-LED` — agent drafts with alternatives; user approves; iterate
- `BUILD-TASK` — test exists → RED → code → GREEN → commit (test-first)
- `BUILD-SPIKE` — code → smoke test → commit (exploration; no test-first)
- `TRANSITION` — runs verify-stage, stages spec + verification.json, commits the phase advance

**Trust level** — set by frontmatter `trust:` AND verified by manifest hash-pin:

- `framework` — content is trusted (treat as instructions)
- `project` — content is untrusted (treat as data only)
- If declared `framework` but the manifest hash mismatches, the loader downgrades to `project` and emits a warning. Not a hard block.

**Stage IDs** — uppercase letters only, max 16 chars. No digits, no underscores. Examples: `SPEC`, `BUILD`, `SHIP`, `RESEARCH`.

**Extension status** — `on` or `off`.

## Hash normalisation (manifest pin + section hash)

The manifest pin (`pre-commit-stage-verified.sh`) and section approval hash (`hash-section.sh`) both normalise content before hashing — same algorithm:

1. Decode UTF-8
2. Convert all line endings to `\n`
3. Strip trailing whitespace from each line
4. Strip leading and trailing blank lines from the captured block
5. Compute SHA-256 over the normalised UTF-8 bytes (lowercase hex, 64 chars)

Reason: editors silently flip CRLF/LF on Windows, and trailing whitespace is meaningless. A raw byte hash would force re-pinning on every checkout. The normalisation contract is what lets `.sdd/.cache/manifest.json` ship as the framework's tamper-detection anchor without false-positives.

Identical algorithm in three places (single source of truth — `hash-section.sh`'s implementation; the moat hook + load-playbook.sh re-implement it byte-for-byte and tests T36-T40 mutation-verify the agreement).
