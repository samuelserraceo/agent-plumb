#!/usr/bin/env bash
# run-framework-test.sh — SDD lean Phase A integration test.
#
# 8 real-behavior assertions. Each test header documents the bug class
# it catches (RED case). Empty / not-yet-implemented stubs MUST fail
# every test. A test that passes against nothing is shallow — rewrite it.

set -uo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NEXT_ACTION="$FRAMEWORK_ROOT/templates/.sdd/scripts/next-action.sh"
VERIFY_STAGE="$FRAMEWORK_ROOT/templates/.sdd/scripts/verify-stage.sh"
MOAT_HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-stage-verified.sh"
LOAD_PLAYBOOK="$FRAMEWORK_ROOT/templates/.sdd/scripts/load-playbook.sh"
COFILE_BLOCK="$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-cofile-block.sh"
FIXTURES_V08="$FRAMEWORK_ROOT/test/fixtures/v08-schema"

PASS=0
FAIL=0
declare -a FAILURES=()

note() { printf '\n— %s\n' "$1"; }
ok()   { printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  ❌ %s\n     %s\n' "$1" "$2"; FAIL=$((FAIL+1)); FAILURES+=("$1: $2"); }

# Make a fresh tmp project; print path. Caller cleans up.
# Includes a baseline git init + scaffold commit so subsequent `git add -A`
# in tests doesn't pull verify-stage.sh into the staged set (which would
# false-trigger the moat's co-stage block on every test).
mkproj() {
  local d
  d=$(mktemp -d)
  mkdir -p "$d/.sdd/features/001-test" "$d/.sdd/scripts"
  cp "$VERIFY_STAGE" "$d/.sdd/scripts/verify-stage.sh" 2>/dev/null || true
  cp "$NEXT_ACTION"  "$d/.sdd/scripts/next-action.sh"  2>/dev/null || true
  ( cd "$d" \
    && git init -q 2>/dev/null \
    && git config user.email t@t.com \
    && git config user.name T \
    && git add .sdd/scripts/ \
    && git commit -q -m "scaffold" >/dev/null 2>&1 ) || true
  echo "$d"
}

# v0.8 scaffold: copies the framework's actual playbooks/, subactions/, config.md
# templates so each loader test starts from a "real valid project." Tests then
# OVERLAY a fixture file to introduce one specific failure mode.
# Used by T27-T30 (loader validation tests) and T31-T35 (hook tests).
mkproj_v08() {
  local d
  d=$(mktemp -d)
  mkdir -p "$d/.sdd/playbooks" "$d/.sdd/subactions" "$d/.sdd/scripts" \
           "$d/.sdd/.cache" "$d/.sdd/features/001-test"
  cp "$FRAMEWORK_ROOT/templates/.sdd/config.md"          "$d/.sdd/config.md"
  cp "$FRAMEWORK_ROOT/templates/.sdd/playbooks/feature.md" "$d/.sdd/playbooks/feature.md"
  cp "$FRAMEWORK_ROOT/templates/.sdd/subactions/problem.md"           "$d/.sdd/subactions/problem.md"
  cp "$FRAMEWORK_ROOT/templates/.sdd/subactions/proposed-approach.md" "$d/.sdd/subactions/proposed-approach.md"
  cp "$FRAMEWORK_ROOT/templates/.sdd/subactions/build-task.md"        "$d/.sdd/subactions/build-task.md"
  cp "$FRAMEWORK_ROOT/templates/.sdd/.cache/manifest.json"            "$d/.sdd/.cache/manifest.json"
  cp "$FRAMEWORK_ROOT/templates/.sdd/scripts/load-playbook.sh"        "$d/.sdd/scripts/load-playbook.sh"
  cp "$VERIFY_STAGE" "$d/.sdd/scripts/verify-stage.sh" 2>/dev/null || true
  cp "$NEXT_ACTION"  "$d/.sdd/scripts/next-action.sh"  2>/dev/null || true
  ( cd "$d" \
    && git init -q 2>/dev/null \
    && git config user.email t@t.com \
    && git config user.name T \
    && git add .sdd/ \
    && git commit -q -m "scaffold" >/dev/null 2>&1 ) || true
  echo "$d"
}

# ============================================================
# T1 — next-action.sh deterministic across 5 invocations
#   RED: implementation uses $RANDOM, hash-set iteration without sort,
#        date timestamps, or any nondeterministic ordering.
# ============================================================
note "T1: next-action.sh deterministic across 5 invocations"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'EOF'
[PHASE: SPEC]

## PHASE: SPEC
[ ] §1 Problem
[ ] §2 Success metrics
EOF
o1=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>/dev/null); e1=$?
o2=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>/dev/null); e2=$?
o3=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>/dev/null); e3=$?
o4=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>/dev/null); e4=$?
o5=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>/dev/null); e5=$?
rm -rf "$d"
all_ok=1
for e in $e1 $e2 $e3 $e4 $e5; do [ "$e" -eq 0 ] || all_ok=0; done
if [ $all_ok -eq 1 ] && [ -n "$o1" ] && [ "$o1" = "$o2" ] && [ "$o2" = "$o3" ] && [ "$o3" = "$o4" ] && [ "$o4" = "$o5" ]; then
  ok "T1 5 invocations yield identical non-empty output (all exit 0)"
else
  bad "T1 nondeterministic, empty, or errored" "exits=[$e1 $e2 $e3 $e4 $e5]; out1='$o1'; out5='$o5'"
fi

# ============================================================
# T2 — first [ ] resolves to §1 Problem
#   RED: returns wrong section, returns empty, hardcodes a different
#        sub-action name.
# ============================================================
note "T2: first [ ] resolves to §1 Problem"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'EOF'
[PHASE: SPEC]

## PHASE: SPEC
[ ] §1 Problem
[ ] §2 Success metrics
EOF
out=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>&1 || true)
rm -rf "$d"
if echo "$out" | grep -q '§1 Problem'; then
  ok "T2 returns §1 Problem"
else
  bad "T2 wrong sub-action" "expected '§1 Problem' in output, got: $out"
fi

# ============================================================
# T3 — advances after [ ] → [x]
#   RED: implementation returns the same sub-action even after the [ ]
#        becomes [x]; e.g. iterates with the wrong predicate.
# ============================================================
note "T3: advances after [ ] → [x]"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'EOF'
[PHASE: SPEC]

