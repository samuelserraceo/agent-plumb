---
type: config
sdd_version: 0.8.0
playbooks_available: [feature]
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
---

# SDD project configuration

This file is your one knob for telling SDD what's available in this project. The framework reads it on every `/start` and `/next` to know which playbooks you can pick from and which optional extensions to apply.

## What each switch means (plain English)

### `sdd_version: 0.8.0`

Which version of the SDD framework this project was created against. The framework warns on mismatch so you can re-run a migration if you upgrade.

### `playbooks_available: [feature]`

Which workflows you can pick from when you run `/start`. v0.8.0 ships only **feature** — the "build something new" journey. More playbooks (`bug`, `idea`, `question`, `project`) ship in Phase C — they'll appear here automatically when you upgrade and pick "yes, install the new playbook" during migration.

### `default_playbook: feature`

If you run `/start "do the thing"` without specifying a playbook, this is the one used. Right now there's only one option, so this is just `feature`. After Phase C, you can change it to whatever you start most often.

### `extensions: {}`

Empty — v0.8.0 ships zero extensions. **Phase B-2 ships the first extension: `ci-moat-enforcement`** (server-side CI verification of your locally-checked work, so even `--no-verify` git commits get caught at PR time). Other extensions like `obsidian-sync`, `slack-notifications`, etc. are Phase C+ ideas.

When extensions become available, this section will look like:

```yaml
extensions:
  ci_moat_enforcement: on    # or "off" if you don't want CI verification
```

You'll never have to write the YAML by hand — `/start` and the migration scripts edit this file for you.

### `size_thresholds:` (optional, not shown above)

Override the framework's default warn/block thresholds for your memory files. Defaults are in SCHEMA.md §4.2. Most projects don't need to touch this. Add it if your project has a working pattern of, say, an unusually large `data-model.md` that the framework keeps complaining about.

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

Add new sub-blocks as your project's needs grow — the resolver passes any keys through unmodified, so your action overrides can introduce custom keys (e.g., `approval_threshold: stricter` for high-stakes work items).

## What you can edit directly

This whole file. It's plain Markdown with YAML frontmatter — no special tooling. Edit, save, run `/next`, the framework picks up the changes.

The one rule: **don't reference a playbook or extension that doesn't exist** (no file in `.sdd/playbooks/<slug>.md` or `.sdd/extensions/<slug>.md`). The loader will catch you with a plain-English error and refuse to advance until you fix it.
