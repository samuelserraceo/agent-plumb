# brief-summarise skeleton

The agent emits this skeleton AFTER the user pastes a brief in `brief-intake.md` and BEFORE pre-filling spec.md sections.

## Shape

The agent prints a 3-bullet recap covering: who's affected, what changes, what success looks like. Plain English; quote the brief verbatim where possible. End with confirm-or-amend.

```text
Here's what I just heard from your brief, across §1 + §3:

  • Who: <verbatim quote or 1-line paraphrase from brief #3 (audience)>
  • What changes: <verbatim quote or 1-line paraphrase from brief #1 (one-line summary)>
  • Success looks like: <verbatim quote from brief #4 (M1/M2/M3 done shape)>

I'll pre-fill §1, §3, §6, §7, §8, §10 from this. §11 ACs and §14 tasks come next via the standard ceremony.

Confirm or tell me what to fix.
```

## Doctrine

- Three bullets, no more (CLAUDE.md 5-line cap applies — recap + confirm = 5 lines max).
- Quote the brief; don't paraphrase from memory (CLAUDE.md verbatim-quote rule per §171).
- End with the explicit confirm prompt: *"Confirm or tell me what to fix."*
- If the brief is missing one of the 3 facets (e.g., no clear audience), say so explicitly: *"Who: not specified in your brief — I'll ask in §1.who follow-up."*

## End-of-section recap (#207 Part 6 — same skeleton, different trigger)

This skeleton ALSO fires at end-of-action for any multi-step USER-LED action (e.g. §1 problem, §3 user-stories). Same shape:

```text
Here's what I just heard from you across §<N>:

  • <restate point 1>
  • <restate point 2>
  • <restate point 3>

Confirm or tell me what to fix.
```

Skip on within-action continuations (e.g. §1.who → §1.why-now share context — only emit at action boundary). Skip on AGENT-LED actions where the agent draft IS the recap.