## PHASE: SPEC
[x] §1 Problem
[ ] §2 Success metrics
EOF
out=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>&1 || true)
rm -rf "$d"
if echo "$out" | grep -q '§2 Success metrics'; then
  ok "T3 advances to §2 after §1 filled"
else
  bad "T3 stuck on §1" "expected '§2 Success metrics' in output, got: $out"
fi

# ============================================================
# T4 — TRANSITION when all [ ] in active phase filled
#   RED: returns the last sub-action (or empty) instead of signaling
#        a phase transition. Or counts [ ] from OTHER phases as open.
# ============================================================
note "T4: TRANSITION when all [ ] in active phase filled"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'EOF'
[PHASE: SPEC]

## PHASE: SPEC
[x] §1 Problem
[x] §2 Success metrics

## PHASE: PLAN
[ ] task list
EOF
out=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>&1 || true)
rm -rf "$d"
# REWRITE per honesty reviewer: previous grep matched the JSON KEY "transition":
# which is always emitted, so a mutant that returned the last [ ] line still
# passed. Now require: transition is a non-null "X→Y" string OR sub_action is
# null — AND output must NOT contain a "sub_action":"[..." (a checklist line).
if echo "$out" | grep -Eq '"sub_action"[[:space:]]*:[[:space:]]*"\['; then
  bad "T4 returned a checklist line instead of transitioning" "got: $out"
elif echo "$out" | grep -Eq '"transition"[[:space:]]*:[[:space:]]*"[A-Z]+→[A-Z]+"' \
     || echo "$out" | grep -Eq '"sub_action"[[:space:]]*:[[:space:]]*null'; then
  ok "T4 emits real transition signal (non-null transition or null sub_action)"
else
  bad "T4 no transition signal" "expected SPEC→PLAN or null sub_action; got: $out"
fi

# ============================================================
# T5 — does NOT count [ ] inside fenced code blocks
#   RED: greps `\[ \]` across the whole spec without tracking ``` fences.
#        Failure mode F3.
# ============================================================
note "T5: ignores [ ] inside fenced code blocks"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'SPEC'
[PHASE: SPEC]

## PHASE: SPEC
[x] §1 Problem
[x] §2 Success metrics

```
example checklist in a code block:
[ ] this should NOT be counted as an open blocker
[ ] neither should this
```

## PHASE: PLAN
[ ] task list
SPEC
out=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>&1 || true)
rm -rf "$d"
# REWRITE per honesty reviewer: the strongest signal that fence-tracking is
# broken is the script returning the in-fence sentinel string. Add an explicit
# anti-pattern check on the unique sentinel ("this should NOT be counted")
# before checking the positive case (real transition or null sub_action).
if echo "$out" | grep -q 'this should NOT be counted'; then
  bad "T5 counted in-fence [ ]" "fence-tracking missing; returned in-fence line: $out"
elif echo "$out" | grep -Eq '"transition"[[:space:]]*:[[:space:]]*"[A-Z]+→[A-Z]+"' \
     || echo "$out" | grep -Eq '"sub_action"[[:space:]]*:[[:space:]]*null'; then
  ok "T5 ignores in-fence [ ] markers (transitioned past empty SPEC body)"
else
  bad "T5 unexpected output" "expected transition/null sub_action; got: $out"
fi

# ============================================================
# T6 — verify-stage.sh scopes exit checks to the named PHASE section
#   RED: a stray `[ ] T9` in PHASE: SHIP would mistakenly count toward
#        BUILD's "no open tasks" check. Implementation greps the whole
#        spec instead of the active section's body.
#        Failure mode F26.
# ============================================================
note "T6: verify-stage scopes checks to active PHASE section (F26)"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'SPEC'
[PHASE: BUILD]

## PHASE: BUILD
[GREEN] T1 component
[GREEN] T2 api

### Exit checks
- [ ] C1: no open tasks in BUILD — ! grep -q '\[ \] T' "$SECTION_FILE"

## PHASE: SHIP
[ ] T9 stray task in wrong phase (must NOT count toward BUILD's C1)
SPEC
bash "$VERIFY_STAGE" "$d/.sdd/features/001-test/spec.md" BUILD >/dev/null 2>&1 || true
vfile="$d/.sdd/features/001-test/verification.json"
if [ -f "$vfile" ] && grep -Eq '"id"[[:space:]]*:[[:space:]]*"C1"[^{}]*"result"[[:space:]]*:[[:space:]]*"pass"' "$vfile" 2>/dev/null; then
  ok "T6 BUILD's C1 passes despite stray [ ] in SHIP"
else
  if [ -f "$vfile" ]; then
    bad "T6 cross-section bleed" "C1 should pass when scoped to BUILD; got: $(cat "$vfile" 2>&1)"
  else
    bad "T6 no verification.json" "verify-stage.sh did not produce $vfile"
  fi
fi
rm -rf "$d"

# ============================================================
# T7 — verify-stage.sh deterministic across 2 invocations on same spec
#   RED: implementation embeds timestamps, $RANDOM, or non-stable
#        ordering of checks in verification.json output.
#        Empty stub: produces no file, fails the precondition → RED.
# ============================================================
note "T7: verify-stage deterministic across 2 invocations"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'SPEC'
[PHASE: BUILD]

## PHASE: BUILD
[GREEN] T1 done
[GREEN] T2 done

### Exit checks
- [ ] C1: at least one task — grep -q '\[GREEN\] T' "$SECTION_FILE"
- [ ] C2: phase header present — grep -q '## PHASE: BUILD' "$SECTION_FILE"
SPEC
spec="$d/.sdd/features/001-test/spec.md"
bash "$VERIFY_STAGE" "$spec" BUILD >/dev/null 2>&1 || true
vfile="$d/.sdd/features/001-test/verification.json"
if [ ! -f "$vfile" ]; then
  bad "T7 setup precondition" "verify-stage produced no verification.json (cannot test determinism)"
else
  v1=$(cat "$vfile")
  bash "$VERIFY_STAGE" "$spec" BUILD >/dev/null 2>&1 || true
  v2=$(cat "$vfile")
  if [ "$v1" = "$v2" ]; then
    ok "T7 verification.json is byte-identical across 2 runs"
  else
    bad "T7 nondeterministic verify-stage" "two runs differ — likely timestamp or unstable ordering"
  fi
fi
rm -rf "$d"

# ============================================================
# T8 — THE MOAT — count-mismatch fabrication blocked
#   RED: hook only checks pass-count rough proxy; or fails open on parse
#        errors; or doesn't fire at all on legitimate `git commit`.
#        Catastrophic-fix #4 is also exercised here (cmd parsed correctly
#        from stdin JSON or hook would exit 0 silently).
# ============================================================
note "T8: moat blocks count-mismatch fabrication"
d=$(mkproj)
cd "$d"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
mkdir -p .sdd/features/001-test
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: BUILD]

