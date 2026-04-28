---
description: Print the current SDD workflow state — phase, open blockers, and resolved parameters for the active step.
---

Show the user the current workflow state. Run these Bash commands and present the output cleanly:

```bash
cat .sdd/INDEX.md
echo ""
echo "---"
# Active work item's spec summary
active=$(awk '/^\*\*Active:\*\*/{print $2; exit}' .sdd/INDEX.md 2>/dev/null || echo "")
echo "$active" | grep -qE '^[a-z][a-z0-9_-]*/[A-Za-z0-9._-]+$' || active=""
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
        print("  (no parameters resolved — INDEX.md or resolver may be missing)")
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

Then give a one-line summary to the user: *"You're on `<work-item>`, phase `<phase>`, on action `<action>`/step `<step>`. Run `/next` to advance one step."*

If `parameters` was empty or null, mention it briefly: *"(parameters cascade not resolved — INDEX.md `**Playbook:**` line missing? Check with `cat .sdd/INDEX.md`.)"*
