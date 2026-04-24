---
description: Skip the current SKIPPABLE rubric section with a reason.
---

$ARGUMENTS

Skip the current section of the active feature's `spec.md`, if and only if it is marked `[SKIPPABLE: ...]`.

## Rules

1. Read `.sdd/INDEX.md` → find the active feature. Read `.sdd/features/<active>/spec.md`.
2. Find the current phase's first section containing any `[ ]`. Check whether that section's heading line contains `[SKIPPABLE:`.
   - **If NOT skippable** → refuse politely: *"§`<N>` `<name>` is required and cannot be skipped. Here's the first blocker: `<question>`."* and ask the next question as if `/next` had been invoked.
   - **If skippable** → proceed.
3. Take the reason from `$ARGUMENTS`. If empty, ask the user: *"Skip §`<N>` — what's the reason? One line."* Then wait.
4. On skip:
   - Replace every `[ ]` in the section with `⏭ skipped — <reason>` (keep the bullet/heading structure so future readers see what was skipped).
   - Append ` [SKIPPED]` to the section's heading line.
   - Update the `Active blocker:` pointer to the next real blocker.
   - Commit: `[SDD:<feature-id>] spec: skip §<N> — <reason>`.
   - If the skip has downstream effect (e.g. §4 skipped → Wireframe is auto-skipped for non-UI features), ALSO skip the downstream section in the same commit and mention it in the commit body.
5. End your turn by announcing the next blocker and how the user proceeds, per the call-to-action rules in `.sdd/CLAUDE.md`.

## Never

- Never skip §1, §2, §3, §5, §6, §7, §11, §12 — they are not marked skippable.
- Never skip just because the user is tired or bored. If they insist with no feature-level reason, push back once: *"This isn't marked skippable. Are you sure? You'll lose the thing it's supposed to capture: `<capture purpose>`."*