## PHASE: BUILD
[GREEN] T1 done

### Exit checks
- [ ] C1: t1 done — grep -q 'T1' "$SECTION_FILE"
- [ ] C2: build label present — grep -q '## PHASE: BUILD' "$SECTION_FILE"
SPEC
echo '**Active:** features/001-test' > .sdd/INDEX.md

# Run verify-stage honestly first → produces 2 honest pass entries.
bash "$VERIFY_STAGE" .sdd/features/001-test/spec.md BUILD >/dev/null 2>&1 || true

# FABRICATE: replace verification.json with one claiming 3 passes.
cat > .sdd/features/001-test/verification.json <<'JSON'
{
  "phase": "BUILD",
  "checks": [
    {"id": "C1", "result": "pass"},
    {"id": "C2", "result": "pass"},
    {"id": "C3", "result": "pass"}
  ]
}
JSON
git add -A

# Simulate the hook's stdin (Claude Code PreToolUse Bash payload).
hook_stdin='{"tool_input":{"command":"git commit -m phase: BUILD->VERIFY"}}'
exit_code=0
echo "$hook_stdin" | bash "$MOAT_HOOK" >/dev/null 2>&1 || exit_code=$?
cd - >/dev/null
rm -rf "$d"
if [ "$exit_code" -eq 2 ]; then
  ok "T8 moat blocked fabrication (exit 2)"
else
  bad "T8 moat let fabrication through" "expected exit 2 (block); got $exit_code"
fi

# ============================================================
# T9 — next-action.sh skips work-item placeholders ([ ] AC<N>, [ ] T<N>, [ ] C-...)
#   RED: implementation treats `[ ] AC1: ...` as a rubric blocker and gets
#        stuck returning it on every /next. Caught during throwaway end-to-end
#        stress-test at the §11 boundary; was not covered by T1-T8.
#   The `[ ]` marker is overloaded:
#     - rubric question (`- **Who has it:** [ ]`) — TRUE blocker
#     - work-item placeholder (`- [ ] AC1: ...`, `- [ ] T1 ...`) — NOT a SPEC
#       blocker; turned [GREEN] in BUILD
#     - exit-check (`- [ ] C-spec-acs: ...`) — verified by verify-stage.sh,
#       never hand-filled
# ============================================================
note "T9: next-action skips AC/T/C- work-item placeholders"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'SPEC'
[PHASE: SPEC]

## PHASE: SPEC

### §1 Problem
- **Who has it:** filled

### §11 Acceptance criteria
- [ ] AC1: GET / returns 200
- [ ] AC2: form has email input

### Exit checks
- [ ] C-spec-acs: §11 has ≥1 acceptance criterion — grep -q '\[ \] AC' "$SECTION_FILE"

## PHASE: PLAN
[ ] task list
SPEC
out=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>&1 || true)
rm -rf "$d"
# All real rubric blockers are filled (only [ ] AC and [ ] C- remain in SPEC).
# Should emit transition, not return AC1 / AC2 / C-spec-acs.
if echo "$out" | grep -qE 'AC1|AC2|C-spec-acs'; then
  bad "T9 returned a work-item placeholder" "expected transition; got: $out"
elif echo "$out" | grep -Eq '"transition"[[:space:]]*:[[:space:]]*"[A-Z]+→[A-Z]+"' \
     || echo "$out" | grep -Eq '"sub_action"[[:space:]]*:[[:space:]]*null'; then
  ok "T9 skips AC/T/C- placeholders, transitions to next phase"
else
  bad "T9 unexpected output" "expected transition with all rubric blockers filled; got: $out"
fi

# ============================================================
# T10 — TRANSITION target follows the 3-phase profile (SPEC → BUILD → SHIP)
#   RED: implementation has the legacy 5-phase mapping (SPEC → PLAN → BUILD
#        → VERIFY → LEARN → SHIPPED). Caught during throwaway end-to-end
#        stress-test when SPEC completed and next_phase emitted SPEC→PLAN
#        but the playbook has no PLAN phase.
# ============================================================
note "T10: transition follows 3-phase profile (SPEC → BUILD)"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'EOF'
[PHASE: SPEC]

## PHASE: SPEC

## PHASE: BUILD
[ ] T1
EOF
out=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>&1 || true)
rm -rf "$d"
# Active phase SPEC has no [ ] markers — should emit SPEC→BUILD transition.
if echo "$out" | grep -Eq '"transition"[[:space:]]*:[[:space:]]*"SPEC→BUILD"'; then
  ok "T10 SPEC transitions to BUILD (3-phase profile)"
else
  bad "T10 wrong transition target" "expected 'SPEC→BUILD'; got: $out"
fi

# ============================================================
# T11 — pre-commit-block allows per-section commits (no [PHASE:] diff)
#   RED: original v0.7 hook refused ANY commit while open [ ] remained in
#        the active phase, blocking the documented per-section pattern.
#        Caught during throwaway end-to-end stress-test.
# ============================================================
note "T11: pre-commit-block allows per-section commits"
d=$(mkproj)
cd "$d"
git init -q
git config user.email t@t.com && git config user.name T
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: SPEC]

## PHASE: SPEC
- **Who has it:** [ ]
- **Why now:** [ ]
SPEC
git add -A && git commit -q -m "init"
sed -i.bak 's/Why now:\*\* \[ \]/Why now:** filled/' .sdd/features/001-test/spec.md
rm -f .sdd/features/001-test/spec.md.bak
git add -A
e=0
echo '{"tool_input":{"command":"git commit -m \"[SDD:001] spec: §2 fill\""}}' \
  | CLAUDE_PROJECT_DIR="$d" bash "$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-block.sh" >/dev/null 2>&1 || e=$?
