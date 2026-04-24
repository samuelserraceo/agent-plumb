---
description: Print the current SDD workflow state to the terminal.
---

Show the user the current workflow state. Run these Bash commands and present the output cleanly:

```bash
cat .sdd/INDEX.md
echo ""
echo "---"
# Active feature's spec summary
active=$(grep -m1 -E '^\*\*Active:\*\*' .sdd/INDEX.md | grep -oE 'features/[A-Za-z0-9._-]+' | head -1 || echo "")
if [ -n "$active" ] && [ -f ".sdd/$active/spec.md" ]; then
  echo "Active spec: .sdd/$active/spec.md"
  echo ""
  # Header + current phase section
  spec=".sdd/$active/spec.md"
  phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" | grep -oE '[A-Z]+' | tail -1)
  echo "Phase: $phase"
  echo ""
  echo "Open blockers (first 10):"
  awk -v ph="## PHASE: $phase" '
    $0 ~ ph {found=1}
    found && /^## PHASE:/ && $0 !~ ph {exit}
    found {print}
  ' "$spec" | grep -n -E '\[ \]' | head -10 || echo "  (none — ready to advance phase)"
fi
```

Then give a one-line summary to the user: "You're on `<feature>`, phase `<phase>`, with `<N>` open blockers. Run `/next` to address the first one."
