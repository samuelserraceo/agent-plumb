---
description: Print the current SDD workflow state — phase, open blockers, and resolved parameters for the active step.
---

Show the user the current workflow state. Run these Bash commands and present the output cleanly:

```bash
cat .sdd/INDEX.md
echo ""
echo "---"
# Render the active-source banner via the shared helper (single
# source of truth for parsing + branch-vs-INDEX messaging — the test
# harness exercises the same script, so drift can't hide behind
# copy-pasted shell here).
bash .sdd/scripts/status-banner.sh --from-resolver
# Re-parse the resolver output once for the spec-details section
# below. Cheap (filesystem + git rev-parse) and keeps /status simple.
resolve_json=$(bash .sdd/scripts/resolve-active.sh 2>/dev/null || echo '{}')
active=$(echo "$resolve_json" | python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except: d = {}
print(d.get("active") or "")
' 2>/dev/null)
if [ -n "$active" ] && [ -f ".sdd/$active/spec.md" ]; then
  spec=".sdd/$active/spec.md"
  echo "Active spec: $spec"
  echo ""
  phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" | grep -oE '[A-Z]+' | tail -1)
  echo "Phase: $phase"
  echo ""
  echo "Open blockers (first 10):"
  awk -v ph="## PHASE: $phase" '
    $0 ~ ph {found=1}
    found && /^## PHASE:/ && $0 !~ ph {exit}
    found {print}
  ' "$spec" | grep -n -E '\[ \]' | head -10 || echo "  (none — ready to advance phase)"
  echo ""
  echo "---"
  echo "Active step + resolved parameters (F5 cascade):"
  bash .sdd/scripts/next-action.sh "$spec" 2>/dev/null | python3 -c "$(cat <<'PYEOF'
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    print("  (next-action.sh returned non-JSON; framework may need attention)")
    sys.exit(0)
if d.get("transition"):
    print(f"  Phase {d['phase']} has no open step rows — transition signal: {d['transition']}.")
    print("  Run /next to advance the phase.")
elif not d.get("step"):
    print("  No active step (legacy spec or empty phase). Run /next to start.")
else:
    print(f"  action: {d.get('action')}")
    print(f"  step:   {d.get('step')}    tag: {d.get('tag')}")
    if d.get("prompt"):
        print(f"  prompt: {d['prompt']}")
    print()
    params = d.get("parameters") or {}
    prov = params.pop("_provenance", {}) if isinstance(params, dict) else {}
    if not params:
        print("  (no parameters resolved this turn — common when there's no active step or playbook context yet)")
    else:
        print("  Resolved parameters (cascade source in brackets):")
        def walk(prefix, val):
            if isinstance(val, dict):
                for k, v in sorted(val.items()):
                    walk(f"{prefix}.{k}" if prefix else k, v)
            else:
                source = prov.get(prefix, "?")
                print(f"    {prefix} = {val!r}  [{source}]")
        walk("", params)
PYEOF
)"
fi
```

Then give a one-line summary to the user. Match what the Python block actually printed:

Pick the summary that matches what the banner actually printed. Each maps a banner subcase to a one-line CTA so the user knows the next move:

- **Ambiguous branch slug** (banner: `Active source: NONE — branch '<x>' slug matched 2+`): *"Your branch slug matches two folders under `.sdd/` — rename one of them so the slug is unique, then run `/status` again."* Don't suggest `/start`; the user already has work items, just collide-named ones.
- **Broken INDEX pointer** (banner: `Active source: NONE — INDEX.md **Active:** points at`): *"INDEX.md's `**Active:**` line points at a folder that doesn't exist. Edit it to point at a real folder, or check out an SDD-style branch (`sdd/<id>-<slug>`) whose folder exists."* Don't suggest `/start` — there's already an INDEX entry, just stale.
- **Scaffold-pending SDD branch** (banner: `Active source: NONE — current branch '<x>' is SDD-shaped`): *"You're on `<branch>` but the work-item folder isn't scaffolded yet. Run `/start <one-line title>` to scaffold it."*
- **Non-SDD branch** (banner: `Active source: NONE — current branch '<x>' isn't an SDD-shape`): *"You're on a non-SDD branch and no INDEX entry. Run `/start <one-line title>` to scaffold a new feature, or check out a branch like `sdd/001-foo`."*
- **Active step present** (action + step both populated): *"You're on `<work-item>`, phase `<phase>`, on action `<action>`/step `<step>`. Run `/next` to advance one step."*
- **Transition signal** (Python printed "transition signal"): *"You're on `<work-item>`, phase `<phase>` — all step rows in this phase are filled. Run `/next` to advance to the next phase."*
- **No active step / legacy spec** (Python printed "No active step"): *"You're on `<work-item>`, phase `<phase>` — no atomic step rows yet. Run `/next` to start the first one."*
- **No active work item** (banner: `Active source: NONE — no active work item.`): *"No active work item. Run `/start <one-line title>` to scaffold a new one."*

If `parameters` was empty or null, mention it briefly: *"(parameters cascade not resolved — INDEX.md `**Playbook:**` line missing? Check with `cat .sdd/INDEX.md`.)"*
