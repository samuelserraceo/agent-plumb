---
type: config
sdd_version: 0.8.0
playbooks_available: [feature]
default_playbook: feature
extensions: {}
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

## What you can edit directly

This whole file. It's plain Markdown with YAML frontmatter — no special tooling. Edit, save, run `/next`, the framework picks up the changes.

The one rule: **don't reference a playbook or extension that doesn't exist** (no file in `.sdd/playbooks/<slug>.md` or `.sdd/extensions/<slug>.md`). The loader will catch you with a plain-English error and refuse to advance until you fix it.