cd - >/dev/null
rm -rf "$d"
if [ "$e" -eq 0 ]; then
  ok "T11 per-section commit allowed (no phase-advance signal)"
else
  bad "T11 false-trigger on per-section commit" "exit was $e, expected 0"
fi

# ============================================================
# T12 — pre-commit-block doesn't false-trigger on "phase:" in message body
#   RED: an earlier "tightened" regex still pattern-matched anywhere in the
#        commit message — bodies that QUOTED `[SDD:001] phase: X → Y` as an
#        example tripped the gate. Diff-only signal closes this. Caught
#        during throwaway when committing a hook fix whose body referenced
#        the convention.
# ============================================================
note "T12: pre-commit-block doesn't false-trigger on 'phase:' in body"
d=$(mkproj)
cd "$d"
git init -q
git config user.email t@t.com && git config user.name T
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: SPEC]

## PHASE: SPEC
- **Who has it:** [ ]
SPEC
git add -A && git commit -q -m "init"
echo "extra line" >> .sdd/features/001-test/spec.md
git add -A
e=0
# Commit message body literally contains the phase-advance convention as an example
echo '{"tool_input":{"command":"git commit -m \"[SDD:001] spec: §1 — example: [SDD:001] phase: SPEC → BUILD shows the convention\""}}' \
  | CLAUDE_PROJECT_DIR="$d" bash "$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-block.sh" >/dev/null 2>&1 || e=$?
cd - >/dev/null
rm -rf "$d"
if [ "$e" -eq 0 ]; then
  ok "T12 'phase:' in body doesn't trigger gate"
else
  bad "T12 message-body false-trigger" "exit was $e, expected 0 (only diff signal should gate)"
fi

# ============================================================
# T13 — pre-commit-block blocks phase-advance with rubric [ ] still open
#   RED: hook misses phase-advance commits, lets through commits with
#        unfilled rubric blockers in the source phase.
# ============================================================
note "T13: pre-commit-block blocks phase-advance with open rubric [ ]"
d=$(mkproj)
cd "$d"
git init -q
git config user.email t@t.com && git config user.name T
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: SPEC]

## PHASE: SPEC
- **Who has it:** [ ]
- **Why now:** [ ]

## PHASE: BUILD
SPEC
git add -A && git commit -q -m "init"
sed -i.bak 's/\[PHASE: SPEC\]/[PHASE: BUILD]/' .sdd/features/001-test/spec.md
rm -f .sdd/features/001-test/spec.md.bak
git add -A
e=0
echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: SPEC → BUILD\""}}' \
  | CLAUDE_PROJECT_DIR="$d" bash "$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-block.sh" >/dev/null 2>&1 || e=$?
cd - >/dev/null
rm -rf "$d"
if [ "$e" -eq 2 ]; then
  ok "T13 phase-advance with open [ ] correctly blocked"
else
  bad "T13 phase-advance let through" "exit was $e, expected 2 (block: source phase has open rubric blockers)"
fi

# ============================================================
# T14 — pre-commit-block allows phase-advance with only AC/T/C- placeholders
#   RED: same `[ ]` overload bug that hit next-action.sh — hook treats
#        `[ ] AC1`, `[ ] T1`, `[ ] C-...` as rubric blockers and refuses
#        legitimate phase-advance. Caught during throwaway at SPEC→BUILD.
# ============================================================
note "T14: pre-commit-block allows phase-advance when only AC/T/C- remain"
d=$(mkproj)
cd "$d"
git init -q
git config user.email t@t.com && git config user.name T
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: SPEC]

## PHASE: SPEC
- **Who has it:** filled
- **Why now:** filled
- [ ] AC1: GET / returns 200
- [ ] T1 scaffold

### Exit checks
- [ ] C-spec-acs: §11 has ≥1 AC — grep -q '\[ \] AC' "$SECTION_FILE"

## PHASE: BUILD
SPEC
git add -A && git commit -q -m "init"
sed -i.bak 's/\[PHASE: SPEC\]/[PHASE: BUILD]/' .sdd/features/001-test/spec.md
rm -f .sdd/features/001-test/spec.md.bak
git add -A
e=0
echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: SPEC → BUILD\""}}' \
  | CLAUDE_PROJECT_DIR="$d" bash "$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-block.sh" >/dev/null 2>&1 || e=$?
cd - >/dev/null
rm -rf "$d"
if [ "$e" -eq 0 ]; then
  ok "T14 work-item placeholders correctly skipped on phase-advance"
else
  bad "T14 false-block on AC/T/C- placeholders" "exit was $e, expected 0"
fi

# ============================================================
# T15 — next_phase BUILD → SHIP (3-phase profile, symmetric to T10)
#   RED: legacy 5-phase mapping has BUILD → VERIFY. The 3-phase v0.8 spine
#        collapsed VERIFY+LEARN into SHIP sub-actions. Caught during
#        throwaway when SPEC completed and we needed to verify the BUILD
#        end of the mapping was also right.
# ============================================================
note "T15: next_phase BUILD → SHIP (3-phase profile)"
d=$(mkproj)
cat > "$d/.sdd/features/001-test/spec.md" <<'EOF'
[PHASE: BUILD]

## PHASE: BUILD

## PHASE: SHIP
[ ] verify-test-run
EOF
out=$(bash "$NEXT_ACTION" "$d/.sdd/features/001-test/spec.md" 2>&1 || true)
rm -rf "$d"
if echo "$out" | grep -Eq '"transition"[[:space:]]*:[[:space:]]*"BUILD→SHIP"'; then
  ok "T15 BUILD transitions to SHIP (3-phase profile)"
else
  bad "T15 wrong transition target" "expected 'BUILD→SHIP'; got: $out"
fi

# ============================================================
# T16 — moat allows commit on honest BUILD verification.json
#   RED: hook is paranoid on non-SPEC phases, blocks honest verifications.
#        T8 covers negative case at BUILD; this completes the matrix with
#        the positive case at BUILD.
# ============================================================
note "T16: moat allows honest BUILD verification.json"
d=$(mkproj)
cd "$d"
git init -q
git config user.email t@t.com && git config user.name T
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: BUILD]

