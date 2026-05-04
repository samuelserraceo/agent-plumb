# sdd-migrate — refresh project's .sdd/ tree from upstream framework

[PHASE: BUILD]

**Active blocker:** §B1 (next action: run-mode-chosen → full-autonomous → T01)

## PHASE: SPEC

### action: problem

- [x] who: Sam (framework maintainer) and any teammate / downstream user who installed SDD at some past commit and now wants upstream framework improvements (new hooks, action prose updates, script bug fixes) without losing their project-specific data (spec.md, decisions.md, INDEX.md, patterns.md, data-model.md, stack.md, principles.md, config.md customisations).
- [x] why-now: feature 006 just shipped a new pre-commit-test-first.sh hook today. Channel A (.claude/) auto-flows via /plugin update; Channel B (.sdd/ project tree) does not. Without sdd-migrate, downstream teams stay on whatever SDD version they first installed and the framework stops being useful as it evolves. This is the load-bearing piece for SDD to become a real updatable internal package.
- [x] what-breaks: every framework improvement only reaches the team via "delete your .sdd/ and re-run /sdd-setup" — which loses every project-specific file. Manifest hash drift surfaces as commit-time errors, but the user has no mechanical fix.

### action: success

- [x] metric: **quality** — running `bash .sdd/scripts/sdd-migrate.sh` in a downstream project on an older SDD version refreshes the framework files (hooks, actions, scripts, playbooks, MCP server) to upstream HEAD without touching the user's project-specific data files. Measurable as a regression test in run-framework-test.sh: scaffold a fake-old-project, run sdd-migrate, assert framework files match upstream + user files unchanged. **Target**: 1 new regression test passes, AND existing 216+ framework tests still pass. **Baseline**: today, 0 migration tools exist.

### action: user-stories

- [x] stories: 3 personas — (1) **Sam (maintainer)**: "As the framework maintainer, I want to refresh my own dogfood `.sdd/` from `templates/.sdd/` after every framework PR, so that I keep testing on the latest version without manually copying files." (2) **Teammate (internal user)**: "As a teammate using SDD on a project I started 2 weeks ago, I want to pull in upstream framework bug fixes and new hooks via a one-liner, so that my commits stop tripping manifest-drift errors." (3) **PR reviewer**: "As a reviewer of a downstream project's PR, I want to know which framework files are stock-standard vs locally edited, so I can focus on the user-specific changes."

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — CLI-only tool, no UI surface.

### action: proposed-approach

