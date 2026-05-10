#!/usr/bin/env bash
# v1.6 anchor integration smoke — verifies all 10 ACs from F009 §11
# Run: bash tests/integration/v1.6-anchor.smoke.sh
set -euo pipefail
cd "$( dirname "${BASH_SOURCE[0]}" )/../.."

echo "=== F009 v1.6-anchor integration smoke ==="
fails=0

run() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label"
    fails=$((fails+1))
  fi
}

# AC1 — brief-intake action exists with the prompt
run "AC1: brief-intake action prose exists"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-001.sh

# AC2 — brief-summarise skeleton exists
run "AC2: brief-summarise skeleton exists"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-002.sh

# AC3 — brief-intake names pre-fill targets
run "AC3: brief-intake pre-fill targets named"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-003.sh

# AC4 — feature.md adds brief-intake before problem
run "AC4: feature.md actions list correct"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-004.sh

# AC5 — success deprecated
run "AC5: success removed from playbook + deprecated:true"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-005.sh

# AC6 — F010+ scaffold has no §2
run "AC6: F010+ scaffold smoke"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-006.sh

# AC7 — CLAUDE.md doctrine
run "AC7: CLAUDE.md one-question-per-turn doctrine"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-007.sh

# AC8 — wireframe + edge-case-sweep frontmatter
run "AC8: wireframe + edge-case-sweep requires_user_approval: false"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-008.sh

# AC9 — proposed-approach <details> foldable
run "AC9: plain-English-first <details> foldable"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-009.sh

# AC10 — data-contract upload prose
run "AC10: data-contract upload-invitation prose"  bash .sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/tests/task-010.sh

echo ""
echo "=== Results ==="
total=10
passed=$((total - fails))
echo "$passed/$total ACs passing"
[ "$fails" -eq 0 ] || exit 1
echo "v1.6 anchor integration smoke: ALL GREEN"
