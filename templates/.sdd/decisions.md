# SDD Decisions Log

> **Append-only event log.** Every approval, phase transition, and
> notable decision gets one entry. Future-you reads this to remember
> WHY past-you committed to something — patterns.md captures the
> *what* and *how*; this file captures the *when* and *why*.
>
> **Enforced**: `pre-commit-decisions-append-only.sh` blocks any
> commit that removes or modifies an existing entry. Edits to past
> entries fail the pre-commit hook with a plain-English error.
>
> **Format**: each entry is one Markdown level-2 section:
>
> ```
> ## <ISO-Z timestamp>  [<work-item-id>]  <playbook>/<sub-action>
> <one-paragraph summary in plain English of what was decided>
> Hash: <sha256 if section was approved> (optional)
> ```
>
> Append entries with `>>` from the agent's command. Never `>` (would
> overwrite). Never edit manually unless re-creating the whole file
> from scratch — and that should be a one-time `[SDD] decisions: reset`
> commit, never a routine operation.

<!-- entries below this line; do not edit existing lines, only append -->
