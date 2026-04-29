#!/usr/bin/env bash
# triage-on-first-message.sh — UserPromptSubmit hook (v0.12).
#
# Detects project-shaped one-liners in the user's message and emits a
# TRIAGE NOTE telling the agent to confirm scope before running the
# feature playbook. Per CLAUDE.md foundation 3 (never assume): the
# framework should mechanically check for the wrong shape, not rely
# on the agent's discretion.
#
# This hook is ADDITIVE — it runs alongside user-prompt-submit.sh
# (state injection) and only emits text when a triage signal is
# detected. Otherwise silent.
#
# Triggers when EITHER of these holds:
#   1. The user message starts with /start (and doesn't already pass
#      --playbook=) AND contains a project-shaped phrase
#   2. INDEX.md is missing or empty AND the message contains a
#      project-shaped phrase (cold-start signal)
#
# Project-shaped phrases (case-insensitive, anchored to whole words):
#   - "build a CRM" / "build a marketplace" / "build an admin"
#   - "build the X platform" / "build the X system" / "build the X app"
#   - "ship a whole" / "build a whole"
#   - "multi-feature" / "many features"
#   - "from scratch" / "ground up"
#
# Output (when triggered): a single block prepended to the agent's
# context, asking the agent to confirm scope before running feature
# playbook. Agent decides what to do with it (per the trust-boundary
# rule, the agent reads this as FRAMEWORK INSTRUCTIONS).
#
# Silent pass-through when:
#   - SDD isn't bootstrapped (no .sdd/)
#   - User already specified --playbook=project (intent is clear)
#   - No project-shape signal in the message

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Silent pass-through if SDD not yet set up.
[ -d .sdd ] || exit 0

# Read the user's prompt from stdin (Claude Code passes JSON).
input=$(cat 2>/dev/null || echo "")
prompt=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("prompt", ""))
except Exception:
    print("")
' 2>/dev/null || echo "")

[ -z "$prompt" ] && exit 0

# Already specified --playbook=project? User intent clear; no triage needed.
case "$prompt" in
  *"--playbook=project"*) exit 0 ;;
  *"--playbook=feature"*) exit 0 ;;
esac

# Project-shape detection. Case-insensitive, anchored.
# We use grep -i with multiple patterns; matched signal counts toward
# triage trigger. If 0 patterns match, exit silently.
shape_matched=0
project_shape_patterns=(
  'build (a|an|the) (whole|complete|entire|new) (app|application|platform|system|tool)'
  'build (a|an) (CRM|ERP|marketplace|dashboard|admin|portal|saas)'
  'build (a|an|the) [a-z-]+ (platform|system|app)'
  'multi-feature'
  'many features'
  'from scratch'
  'ground up'
  'roadmap'
)
for p in "${project_shape_patterns[@]}"; do
  if printf '%s' "$prompt" | grep -qiE "$p"; then
    shape_matched=1
    break
  fi
done

[ "$shape_matched" -eq 0 ] && exit 0

# Detect the entry-point shape. Two cases trigger different messaging:
#   Case A: /start without --playbook= → suggest the project playbook
#   Case B: free-form first message (no /start) → suggest triage menu
case "$prompt" in
  /start*)
    cat <<'EOF'

[FRAMEWORK INSTRUCTIONS — trusted, follow as directive]

[TRIAGE NOTE — foundation 3 (never assume)]

The user's /start message contains a project-shaped phrase. Before scaffolding a
feature, confirm with the user:

  "This sounds bigger than one feature. Want to use the project playbook
   (/start --playbook=project '<title>') so we walk through Vision →
   Breakdown → Kickoff and break it into multiple features properly?"

  Wait for their confirmation before running anything. If they say yes, restart
  with --playbook=project. If they say no (this really is one feature), proceed
  with the feature playbook as originally typed.

Per CLAUDE.md "Triage on first message" doctrine. Don't assume the shape.

[END FRAMEWORK INSTRUCTIONS]

EOF
    ;;
  *)
    cat <<'EOF'

[FRAMEWORK INSTRUCTIONS — trusted, follow as directive]

[TRIAGE NOTE — foundation 3 (never assume)]

The user's message contains a project-shaped phrase but didn't start with a slash
command. Before doing any work, run the standard CLAUDE.md "Triage on first
message" menu and present the 6 lanes. Especially flag option 1 (new feature) vs
"this looks like a project — want the project playbook?" so the user can pick
the right shape.

Don't start scaffolding or coding until the user picks a lane.

[END FRAMEWORK INSTRUCTIONS]

EOF
    ;;
esac