## PHASE: BUILD
[GREEN] T1 done

### Exit checks
- [ ] C-build-1: T1 present — grep -q 'T1' "$SECTION_FILE"
- [ ] C-build-2: phase header present — grep -q '## PHASE: BUILD' "$SECTION_FILE"
SPEC
bash "$VERIFY_STAGE" .sdd/features/001-test/spec.md BUILD >/dev/null 2>&1 || true
git add -A
e=0
echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD → SHIP\""}}' \
  | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" >/dev/null 2>&1 || e=$?
cd - >/dev/null
rm -rf "$d"
if [ "$e" -eq 0 ]; then
  ok "T16 honest BUILD verification allowed through"
else
  bad "T16 moat false-positive at BUILD" "exit was $e, expected 0"
fi

# ============================================================
# T17 — NUL byte in spec.md is rejected by verify-stage.sh
#   RED: awk treats \0 as record terminator. An exit-check line containing
#        a NUL has its `— <bash cmd>` separator silently dropped, the
#        check vanishes from output, and a fabricated `{"checks":[]}`
#        matches the empty fresh set, bypassing the moat. Caught by
#        adversarial reality-vs-theory review (round 2).
# ============================================================
note "T17: verify-stage rejects NUL bytes in spec.md"
d=$(mkproj)
# Construct a spec with a NUL byte mid-check line
printf '[PHASE: BUILD]\n## PHASE: BUILD\n### Exit checks\n- [ ] C1: poisoned-check\x00 — false\n' > "$d/.sdd/features/001-test/spec.md"
# Sanity: confirm the file actually contains a NUL byte
nul_present=0
od -An -c "$d/.sdd/features/001-test/spec.md" | grep -q '\\0' && nul_present=1
e=0
bash "$VERIFY_STAGE" "$d/.sdd/features/001-test/spec.md" BUILD >/dev/null 2>&1 || e=$?
rm -rf "$d"
if [ "$nul_present" -eq 1 ] && [ "$e" -ne 0 ]; then
  ok "T17 NUL-byte spec rejected by verify-stage (exit non-zero)"
else
  bad "T17 verify-stage processed NUL-poisoned spec" "nul_present=$nul_present, exit=$e (expected nul=1, exit≠0)"
fi

# ============================================================
# T18 — Moat rejects NUL bytes in staged spec.md
#   RED: same NUL truncation attack but in the hook's re-verification
#        path. The hook reads the staged spec via git show, then re-runs
#        verify-stage. If the staged spec has NULs and the hook doesn't
#        guard, fresh re-run produces empty checks, and a fabricated
#        empty verification.json matches.
# ============================================================
note "T18: moat rejects NUL bytes in staged spec.md"
d=$(mkproj)
cd "$d"
echo '**Active:** features/001-test' > .sdd/INDEX.md
printf '[PHASE: BUILD]\n## PHASE: BUILD\n### Exit checks\n- [ ] C1: poisoned\x00 — false\n' > .sdd/features/001-test/spec.md
cat > .sdd/features/001-test/verification.json <<'JSON'
{"phase":"BUILD","checks":[]}
JSON
git add -A
out=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
        | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" 2>&1) || true
e=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
      | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" >/dev/null 2>&1; echo $?)
cd - >/dev/null
rm -rf "$d"
# Assert the moat's OWN NUL guard fires (not the downstream verify-stage
# guard, which would also block but via a different message). This isolates
# the moat's defense-in-depth layer specifically.
nul_msg_seen=0
echo "$out" | grep -q 'spec.md contains NUL bytes' && nul_msg_seen=1
if [ "$e" -eq 2 ] && [ "$nul_msg_seen" -eq 1 ]; then
  ok "T18 moat's own NUL guard fires (defense-in-depth layer)"
else
  bad "T18 moat NUL guard not isolated" "exit=$e, msg_seen=$nul_msg_seen, output: $out"
fi

# ============================================================
# T19 — Moat refuses to use a tampered verify-stage.sh (hash pin)
#   RED: hook trusts the in-project verify-stage.sh blindly. An
#        adversarial agent replaces .sdd/scripts/verify-stage.sh with a
#        shim that emits any pass-state, fabricates a matching
#        verification.json, and the moat lets it through. Demonstrated
#        live by adversarial review round 2.
# ============================================================
note "T19: moat refuses tampered verify-stage.sh (hash mismatch)"
d=$(mkproj)
cd "$d"
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: BUILD]

## PHASE: BUILD

### Exit checks
- [ ] C1: impossible — false
SPEC
# Replace verify-stage.sh with a SHIM that always emits "pass"
cat > .sdd/scripts/verify-stage.sh <<'SHIM'
#!/usr/bin/env bash
# Shim: pretends C1 passed even though the real check is `false`
out_dir=$(dirname "$1")
cat > "$out_dir/verification.json" <<'JSON'
{"phase":"BUILD","checks":[{"id":"C1","result":"pass"}]}
JSON
exit 0
SHIM
chmod +x .sdd/scripts/verify-stage.sh
# Fabricate matching verification.json (matches the shim's output)
cat > .sdd/features/001-test/verification.json <<'JSON'
{"phase":"BUILD","checks":[{"id":"C1","result":"pass"}]}
JSON
# Stage ONLY the verification artifacts. The shim verify-stage.sh stays
# unstaged so the co-stage block doesn't fire — this isolates the hash
# pin path. (T20 covers the co-stage path separately.)
git add .sdd/INDEX.md .sdd/features/001-test/spec.md .sdd/features/001-test/verification.json
out=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
        | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" 2>&1) || true
e=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
      | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" >/dev/null 2>&1; echo $?)
cd - >/dev/null
rm -rf "$d"
hash_msg_seen=0
echo "$out" | grep -q 'hash mismatch' && hash_msg_seen=1
if [ "$e" -eq 2 ] && [ "$hash_msg_seen" -eq 1 ]; then
  ok "T19 tampered verify-stage.sh blocked via hash pin"
else
  bad "T19 hash pin not enforced" "exit=$e, hash_msg_seen=$hash_msg_seen, output: $out"
