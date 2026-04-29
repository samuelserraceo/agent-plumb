# /settings — view or change SDD framework settings

**What it does:** prints the resolved settings for this project, or updates a single setting in place. No editor required.

**Why it exists:** the framework's config (parameters, file rules, events, etc.) lives in `.sdd/config.md`. Editing YAML by hand is fine for power users, but most users want a one-line check ("what's my budget for a step?") or a one-line change ("bump my budget to 30 minutes").

## Usage

```
/settings                              # list every setting + its current value
/settings get <key>                    # print one setting (e.g. /settings get budget.max_minutes)
/settings set <key> <value>            # change one setting (writes to .sdd/config.md)
/settings reset <key>                  # remove an override and fall back to the default
```

## Examples

```
/settings
  → prints the full inventory: parameters, file_rules, events, …

/settings get budget.max_minutes
  → budget.max_minutes = 5 [project]

/settings set budget.max_minutes 30
  → updates .sdd/config.md → parameters.budget.max_minutes: 30

/settings get voice.plain_english
  → voice.plain_english = True [project]

/settings get folder_rules.deferred_paths
  → folder_rules.deferred_paths = ['.sdd/topics/', '.sdd/archive/', '.sdd/bugs/'] [project]
```

The bracketed `[project]` label is the **provenance** — where the active value comes from in the cascade. Other possible labels:

- `[project]` — value comes straight from `.sdd/config.md` (the project default)
- `[work-item:<id>]` — overridden in the active spec.md frontmatter `overrides:` block
- `[stage:<id>]` — overridden in the active playbook's per-stage `overrides:` block
- `[action:<slug>]` — overridden in the action's frontmatter (e.g. `proposed-approach.md`)
- `[step:<id>]` — overridden in spec.md's active step row

Provenance is shown only for `parameters.*` keys (the cascade-aware block). Other keys (file_rules, events, etc.) live in `config.md` only and always show `[project]`.

## What you can change

The full inventory is in `.sdd/config.md` — eight setting blocks:

| Block | What it controls | Common values |
|---|---|---|
| `parameters.budget` | per-step time/token/commit caps (warn-only) | max_minutes, max_tokens, max_commits |
| `parameters.voice` | agent's prose style | plain_english, translate_jargon_on_first_use |
| `parameters.pace` | when the agent halts | halt_on_red_after_attempts |
| `parameters.ralph` | the headless build loop's pacing | max_iters, timeout_per_iter |
| `file_classes` | named groups of files (regex patterns) | CLAIM, POLICY |
| `co_stage_block` | which class pairs can't be staged together | `[CLAIM, POLICY]` |
| `file_rules` | per-file rules | append_only, size_warn, size_block, managed_section |
| `state_rules` | refusal rules driven by project state | phase_advance_with_open_blockers |
| `folder_rules` | canonical-folder enforcement | default_action, deferred_paths, root_allowed |
| `events` | the event → file-action map | section_approved, phase_transition, ship_complete |

## Cascade order (highest priority wins)

When the same setting is declared in multiple places, the framework picks the most-specific one:

1. **Step-level override** in spec.md (the active step's row)
2. **Action-level override** in `.sdd/actions/<slug>.md` frontmatter
3. **Stage-level override** in `.sdd/playbooks/<slug>.md` per-stage block
4. **Work-item override** in spec.md frontmatter
5. **Project default** in `.sdd/config.md` (this file)

`/settings get` shows where the current value comes from in brackets, e.g.:

```
budget.max_minutes = 30 [action:proposed-approach]
```

Means the project default (5 minutes) is being overridden by the proposed-approach action's frontmatter.

## What this command actually does (under the hood, for the curious)

`/settings` invokes `.sdd/scripts/settings.sh`. The script:
- Reads `.sdd/config.md`'s YAML frontmatter
- For `get`/`list`: walks the parameters tree and prints each leaf with provenance
- For `set`: updates the YAML in-place using PyYAML's `safe_dump`. **Note:** YAML comments inside the frontmatter are NOT preserved through `safe_dump` — comments below the frontmatter (in the Markdown body) are untouched, but inline `# comment` lines inside the YAML block get stripped on first `set` call. If you rely on inline YAML comments for documentation, edit `.sdd/config.md` by hand instead.
- For `reset`: removes the matching override key from frontmatter (same comment caveat)

If you'd rather edit by hand, open `.sdd/config.md` — same result.

## End the turn

Always end with the next thing the user can do:
- After `list` or `get`: *"What would you like to change? Use `/settings set <key> <value>`, or run `/next` to keep working."*
- After `set`: *"Done — `<key>` is now `<value>`. The change applies to your next `/next`."*
- After `reset`: *"Override removed. `<key>` falls back to its inherited value."*
