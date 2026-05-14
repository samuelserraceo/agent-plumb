---
description: Refresh your project's `.sdd/` tree from upstream — pull in framework updates without touching your specs / decisions / patterns / data-model.
argument-hint: "[--apply] [--upstream=<path-or-url>]"
---

# /sdd-migrate

The wrapper around `bash .sdd/scripts/sdd-migrate.sh` for pulling framework updates into an existing SDD project. Categorises every framework-tracked file as ADD / UPDATE-CLEAN / UPDATE-CONFLICT / REMOVED via the framework's normalised SHA-256 hash. **User-data files are invisible to the tool by walk-list design** — your `INDEX.md`, `decisions.md`, `patterns.md`, `data-model.md`, `stack.md`, `principles.md`, `.sdd/features/**`, `.sdd/bugs/**`, `.sdd/refactors/**`, `.sdd/ideas/**` are never touched.

## Usage

```text
/sdd-migrate                                          # dry-run (default) — shows what would change, no writes
/sdd-migrate --apply                                  # apply mode with per-file confirmation on conflicts
/sdd-migrate --apply --upstream=~/Projects/sdd        # explicit upstream framework checkout
```

## What happens

1. **Walks every framework-tracked file** under `templates/.sdd/`, `templates/.claude/`, `.sdd/scripts/`, `.sdd/actions/`, `.sdd/playbooks/`, `.claude/hooks/`, `.claude/commands/`.
2. **Categorises each file** into one of:
   - **ADD** — exists upstream, missing locally → safe to copy
   - **UPDATE-CLEAN** — exists both sides, your local hash matches the prior pin → safe overwrite
   - **UPDATE-CONFLICT** — exists both sides, your local hash differs from prior pin → user confirms per file
   - **REMOVED** — exists locally, gone upstream → user confirms removal
3. **In `--apply` mode**, prompts per-file on conflicts. In dry-run (default), prints the categorisation and exits without writes.
4. **Re-pins the manifest** to upstream after a successful apply so commits stop tripping drift errors.

## Safety

- Default is dry-run. You see the change list before anything writes.
- User-data files are NEVER in the walk list. `INDEX.md` / `decisions.md` / `patterns.md` / `data-model.md` / `stack.md` / `principles.md` and every per-feature folder under `.sdd/{features,bugs,refactors,ideas}/` are invisible by design.
- Bash 3.2 compatible (works on stock macOS `/bin/bash`).
- After `--apply`, the manifest is re-pinned to upstream — your next commit will not trip the moat hook with hash-mismatch errors.

## When to run

- After a fresh clone of the upstream framework, when you want to pull recent improvements into an existing project.
- After `/plugin marketplace update` if the plugin path didn't fully refresh `.sdd/`.
- Periodically (e.g. monthly) to keep your project's framework version in step.

## Implementation

This slash command invokes:

```bash
bash .sdd/scripts/sdd-migrate.sh "$@"
```

with the args you pass through. The script lives at `.sdd/scripts/sdd-migrate.sh` and is manifest-tracked.

## Why this file exists

F007 (PR #157) shipped `sdd-migrate.sh` and the dry-run/apply flow. The F007 spec.md line 44 promised this slash-command wrapper but the file was never landed. GPT-5.5's external review (2026-05-14) caught the ledger lie. This file makes the spec's promise true.