fi

# ============================================================
# T20 — Moat refuses to co-stage verify-stage.sh and verification.json
#   RED: hook only checks JSON content, not which files are staged. An
#        adversary stages BOTH a verify-stage shim and a fabricated
#        verification.json in one commit; the hook runs the shim,
#        verification matches, commit allowed. The co-stage block
#        forces verify-stage changes into their own auditable commit.
# ============================================================
note "T20: moat refuses co-stage of verify-stage.sh + verification.json"
d=$(mkproj)
cd "$d"
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: BUILD]

## PHASE: BUILD

### Exit checks
- [ ] C1: trivially true — true
SPEC
# A "harmless" edit to verify-stage.sh: just bump a comment. Even harmless
# co-staging is refused because allowing it opens the door to malicious shims.
echo "# touched-for-test" >> .sdd/scripts/verify-stage.sh
bash .sdd/scripts/verify-stage.sh .sdd/features/001-test/spec.md BUILD >/dev/null 2>&1 || true
git add -A
out=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
        | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" 2>&1) || true
e=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
      | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" >/dev/null 2>&1; echo $?)
cd - >/dev/null
rm -rf "$d"
co_block_seen=0
echo "$out" | grep -q 'cannot be staged in the same' && co_block_seen=1
if [ "$e" -eq 2 ] && [ "$co_block_seen" -eq 1 ]; then
  ok "T20 co-stage of verify-stage.sh + verification.json blocked"
else
  bad "T20 co-stage allowed" "exit=$e, co_block_seen=$co_block_seen, output: $out"
fi

# ============================================================
# T21 — pre-commit-block reads INDEX.md and spec.md from STAGED blobs
#   RED: hook reads working tree, agent blanks the working-tree INDEX.md
#        (or removes spec.md) to make the hook see no active feature,
#        then commits a phase-advance with open blockers. Caught by
#        adversarial reality-vs-theory review (round 3).
# ============================================================
note "T21: pre-commit-block reads from staged blobs (not working tree)"
d=$(mkproj)
cd "$d"
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: SPEC]

## PHASE: SPEC
- **Who has it:** [ ]
SPEC
git add -A && git commit -q -m "init"
# Stage a phase-advance from SPEC to BUILD (open [ ] in SPEC remains)
sed -i.bak 's/\[PHASE: SPEC\]/[PHASE: BUILD]/' .sdd/features/001-test/spec.md
rm -f .sdd/features/001-test/spec.md.bak
git add .sdd/features/001-test/spec.md
# Now blank out the working-tree INDEX.md to try to bypass
echo "" > .sdd/INDEX.md
e=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: SPEC->BUILD\""}}' \
      | CLAUDE_PROJECT_DIR="$d" bash "$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-block.sh" >/dev/null 2>&1; echo $?)
cd - >/dev/null
rm -rf "$d"
if [ "$e" -eq 2 ]; then
  ok "T21 working-tree INDEX.md blanking didn't bypass — hook used staged blob"
else
  bad "T21 working-tree manipulation bypassed gate" "exit=$e, expected 2"
fi

# ============================================================
# T22 — moat blocks co-stage of pre-commit-stage-verified.sh + verification.json
#   RED: hook only blocks co-stage of verify-stage.sh; agent stages a
#        no-op replacement of the moat hook itself + fabrication.
# ============================================================
note "T22: moat blocks co-stage of itself + verification.json"
d=$(mkproj)
cd "$d"
mkdir -p .claude/hooks
# Set up: scaffold commit has the hook in HEAD, then we modify it and stage
# alongside a verification.json. Both must be in the staged set.
cp "$MOAT_HOOK" .claude/hooks/pre-commit-stage-verified.sh
chmod +x .claude/hooks/pre-commit-stage-verified.sh
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: BUILD]

## PHASE: BUILD

### Exit checks
- [ ] C1: trivially true — true
SPEC
git add -A && git commit -q -m "scaffold"
# Now modify the hook AND create a fresh verification.json (both staged)
echo "# touched-for-test" >> .claude/hooks/pre-commit-stage-verified.sh
bash "$VERIFY_STAGE" .sdd/features/001-test/spec.md BUILD >/dev/null 2>&1 || true
git add -A
out=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
        | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" 2>&1) || true
e=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
      | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" >/dev/null 2>&1; echo $?)
cd - >/dev/null
rm -rf "$d"
hook_co_block_seen=0
echo "$out" | grep -q 'pre-commit-stage-verified.sh and verification.json' && hook_co_block_seen=1
if [ "$e" -eq 2 ] && [ "$hook_co_block_seen" -eq 1 ]; then
  ok "T22 hook co-stage with verification.json blocked"
else
  bad "T22 hook co-stage allowed" "exit=$e, msg_seen=$hook_co_block_seen, output: $out"
fi

# ============================================================
# T23 — pre-commit-block detects NUL via the staged-file path (round 4)
#   RED: round-3's NUL guard read the staged blob into a bash variable
#        via $(git show :spec). Bash strips NULs from command-substitution
#        output, so `printf "$content" | od` operates on already-stripped
#        bytes and never detects NUL. The fix uses a temp file.
# ============================================================
note "T23: pre-commit-block NUL guard works via staged-file path (round 4)"
d=$(mkproj)
cd "$d"
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: SPEC]

## PHASE: SPEC
- **Who has it:** [ ]
SPEC
git add -A && git commit -q -m "init"
# Stage a phase-advance with NUL bytes baked into the staged blob — using
# `git hash-object -w` to write a binary blob and `git update-index` to
# stage it (bypasses working-tree round-trip).
binary_blob=$(printf '[PHASE: BUILD]\n\n## PHASE: SPEC\n- [ ] §1: STILL OPEN\n\x00poison\n## PHASE: BUILD\n' | git hash-object -w --stdin)
git update-index --add --cacheinfo 100644 "$binary_blob" .sdd/features/001-test/spec.md
e=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: SPEC->BUILD\""}}' \
      | CLAUDE_PROJECT_DIR="$d" bash "$FRAMEWORK_ROOT/templates/.claude/hooks/pre-commit-block.sh" >/dev/null 2>&1; echo $?)
