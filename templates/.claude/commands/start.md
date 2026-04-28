---
description: Start a new feature, bug, idea, or other work item. Scaffolds the folder, spec.md, and INDEX.md.
argument-hint: "<title for the new work item>"
---

# /start

Begin a new work item. Pick the kind of work, give it a one-line title, and the framework scaffolds the folder + spec.md + updates INDEX.md.

## Usage

```
/start build a waitlist landing page
/start fix the login button     # (Phase C: routes to bug playbook)
/start could we use Postgres    # (Phase C: routes to idea playbook)
```

## What this command does

1. Reads `.sdd/config.md` to find which playbooks are available in this project.
2. **B-1 ships only `feature`.** If you say `/start fix the login button`, the framework will tell you in plain English: *"Bug playbook is coming in Phase C. For now, use feature — it's the same process, just with extra steps you can leave blank."*
3. Computes the next ID for the work-item folder (e.g., `001`, `002`, ...).
4. Derives a slug from your title (`build a waitlist landing page` → `build-a-waitlist-landing-page`).
5. Creates `.sdd/<work-item-folder>/<NNN>-<slug>/spec.md` with all the playbook's action headings as placeholders.
6. Updates `INDEX.md` to point at the new work item.
7. Tells you the exact `/next` to run first (which will ask the first question — usually §1 Problem).

## What this command does NOT do

- It does NOT make a git branch. The first `/next` after `/start` does that.
- It does NOT auto-fill any of the spec sections. You walk through them with `/next`.
- It does NOT pick a playbook by guessing your intent. v0.9 ships only `feature`, so it just uses that. When future playbooks (`bug`, `idea`, etc.) ship, the framework will ask you which.
- It DOES accept `--extends=<id>` (or `--extends <id>`) for evolving a shipped feature. The flag resolves leniently against the work-item folder (exact slug, bare NNN, substring); the new spec.md frontmatter records `extends: [features/<id>-<slug>]`, and `mark-shipped` writes a richer `## Shipped` block with cross-references. Plain-English failures on no-match or ambiguity tell the user to run `/status` to see what's shipped.

## Implementation

The slash command body invokes `bash .sdd/scripts/start.sh "<arg>"`. The script:
- Reads `config.md` for available playbooks
- Reads the chosen playbook's frontmatter for `work_item_folder` and `stages`
- Slugifies the title
- Creates the folder + spec.md
- Updates INDEX.md
- Prints next-steps

If anything goes wrong (no `.sdd/`, malformed config, requested playbook doesn't exist), it exits non-zero with a plain-English error message — no bash stack trace.
