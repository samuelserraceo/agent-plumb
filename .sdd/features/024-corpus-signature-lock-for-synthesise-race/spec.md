---
playbook: feature
---

# corpus signature lock for synthesise race

[PHASE: BUILD]

**Active blocker:** _(none — SPEC approved, BUILD in progress)_

## PHASE: SPEC

### 1. brief-intake

[APPROVED]

**Brief** (from `gh issue view 113` + Sam's 2026-05-12 task assignment):

The MCP server's `synthesise()` query (Tier 3, v1.1) reads a corpus signature (hash over all `.sdd/` markdown file mtimes + sizes) and uses it as a cache key. If a user edits a `.sdd/` file in parallel with a `synthesise()` call, the signature read can land mid-write — producing a fingerprint that doesn't match the actual on-disk state at any single moment, which means the cache key indexes inconsistent data.

This is **defensive scope**: Tier 3 is FALSE on this project today (`parameters.mcp.tier3.enabled: false`), so the race can't actually fire here. We're shipping the lock helper + doctrine NOW so they're already in place when Tier 3 enables on a downstream project.

**Scope** (small, focused):
1. New `templates/.sdd/scripts/corpus-signature-lock.sh` — mkdir-as-lockdir helper (bash 3.2 / macOS compatible)
2. Doctrine paragraph in `templates/CLAUDE.md` synthesis section: "acquire lock before reading corpus signature; release after caching"
3. Mirror script to live `.sdd/scripts/`
4. Manifest repin both copies
5. 3 BUILD task-tests T290-T292

**Out of scope:** integrating the lock into the actual `synthesise()` Python code in `extensions/sdd-mcp-server/` (that's a Tier 3 enablement task — happens on the project that flips `tier3.enabled: true`, which is not this one). All we ship here is the bash helper + doctrine so the agent knows to use it.

### 2. problem

[APPROVED]

- **who:** downstream-project users who enable Tier 3 synthesis (`parameters.mcp.tier3.enabled: true`) AND edit `.sdd/` markdown files while a background agent or parallel session fires `synthesise()` calls.
- **why-now:** filed during v1.1 Tier 3 SPEC §15 edge-case sweep (2026-05-01); deferred from v1.1 itself because the fix lives in v1.0 graph-cache + a helper script, not Tier 3 code. Shipping defensively so the helper is ready BEFORE the first downstream project enables Tier 3.
- **what-breaks:** signature read lands mid-write → cache key indexes inconsistent corpus state → `synthesise()` may return cached output that doesn't reflect what's on disk, OR miss cache entries that should have hit. Silent correctness bug; no error surfaces.

### 3. user-stories

[APPROVED]

- As a downstream-project user with Tier 3 enabled, I want `synthesise()` to avoid reading corpus state mid-write, so that my cache key reflects a coherent snapshot of `.sdd/`. {best-effort: lock helper bounds the window; T291 verifies contention detection}
- As the SDD framework maintainer (Sam), I want the lock helper + doctrine in place BEFORE Tier 3 enables on a real project, so that the v1.1 Tier 3 enablement doesn't ship with this race latent.

### 4. ux-brief

[APPROVED]

No user-facing UX. This is a behind-the-scenes safety helper that the synthesise() integration will call internally. The only user-visible signal is the absence of a stale-cache symptom.

### 5. proposed-approach

[APPROVED]

**Chosen approach: mkdir-as-lockdir bash helper.**

`mkdir` is atomic on POSIX filesystems — two concurrent `mkdir` calls on the same path: exactly one succeeds, the other gets `EEXIST`. This is the same pattern `templates/.sdd/scripts/background-while-waiting.sh` already uses (F009 precedent, ~line 47), and it's bash 3.2 / macOS compatible since `flock` isn't part of base macOS without Homebrew util-linux. {verify-by: T291 bash-background-then-acquire — proves exactly one of two concurrent acquires wins on this filesystem}

The helper exposes two subcommands:
- `acquire <lockdir-path>` — try to `mkdir` the lock; exit 0 on success, exit 1 if held; bounded retry loop (50 retries × 0.1s = ~5s ceiling, same as F009).
- `release <lockdir-path>` — `rmdir` the lock; exit 0 (idempotent — silently skip if absent).

**Alternatives considered + rejected:**
- `flock(1)` — not in macOS base, requires Homebrew util-linux. Rejected for bash 3.2 / macOS compat constraint.
- `mv`-based locking (atomic rename) — atomic but more error-prone in cleanup (orphan files vs orphan dirs); F009 already proved `mkdir` works.
- Python-side `fcntl.flock` inside `synthesise()` itself — would couple the lock to the MCP server. Bash helper is reusable across other synthesise-adjacent callers (e.g. `get_neighbours` if those ever cache too).

### 6. data-contract

[APPROVED]

No data-model changes. The lock is a transient filesystem directory (`<cache-dir>/.corpus-signature.lock.d`), not a persisted entity. Same shape as `background-while-waiting.sh`'s `.background-emit.lock.d`.

### 7. flows

[APPROVED]

**Flow 1: successful synthesise() call (single agent, no contention)**
1. Agent calls `synthesise()` via MCP server.
2. Server invokes `corpus-signature-lock.sh acquire <path>` → exit 0 (no contention).
3. Server reads corpus signature (hash over `.sdd/` mtimes + sizes).
4. Server uses signature as cache key, returns synthesised output.
5. Server invokes `corpus-signature-lock.sh release <path>` → exit 0.

**Flow 2: contention — parallel synthesise() + user edit**
1. Agent A calls `synthesise()` and acquires the lock.
2. Agent B (or user save) calls `synthesise()` — `acquire` retries ~5s waiting for A.
3. If A finishes within 5s → B acquires → reads coherent signature → cache key consistent.
4. If A holds longer than ~5s → B exits 1; caller logs the contention and either retries or surfaces an error (caller policy, out of scope here). {verify-by: T291 — proves second acquire exits 1 when held}

### 8. dependencies

[APPROVED]

None. Pure bash, no external services, no pricing. Uses `mkdir`, `rmdir`, `sleep`, `command -v`, all POSIX-baseline.

### 9. out-of-scope

[APPROVED]

- Integration into the actual Python `synthesise()` flow in `extensions/sdd-mcp-server/`. That happens on the downstream project that flips `tier3.enabled: true` — not here.
- Wrapping `get_neighbours` / `get_backlinks` / `search_within` (v1.0 graph queries) with the same lock. Issue #113 notes these face the same race today; addressing them is a separate v1.0 graph-cache patch (atomic-snapshot approach, ~1 day work in `_graph_cache.py` per issue #113). Out of scope for this defensive ship.
- Cleanup-on-crash beyond `EXIT` trap. If a holder gets SIGKILL'd (no trap fires), the lockdir orphans and the next acquire waits ~5s then exits 1. Caller can `rmdir` manually. Same limitation F009 carries; documented, accepted.
- Cross-machine locking (NFS, distributed FS). `mkdir` atomicity is local-filesystem-only. Tier 3 today runs against local `.sdd/` only, so out of scope.

[APPROVED]

### 10. non-functional

[APPROVED]

- **Performance:** `mkdir` + `rmdir` are O(1) syscalls. The 50-retry × 0.1s loop caps wait at ~5s — same as F009 — chosen because synthesise() calls themselves take seconds (LLM round-trip), so 5s of lock-wait is a small fraction.
- **Compatibility:** bash 3.2 (macOS default), no `flock`, no `mapfile`, no `[[` -nt`-style date arithmetic. Tested patterns mirror F009.
- **Security:** lockdir lives under the project's `.sdd/.cache/` (or `$SDD_CACHE_DIR` override). Same trust boundary as the rest of `.sdd/`.
- **Concurrency contract:** at most one holder at any instant on the same lockdir. Two concurrent `acquire` calls — exactly one returns 0, the other retries then returns 1.

### 11. acceptance-criteria

[APPROVED]

- [ ] AC1: `corpus-signature-lock.sh` exists in `templates/.sdd/scripts/` and live `.sdd/scripts/`, both executable {verify-by: T290 bash-stat}
- [ ] AC2: Calling `acquire <path>` when no lock is held exits 0 and creates the lockdir {verify-by: T292 bash-exit-and-stat}
- [ ] AC3: Calling `acquire <path>` when another process holds the lock exits 1 within ~5s {verify-by: T291 bash-background-then-acquire}
- [ ] AC4: Calling `release <path>` removes the lockdir and exits 0 (idempotent — also exit 0 if already absent) {verify-by: T292 bash-exit-and-stat}
- [ ] AC5: Doctrine paragraph in `templates/CLAUDE.md` synthesis section names the helper script + acquire-before-read / release-after-cache discipline {verify-by: bash-grep `corpus-signature-lock.sh` templates/CLAUDE.md}
- [ ] AC6: Both manifest copies (`templates/.sdd/manifest.json` + live `.sdd/manifest.json`) repin the new script {verify-by: bash-grep `corpus-signature-lock.sh` manifest.json}

### 12. signoff-steps

[APPROVED]

Sam to-do before merge:
- Read `corpus-signature-lock.sh` source (40 lines), confirm the mkdir-as-lockdir pattern matches F009.
- Read the new paragraph in `templates/CLAUDE.md`, confirm it names the script + the acquire-before-read / release-after-cache contract clearly.
- Run `bash test/F024-corpus-signature-lock-test.sh` locally; confirm T290-T292 all green.

### 13. wireframe

[APPROVED]

Non-UI feature — no screens. Flow-only diagram (ASCII):

```
synthesise() caller        corpus-signature-lock.sh        filesystem (.sdd/.cache/)
       │
       │ acquire <path>          ├── mkdir <path>/.corpus-signature.lock.d
       │ ─────────────────────► │      ├── success → exit 0 (this caller holds the lock)
       │                         │      └── EEXIST → retry up to 50×0.1s, then exit 1
       │ ◄───────────────────── ┘
       │
       │ (read .sdd/ signature, use as cache key, cache result)
       │
       │ release <path>          ├── rmdir <path>/.corpus-signature.lock.d
       │ ─────────────────────► │      └── exit 0 (idempotent — already-absent is fine)
       │ ◄───────────────────── ┘
```

### 14. plan-decompose

[APPROVED]

- [ ] T290: `corpus-signature-lock.sh` exists in BOTH locations + is executable + has bash 3.2-compatible shebang
- [ ] T291: `acquire` exits 1 when another process holds the lock (test via background subshell holding the lock + foreground second acquire)
- [ ] T292: `acquire` exits 0 + creates lockdir on first call; `release` exits 0 + removes lockdir; second `release` (idempotent) also exits 0

### 15. edge-case-sweep

[APPROVED]

- **Crash during hold (no EXIT trap fires)** — orphan lockdir; next caller waits 5s, exits 1, surfaces contention. Documented, accepted. Same limitation as F009.
- **Disk full → mkdir fails for non-EEXIST reason** — `mkdir` exits non-zero, helper retries 50× thinking it's contention, eventually exits 1. Caller sees "lock contention timeout" but real cause is disk-full. Acceptable for v1; a v2 could distinguish EEXIST from other errors. Out of scope here.
- **Lockdir path on a path that doesn't exist** — `mkdir -p` parent dirs first? Decision: the caller passes the FULL lockdir path; the helper assumes the parent (`$cache_dir`) exists. If not, `mkdir` fails, helper retries and times out → exit 1. Caller responsibility to make sure the cache dir exists (same as F009). {best-effort: caller-contract; not separately tested}
- **Concurrent `release` calls** — `rmdir` fails on the second one with "directory not found"; helper swallows that and exits 0 (idempotent). Test T292 covers this.

### Exit checks
- [x] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+'
- [x] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+'

## PHASE: BUILD

(BUILD phase starts here — tasks T290-T292 flip to [x] as they go green, with linked commits.)
