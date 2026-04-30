---
description: Print the current SDD workflow state — phase, open blockers, and resolved parameters for the active step.
---

Show the user the current workflow state. Run these Bash commands and present the output cleanly:

```bash
cat .sdd/INDEX.md
echo ""
echo "---"
# Resolve the active work item via resolve-active.sh (branch-aware,
# falls back to INDEX.md **Active:** when not on an SDD branch).
resolve_json=$(bash .sdd/scripts/resolve-active.sh 2>/dev/null || echo '{}')
active=$(echo "$resolve_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("active") or "")' 2>/dev/null)
source=$(echo "$resolve_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("source") or "")' 2>/dev/null)
branch=$(echo "$resolve_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("branch") or "")' 2>/dev/null)
index_active=$(echo "$resolve_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("index_active") or "")' 2>/dev/null)
# Branch-aware status banner — explains where the active value came
# from + flags drift between branch and INDEX.md so the user sees
# what's going on across multiple worktrees.
if [ "$source" = "branch" ]; then
  echo "Active source: branch ($branch) → $active"
  if [ -n "$index_active" ] && [ "$index_active" != "$active" ]; then
    echo "  Note: INDEX.md **Active:** points at $index_active — drift is OK in"
    echo "        multi-worktree work. The branch wins. Switch branches to"
    echo "        switch features, no manual INDEX.md edit needed."
  fi
elif [ "$source" = "index" ]; then
  if [ -n "$branch" ]; then
    echo "Active source: INDEX.md (branch '$branch' is not an SDD branch) → $active"
  else
    echo "Active source: INDEX.md → $active"
  fi
fi
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

- **Active step present** (action + step both populated): *"You're on `<work-item>`, phase `<phase>`, on action `<action>`/step `<step>`. Run `/next` to advance one step."*
- **Transition signal** (Python printed "transition signal"): *"You're on `<work-item>`, phase `<phase>` — all step rows in this phase are filled. Run `/next` to advance to the next phase."*
- **No active step / legacy spec** (Python printed "No active step"): *"You're on `<work-item>`, phase `<phase>` — no atomic step rows yet. Run `/next` to start the first one."*
- **No active work item** (the `active=""` branch above): *"No active work item. Run `/start <one-line title>` to scaffold a new one."*

If `parameters` was empty or null, mention it briefly: *"(parameters cascade not resolved — INDEX.md `**Playbook:**` line missing? Check with `cat .sdd/INDEX.md`.)"*
