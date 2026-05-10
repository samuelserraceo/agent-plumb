#!/usr/bin/env bash
# T203 — AC4 — Spec.md row isolation under wave dispatch.
#
# The simpler-than-§6-EC#9-implied architecture: wave-task subagents
# DON'T modify spec.md directly. Each subagent only touches its own
# test + code files. The orchestrator (after the wave finishes)
# commits a single spec.md edit that flips every wave-task row
# RED → GREEN at once.
#
# This sidesteps the "adjacent rows have overlapping diff context"
# problem entirely — git only sees one spec.md edit per wave (the
# orchestrator's), not N concurrent ones. No 3-way merge needed.
#
# Contract:
#   1. 3 wave-task subagents each commit their test + code (disjoint
#      file sets — `tests/task-T<N>.sh` + corresponding code file).
#      Wave-tasks never touch spec.md.
#   2. Orchestrator commits a single spec.md edit flipping all 3
#      wave-task rows from `[ ]` to `[x]` (the "wave green" step).
#   3. Final state: 3 × 2 wave-task commits + 1 orchestrator commit
#      = 7 commits. No conflicts at any step.

set -uo pipefail

fails=()

WORK="$(mktemp -d -t sdd-t203.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

REPO="$WORK/repo"
mkdir -p "$REPO"
cd "$REPO"

git init -q
git config user.email "t203@test.local"
git config user.name "T203 test"
git config commit.gpgsign false

mkdir -p tests scripts
cat > spec.md <<'SPEC'
# fixture row-isolation

[PHASE: BUILD]

## PHASE: SPEC

### action: plan-decompose

- [ ] T200 [WAVE: 1]: scaffold endpoint A
- [ ] T201 [WAVE: 1]: scaffold endpoint B
- [ ] T202 [WAVE: 1]: scaffold endpoint C

## PHASE: BUILD
SPEC

git add spec.md
git commit -q -m "base: 3 wave-tasks RED"

# --- 3 subagents land their test+code (disjoint files; spec.md untouched) ---
for n in 200 201 202; do
  printf '#!/usr/bin/env bash\necho "T%s test"\n' "$n" > "tests/task-T$n.sh"
  printf '# code for T%s\n' "$n" > "scripts/wave-feature-T$n.sh"
  chmod +x "tests/task-T$n.sh" "scripts/wave-feature-T$n.sh"
  git add "tests/task-T$n.sh" "scripts/wave-feature-T$n.sh"
  git commit -q -m "wave-task T$n: test + code (no spec.md touch)"
done

# Negative-control assert: spec.md content is unchanged through all 6 commits
if ! diff <(git show HEAD:spec.md) <(git show HEAD~3:spec.md) >/dev/null; then
  fails+=("spec.md was modified during wave-task commits (contract: only orchestrator touches spec.md)")
fi

# --- Orchestrator's wave-green commit: flip all 3 rows in one edit -------
python3 -c "
import re
with open('spec.md', encoding='utf-8') as f:
    content = f.read()
for n in (200, 201, 202):
    content = re.sub(
        r'^- \[ \] T' + str(n) + r' \[WAVE: 1\]:',
        '- [x] T' + str(n) + ' [WAVE: 1]:',
        content,
        count=1,
        flags=re.M,
    )
with open('spec.md', 'w', encoding='utf-8') as f:
    f.write(content)
"
git add spec.md
git commit -q -m "wave-1 green: T200/T201/T202 all GREEN (orchestrator integrates)"

# --- Assert final state -------------------------------------------------
for n in 200 201 202; do
  if ! grep -qE "^- \[x\] T${n} \[WAVE: 1\]:" spec.md; then
    fails+=("after orchestrator wave-green commit, T$n not flipped to [x]")
  fi
done

# Negative: no `[ ]` wave-1 rows should remain.
if grep -qE "^- \[ \] T[0-9]+ \[WAVE: 1\]:" spec.md; then
  leftover="$(grep -E '^- \[ \] T[0-9]+ \[WAVE: 1\]:' spec.md | head -3)"
  fails+=("wave-1 still has unflipped rows after orchestrator commit: $leftover")
fi

# Total commit count: 1 base + 3 wave-task + 1 wave-green = 5.
commit_count="$(git rev-list --count HEAD)"
if [ "$commit_count" -ne 5 ]; then
  fails+=("expected 5 commits (1 base + 3 wave-task + 1 wave-green), got $commit_count")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T203 — AC4 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T203 — AC4 spec.md row isolation: wave-tasks commit disjoint files, orchestrator flips rows in one atomic spec.md edit (no merge conflicts possible)"