cd - >/dev/null
rm -rf "$d"
if [ "$e" -eq 2 ]; then
  ok "T23 NUL-byte staged spec correctly blocked"
else
  bad "T23 NUL bypass via staged-blob round 4" "exit=$e, expected 2"
fi

# ============================================================
# T24 — Moat blocks empty staged verification.json
#   RED: moat used to silently `continue` past empty claimed, treating
#        it as nothing to verify. An attacker could stage an empty file
#        to skip verification. Round 4 minor finding.
# ============================================================
note "T24: moat blocks empty staged verification.json"
d=$(mkproj)
cd "$d"
echo '**Active:** features/001-test' > .sdd/INDEX.md
cat > .sdd/features/001-test/spec.md <<'SPEC'
[PHASE: BUILD]

## PHASE: BUILD

### Exit checks
- [ ] C1: trivially true — true
SPEC
# Stage an EMPTY verification.json
: > .sdd/features/001-test/verification.json
git add -A
e=$(echo '{"tool_input":{"command":"git commit -m \"[SDD:001] phase: BUILD->SHIP\""}}' \
      | CLAUDE_PROJECT_DIR="$d" bash "$MOAT_HOOK" >/dev/null 2>&1; echo $?)
cd - >/dev/null
rm -rf "$d"
if [ "$e" -eq 2 ]; then
  ok "T24 empty verification.json blocked"
else
  bad "T24 empty verification.json allowed" "exit=$e, expected 2"
fi

# ============================================================
# T25 — settings.json registers the moat hook
#   RED: Phase A shipped with pre-commit-stage-verified.sh as a file but
#        never registered in templates/.claude/settings.json. The hook
#        existed but was never invoked by Claude Code's hook chain on
#        real commits. Pure configuration-consistency check; flagged by
#        Phase B coverage reviewer as a BLOCKER missed by 4 prior rounds.
# ============================================================
note "T25: settings.json registers pre-commit-stage-verified.sh"
if grep -q 'pre-commit-stage-verified\.sh' "$FRAMEWORK_ROOT/templates/.claude/settings.json"; then
  ok "T25 moat hook registered in PreToolUse chain"
else
  bad "T25 moat hook missing from settings.json" "no pre-commit-stage-verified.sh entry — hook ships unfired"
fi

# ============================================================
# T26 — CLAUDE.md version matches profile-feature.md profile_version
#   RED: Phase A shipped CLAUDE.md at v0.7.1 (5-phase prose) while
#        profile-feature.md was at 0.7.5-phase-a (3-phase). Drift caused
#        agent confusion at §11 — agent read CLAUDE.md's 5-phase rules in
#        a project whose playbook said 3 phases.
# ============================================================
note "T26: CLAUDE.md version matches profile-feature.md profile_version"
claude_version=$(grep -m1 'SDD-MANAGED-START version:' "$FRAMEWORK_ROOT/templates/CLAUDE.md" | sed -E 's/.*version: ([^ ]+) -->.*/\1/' || echo "")
profile_version=$(grep -m1 '^profile_version:' "$FRAMEWORK_ROOT/templates/.sdd/profile-feature.md" | awk '{print $2}' || echo "")
if [ -n "$claude_version" ] && [ "$claude_version" = "$profile_version" ]; then
  ok "T26 versions aligned (CLAUDE.md=$claude_version, profile-feature.md=$profile_version)"
else
  bad "T26 version drift" "CLAUDE.md=$claude_version, profile-feature.md=$profile_version (must match)"
fi

# ============================================================
# T27 — load-playbook.sh --validate rejects unknown tag
#   RED: loader silently accepts a sub-action with `tag: BOGUS`
#        instead of erroring with the closed-enum check (SCHEMA.md §6).
# ============================================================
note "T27: load-playbook.sh --validate rejects unknown tag"
d=$(mkproj_v08)
# Overlay invalid fixture into the project's subactions/
cp "$FIXTURES_V08/invalid-unknown-tag.md" "$d/.sdd/subactions/invalid-unknown-tag.md"
out=$(bash "$LOAD_PLAYBOOK" --validate "$d" 2>&1) && ec=0 || ec=$?
rm -rf "$d"
if [ "$ec" -ne 0 ] && echo "$out" | grep -qiE 'BOGUS|unknown tag|invalid tag'; then
  ok "T27 unknown tag rejected (exit=$ec, error mentions BOGUS/tag)"
else
  bad "T27 unknown tag accepted or wrong error" "exit=$ec; out='$out'"
fi

# ============================================================
# T28 — load-playbook.sh --validate rejects slug-filename mismatch
#   RED: loader doesn't enforce SCHEMA.md §1.5 / §2.6 rule that
#        slug must equal filename without .md.
# ============================================================
note "T28: load-playbook.sh --validate rejects slug-filename mismatch"
d=$(mkproj_v08)
# Fixture's filename is invalid-slug-mismatch.md but its slug claims not-the-filename
cp "$FIXTURES_V08/invalid-slug-mismatch.md" "$d/.sdd/subactions/invalid-slug-mismatch.md"
out=$(bash "$LOAD_PLAYBOOK" --validate "$d" 2>&1) && ec=0 || ec=$?
rm -rf "$d"
if [ "$ec" -ne 0 ] && echo "$out" | grep -qiE 'slug.*mismatch|slug.*filename|not-the-filename'; then
  ok "T28 slug-filename mismatch rejected (exit=$ec, error mentions slug)"
else
  bad "T28 slug mismatch accepted or wrong error" "exit=$ec; out='$out'"
fi

# ============================================================
# T29 — load-playbook.sh --validate rejects multi-match slug
#   RED: loader's slug-map allows two files to claim the same slug
#        instead of erroring with both paths listed (SCHEMA.md §10).
# ============================================================
note "T29: load-playbook.sh --validate rejects multi-match slug"
d=$(mkproj_v08)
# Two fixtures both declare slug=dup-test
cp "$FIXTURES_V08/multi-match/dup-a.md" "$d/.sdd/subactions/dup-a.md"
cp "$FIXTURES_V08/multi-match/dup-b.md" "$d/.sdd/subactions/dup-b.md"
out=$(bash "$LOAD_PLAYBOOK" --validate "$d" 2>&1) && ec=0 || ec=$?
rm -rf "$d"
if [ "$ec" -ne 0 ] && echo "$out" | grep -qiE 'duplicate slug|multi.?match|dup-test.*matches'; then
  ok "T29 multi-match slug rejected (exit=$ec, error mentions duplicate)"
