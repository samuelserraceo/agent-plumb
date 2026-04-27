#!/usr/bin/env bash
# init-throwaway.sh — Scaffold a throwaway test project for SDD lean Phase A.
#
# Creates a fresh sandbox with the framework templates copied in and an
# active feature (001-landing-page-waitlist) seeded from the fixture
# at templates/.sdd/features/_throwaway-fixture.md. Then prints the
# exact prompt to paste into Claude Code to start driving.
#
# Usage:
#   bash test/init-throwaway.sh                   # default: ~/sdd-throwaway
#   bash test/init-throwaway.sh ~/my-sandbox-dir  # custom path

set -euo pipefail

TARGET="${1:-$HOME/sdd-throwaway}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK="${SDD_FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FIXTURE="$FRAMEWORK/test/_throwaway-fixture.md"

if [ ! -d "$FRAMEWORK/templates" ] || [ ! -f "$FIXTURE" ]; then
  echo "ERROR: framework templates/ or fixture not found at $FRAMEWORK" >&2
  exit 1
fi

if [ -e "$TARGET" ]; then
  echo "ERROR: $TARGET already exists. Remove it first or pick a new path." >&2
  exit 1
fi

echo "Creating throwaway sandbox at: $TARGET"
mkdir -p "$TARGET"
cd "$TARGET"
git init -q
cp -R "$FRAMEWORK/templates/." .

FEAT_SLUG="001-landing-page-waitlist"
FEAT="features/$FEAT_SLUG"
mkdir -p ".sdd/$FEAT"
cp "$FIXTURE" ".sdd/$FEAT/spec.md"

cat > .sdd/INDEX.md <<INDEX
# SDD INDEX

**Active:** $FEAT

## Active

- $FEAT — landing-page-waitlist (PHASE: SPEC)

## Shipped
INDEX

git add .sdd/ .claude/ CLAUDE.md 2>/dev/null || git add -A
git -c user.email="test@sdd.local" -c user.name="SDD Test" \
    commit -q -m "[SDD:001] init: scaffold landing-page-waitlist feature"

cat <<EOF

╔══════════════════════════════════════════════════════════════════╗
║  ✓ Throwaway sandbox ready                                       ║
╚══════════════════════════════════════════════════════════════════╝

  Location:  $TARGET
  Feature:   $FEAT
  Phase:     SPEC

──────────────────────────────────────────────────────────────────────
NEXT — paste into your terminal:
──────────────────────────────────────────────────────────────────────

  cd $TARGET
  claude

──────────────────────────────────────────────────────────────────────
THEN paste this opening prompt into Claude Code:
──────────────────────────────────────────────────────────────────────

I'm stress-testing SDD lean Phase A on a throwaway project. Active
feature: $FEAT_SLUG (a personal landing page with email waitlist).

You are the SDD agent. Drive this feature through the spine. The
playbook lives at .sdd/playbooks/feature.md, with each sub-action's
prose at .sdd/actions/<slug>.md.

For each turn:
1. Run \`bash .sdd/scripts/next-action.sh .sdd/$FEAT/spec.md\` and read the JSON.
2. Read the playbook section corresponding to that sub-action.
3. Walk me through the sub-action following the playbook's prose
   (USER-LED → ask, AGENT-LED → propose with alternatives).
4. Update spec.md (replace the [ ] with the agreed answer).
5. Commit with [SDD:001] <phase>: <slug>.

At a phase transition:
- Run \`bash .sdd/scripts/verify-stage.sh .sdd/$FEAT/spec.md <PHASE>\`.
- Stage spec.md + the produced verification.json together.
- Commit \`[SDD:001] phase: <FROM> → <TO>\`. The moat hook re-runs
  verify-stage on the staged spec and refuses to commit if the claimed
  verification.json doesn't match a fresh re-run.

Translation rule: never ask me to judge technical decisions in raw
jargon. Frame in plain English with what-it-does-for-the-user.

Begin: run next-action.sh and walk me through §1 Problem.

──────────────────────────────────────────────────────────────────────
EOF
