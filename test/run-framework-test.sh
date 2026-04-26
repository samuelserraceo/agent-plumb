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

PASS=0
FAIL=0
declare -a FAILURES=()

note() { printf '\n— %s\n' "$1"; }
ok()   { printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  ❌ %s\n     %s\n' "$1" "$2"; FAIL=$((FAIL+1)); FAILURES+=("$1: $2"); }

# Make a fresh tmp project; print path. Caller cleans up.
mkproj() {
  local d
  d=$(mktemp -d)
  mkdir -p "$d/.sdd/features/001-test" "$d/.sdd/scripts"
  # Wire scripts into the proj so the moat hook can find them at .sdd/scripts/.
  cp "$VERIFY_STAGE" "$d/.sdd/scripts/verify-stage.sh" 2>/dev/null || true
  cp "$NEXT_ACTION"  "$d/.sdd/scripts/next-action.sh"  2>/dev/null || true
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
