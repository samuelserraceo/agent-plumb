---
description: Capture an idea to backlog cheaply — single file in .sdd/ideas/, no commitment.
argument-hint: "<one-liner describing the idea>"
---

# /sdd-idea

Capture an idea to the backlog. Cheap parking spot — no commitment to build. Promote to a real work item later via `/sdd-start` when it earns it.

Run `bash .sdd/scripts/idea.sh "$ARGUMENTS"`. The script creates `.sdd/ideas/<NNN>-<slug>.md` and adds an entry to the Ideas section of `INDEX.md`. Same flow as Claude Code's `/idea`.