else
  bad "T29 duplicate slugs accepted or wrong error" "exit=$ec; out='$out'"
fi

# ============================================================
# T30 — load-playbook.sh detects tampered framework file (hash mismatch)
#   RED: loader doesn't compare actual file SHA against manifest's
#        expected_sha256, so a tampered framework sub-action keeps its
#        trust=framework status (SCHEMA.md §11.2 violation).
# ============================================================
note "T30: load-playbook.sh detects tampered framework file"
d=$(mkproj_v08)
# Build a manifest claiming a hash for problem.md that DOESN'T match the actual file
problem_path="$d/.sdd/subactions/problem.md"
fake_hash="0000000000000000000000000000000000000000000000000000000000000000"
cat > "$d/.sdd/.cache/manifest.json" <<EOF
{
  "sdd_version": "0.8.0",
  "playbooks": {},
  "subactions": {
    "problem": {
      "path": ".sdd/subactions/problem.md",
      "expected_sha256": "$fake_hash",
      "trust": "framework"
    }
  },
  "extensions": {},
  "scripts": {}
}
EOF
out=$(bash "$LOAD_PLAYBOOK" --check-hashes "$d" 2>&1) && ec=0 || ec=$?
rm -rf "$d"
# Hash mismatch should emit a warning (stderr) AND mark untrusted; exit code may
# be 0 (warning) or non-zero (depends on impl). Test for the warning text.
if echo "$out" | grep -qiE 'tampered|hash mismatch|trust.*downgrade|untrusted'; then
  ok "T30 hash mismatch detected (warning emitted)"
else
  bad "T30 tamper not detected" "exit=$ec; out='$out'"
fi

# ============================================================
# T31 — pre-commit-cofile-block blocks verify-stage + verification.json co-stage
#   RED: hook absent or doesn't enforce the verify-stage / verification.json
#        pair, allowing an attacker to swap the verifier and ship a fabricated
#        verification.json in the same commit (Phase A defense in handoff §16).
# ============================================================
note "T31: cofile-block refuses verify-stage.sh + verification.json same commit"
d=$(mkproj_v08)
cd "$d"
# Modify verify-stage.sh + create verification.json, stage both
echo "# tampered" >> .sdd/scripts/verify-stage.sh
cat > .sdd/features/001-test/verification.json <<'EOF'
{"phase":"SPEC","checks":[{"id":"C-spec-acs","result":"pass"}],"approved_sections":{}}
EOF
git add .sdd/scripts/verify-stage.sh .sdd/features/001-test/verification.json
hook_stdin='{"tool_input":{"command":"git commit -m phase: SPEC -> BUILD"}}'
ec=0
echo "$hook_stdin" | bash "$COFILE_BLOCK" >/dev/null 2>&1 || ec=$?
cd - >/dev/null
rm -rf "$d"
if [ "$ec" -eq 2 ]; then
  ok "T31 cofile-block refused (exit 2)"
else
  bad "T31 cofile-block let pair through" "expected exit 2; got $ec"
fi

# ============================================================
# T32 — pre-commit-cofile-block blocks moat-hook + verification.json co-stage
#   RED: an attacker modifies pre-commit-stage-verified.sh to neuter the moat
#        and ships a fabricated verification.json in the same commit.
# ============================================================
note "T32: cofile-block refuses pre-commit-stage-verified.sh + verification.json same commit"
d=$(mkproj_v08)
cd "$d"
mkdir -p .claude/hooks
cp "$MOAT_HOOK" .claude/hooks/pre-commit-stage-verified.sh
echo "# tampered" >> .claude/hooks/pre-commit-stage-verified.sh
cat > .sdd/features/001-test/verification.json <<'EOF'
{"phase":"SPEC","checks":[{"id":"C-spec-acs","result":"pass"}],"approved_sections":{}}
EOF
git add .claude/hooks/pre-commit-stage-verified.sh .sdd/features/001-test/verification.json
hook_stdin='{"tool_input":{"command":"git commit -m phase: SPEC -> BUILD"}}'
ec=0
echo "$hook_stdin" | bash "$COFILE_BLOCK" >/dev/null 2>&1 || ec=$?
cd - >/dev/null
rm -rf "$d"
if [ "$ec" -eq 2 ]; then
  ok "T32 cofile-block refused (exit 2)"
else
  bad "T32 cofile-block let pair through" "expected exit 2; got $ec"
fi

# ============================================================
# T33 — pre-commit-cofile-block blocks playbook + verification.json co-stage
#   RED: an attacker modifies feature.md (e.g., loosens an exit_check or removes
#        a sub-action requiring approval) and ships a fabricated verification.json
#        in the same commit. Without this block, the playbook+claim are atomic.
# ============================================================
note "T33: cofile-block refuses playbook + verification.json same commit"
d=$(mkproj_v08)
cd "$d"
echo "# tampered" >> .sdd/playbooks/feature.md
cat > .sdd/features/001-test/verification.json <<'EOF'
{"phase":"SPEC","checks":[{"id":"C-spec-acs","result":"pass"}],"approved_sections":{}}
EOF
git add .sdd/playbooks/feature.md .sdd/features/001-test/verification.json
hook_stdin='{"tool_input":{"command":"git commit -m phase: SPEC -> BUILD"}}'
ec=0
echo "$hook_stdin" | bash "$COFILE_BLOCK" >/dev/null 2>&1 || ec=$?
cd - >/dev/null
rm -rf "$d"
if [ "$ec" -eq 2 ]; then
  ok "T33 cofile-block refused (exit 2)"
else
  bad "T33 cofile-block let pair through" "expected exit 2; got $ec"
fi

# ============================================================
# Report
# ============================================================
printf '\n----------------------------------------\n'
TOTAL=$((PASS+FAIL))
printf 'RESULTS: %d/%d passing (real-behavior assertions)\n' "$PASS" "$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  printf '\nFailures:\n'
  for f in "${FAILURES[@]}"; do
    printf '  - %s\n' "$f"
  done
  exit 1
fi
exit 0