- [x] approval: **dry-run by default + --apply with per-file confirmation**. Approved by Sam on 2026-05-04 ("crack on" with my proposed defaults).

  **Approach (chosen):**
  1. New script `templates/.sdd/scripts/sdd-migrate.sh` (mirrored to project on init).
  2. **Dry-run by default** — no `--apply` flag, prints what would change in 4 categories: `ADD` (new framework files since user's install), `UPDATE-CLEAN` (framework files that drifted upstream but user's copy still matches the prior shipped hash → safe overwrite), `UPDATE-CONFLICT` (framework files where user's copy differs from BOTH upstream and the prior shipped hash → user has local edits), `REMOVED` (files gone from upstream but present locally → kept untouched, just listed).
  3. **`--apply` mode** — applies ADD + UPDATE-CLEAN automatically. For each UPDATE-CONFLICT, prompts: `keep / overwrite / show-diff`. Default response (Enter) = `keep` (safe failure mode).
  4. **Untouched ever** — user-data files: `spec.md`, `INDEX.md` (re-pinned section only), `decisions.md`, `patterns.md`, `data-model.md`, `stack.md`, `principles.md`, anything under `.sdd/features/`, `.sdd/bugs/`, `.sdd/refactors/`, `.sdd/ideas/`, `.sdd/.cache/`. List enforced by hard-coded exclusion regex.
  5. **Managed sections** in `CLAUDE.md` and `config.md` — only the content between `SDD-MANAGED-START` and `SDD-MANAGED-END` markers is replaced. User-owned content outside the markers is preserved.
  6. **Hash-aware** — uses the same normalised-SHA-256 algorithm as the manifest pin (LF + strip trailing whitespace + strip blank-line edges). Reads the user's `.sdd/.cache/manifest.json` to get prior shipped hashes.
  7. After `--apply`, writes the new manifest with upstream hashes so the user's commits stop tripping manifest-drift errors.

  **Alternative considered: 3-way merge (rejected).** A `git merge`-style 3-way merge with conflict markers in files would be fancier but adds dependency on git's merge driver and produces files that cannot be cleanly rolled back. The chosen overwrite-with-confirmation matches SDD's "fail closed" doctrine and lets the user `git diff` after to see what changed.

  **Files touched:**
  - `templates/.sdd/scripts/sdd-migrate.sh` (NEW) + mirror at `.sdd/scripts/`
  - `templates/.claude/commands/sdd-migrate.md` (NEW slash command wrapper) + mirror
  - `test/run-framework-test.sh` (T160 regression — fake-old-project end-to-end)
  - `templates/.sdd/.cache/manifest.json` (re-pinned with the new script's hash)
  - `docs/walkthrough.html` (cards listing the new tool)
  - `.sdd/INDEX.md` (Active line)
  
  {verify-by: T-160-sdd-migrate}

### action: data-contract

- [x] approval: **no new entities**. The tool reads existing `.sdd/.cache/manifest.json` (existing schema), reads existing framework files (no schema), writes the updated manifest (same schema) + updates files in place. No `data-model.md` changes. Approved by Sam on 2026-05-04 (implicit via "crack on" with proposed approach).

### action: flows

- [x] flows: 2 critical flows. **Flow 1 (dry-run, implements story 1+2):** user runs `bash .sdd/scripts/sdd-migrate.sh` → script reads upstream framework files (from a path arg or env var pointing at the framework checkout) → categorises every tracked file as ADD / UPDATE-CLEAN / UPDATE-CONFLICT / REMOVED → prints summary table. **Flow 2 (apply, implements story 1+2):** user runs `bash .sdd/scripts/sdd-migrate.sh --apply --upstream=/path/to/sdd-framework` → applies ADD + UPDATE-CLEAN automatically; for each UPDATE-CONFLICT, prompts the user to keep/overwrite/show-diff → at end, writes the new manifest with upstream hashes. {verify-by: T-160-sdd-migrate}

### action: dependencies

- [x] deps: no new external services. Uses existing tools: `bash`, `python3` (for hash computation, same as manifest pin), `diff` (POSIX). Cost = $0/mo. {best-effort: Sam at SHIP — confirms no surprise installs}

### action: out-of-scope

- [x] list: 5 explicit deferrals — (1) **3-way merge** (rejected per §5 alternatives — picked overwrite-with-confirmation instead). (2) **Auto-fetch upstream** — this round requires `--upstream=<path>` to point at a local SDD framework checkout. Future iteration could `git clone` from a fixed URL. (3) **Schema migration** — if `templates/.sdd/config.md` adds new keys, migrate doesn't auto-merge them into the user's `config.md`; user re-runs `/sdd-config <key>` for missing fields (the existing flow). (4) **MCP server queries** — extensions/sdd-mcp-server/queries/ are not part of `.sdd/` (live in `extensions/`); migrate skips them. Users update via `pip install` or git pull on the extension separately. (5) **Rollback** — no `--rollback` flag this round; user reverts via `git`. The manifest re-pin is the only "destructive" change and it's just a JSON file overwrite.
- [x] approval: user_approves — Sam approved on 2026-05-04 ("crack on" with proposed defaults).

### action: non-functional

- [x] constraints: 3 categories — performance, security, compliance. Detail below.
  - **Performance**: dry-run runs in under one second on a 100-file tree (typical SDD project size). `--apply` adds the cost of writing files; bounded by tree size. {best-effort: Sam at SHIP — confirms timing on real downstream project}
  - **Security**: skips the credential flow entirely (no prompts). Reads / writes only inside the user's project directory and the user-supplied `--upstream=<path>`. No network calls. {verify-by: T-160-sdd-migrate}
  - **Compliance**: no PII, no external API calls. Tool runs locally only.

### action: acceptance-criteria

- [x] approval: 7 ACs covering dry-run, apply, conflict prompts, and exclusions. Approved by Sam on 2026-05-04 ("crack on").

- [ ] AC1: dry-run on a clean (synced) downstream project → reports 0 changes; exit 0. → tests/task-001.sh
- [ ] AC2: dry-run on a stale downstream project (missing a hook file added upstream) → reports the missing file under ADD; exit 0. → tests/task-002.sh
- [ ] AC3: dry-run on a stale downstream project where one tracked file's hash differs upstream AND user has stock prior content → reports UPDATE-CLEAN; exit 0. → tests/task-003.sh
- [ ] AC4: dry-run on a project where user has locally edited a tracked framework file → reports UPDATE-CONFLICT; exit 0. → tests/task-004.sh
- [ ] AC5: --apply mode applies ADD + UPDATE-CLEAN entries automatically and writes the new manifest. After --apply, a fresh dry-run reports 0 changes. → tests/task-005.sh
- [ ] AC6: --apply on UPDATE-CONFLICT prompts (keep / overwrite / show-diff); default Enter response is keep (safe failure mode). → tests/task-006.sh
- [ ] AC7: user-data files preserved bit-for-bit on --apply — INDEX.md, decisions.md, patterns.md, data-model.md, stack.md, principles.md, .sdd/features/**, .sdd/bugs/**, .sdd/refactors/**, .sdd/ideas/** untouched. → tests/task-007.sh

### action: signoff-steps

- [x] manual-steps: 3 manual checks before SHIP — (1) Run sdd-migrate on the framework's own dogfood `.sdd/` against `templates/.sdd/`. Confirm 0 changes (the framework is its own user; should be in sync). (2) Manually edit a hook file locally; re-run dry-run; confirm UPDATE-CONFLICT report. (3) Run `--apply` with that conflict; pick `show-diff`; confirm the diff renders cleanly. {best-effort: Sam at SHIP}

### action: wireframe

- [x] wireframe: drafted — non-UI flow (categorise → ADD/UPDATE-CLEAN/UPDATE-CONFLICT/REMOVED → apply → re-pin), architecture (sdd-migrate.sh + slash command wrapper, exclusion list of user-data files), concrete example showing ADD/CLEAN/CONFLICT output for a real "missing today's test-first hook" scenario.

### action: plan-decompose

- [x] tasks: 7 tasks (T01-T07) — 1:1 with AC1-AC7. T01 introduces the script skeleton (dry-run reporting on a synced project = 0 changes); T02-T07 extend it.

- [x] T01 GREEN: Skeleton landed. templates/.sdd/scripts/sdd-migrate.sh (+ mirror) walks 6 tracked dirs (.claude/hooks, .claude/commands, .sdd/scripts, .sdd/actions, .sdd/playbooks, .sdd/skeletons), hashes via the framework's normalised SHA-256, reads prior-shipped hashes from user manifest, categorises into ADD/UPDATE-CLEAN/UPDATE-CONFLICT/REMOVED, and prints summary. Synced project → "in sync" message. T160 added (217/217 passing). → tests/task-001.sh
- [ ] T02: ADD detection (AC2). Tracked file in upstream, missing in user → reports under ADD. → tests/task-002.sh
- [ ] T03: UPDATE-CLEAN detection (AC3). User hash matches prior shipped, upstream has newer → reports under UPDATE-CLEAN. → tests/task-003.sh
- [ ] T04: UPDATE-CONFLICT detection (AC4). User hash differs from BOTH upstream AND prior shipped → reports under UPDATE-CONFLICT. → tests/task-004.sh
- [ ] T05: --apply mode (AC5). Applies ADD + UPDATE-CLEAN automatically; writes new manifest. Fresh dry-run after = 0 changes. → tests/task-005.sh
- [ ] T06: --apply prompt on UPDATE-CONFLICT (AC6). keep / overwrite / show-diff; default Enter = keep. → tests/task-006.sh
- [ ] T07: User-data exclusion (AC7). INDEX.md, decisions.md, patterns.md, data-model.md, stack.md, principles.md, .sdd/features/**, .sdd/bugs/**, .sdd/refactors/**, .sdd/ideas/** preserved bit-for-bit even on --apply. → tests/task-007.sh

### action: edge-case-sweep

- [x] ec-sweep: drafted 4 candidates — EC1 missing user manifest (.sdd/.cache/manifest.json absent), EC2 user is on the framework's own repo (sees self as upstream → no-op), EC3 upstream has malformed manifest (corrupted JSON), EC4 file rename across upstream versions (foo.sh → foo-renamed.sh treated as REMOVE+ADD pair).
- [x] ec-pick: picked EC1 + EC2 → folded into existing AC1 (synced) and AC4 (conflict). EC3 deferred (corrupted upstream is rare; user can `git pull` again). EC4 deferred (file renames in framework code are rare; if it happens we'll surface as REMOVE+ADD which is honest).

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE" {verify-by: verify-stage.sh}
- [ ] C-spec-tasks: ≥1 task in plan-decompose section — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE" {verify-by: verify-stage.sh}

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full autonomous — Sam pre-approved this run mode for both feature 006 and bug 003 today; same default applies here.

**Run mode:** full-autonomous

### action: build-task

(driven by §14 tasks T01-T07 — each task lands as one commit)

### Exit checks
- [ ] C-build-tasks-green: every task is GREEN (test passing, code committed)
