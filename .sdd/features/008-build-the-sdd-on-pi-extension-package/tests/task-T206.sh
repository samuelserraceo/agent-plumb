#!/usr/bin/env bash
# T206 — AC7 — /sdd-status is an instant zero-LLM command registered via
# pi.registerCommand; outputs current phase, blocker, and suggested next
# action without any LLM round-trip. Folds EC#8: when invoked outside an
# SDD project, falls back to "no SDD project found — run /sdd-start to
# initialise".
#
# Same delegation pattern as T204/T205: the pi extension owns the prompt
# template; the framework owns the script. T206 verifies BOTH layers —
# the contract (prompt body declares pi.registerCommand zero-LLM, the
# status.sh delegate, and the no-project fallback verbatim) AND the
# end-to-end behaviour of status.sh against two fixtures (no .sdd/, and
# a populated .sdd/ with an active feature).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROMPT="$FRAMEWORK_ROOT/extensions/sdd-pi-extension/prompts/sdd-status.md"
TPL="$FRAMEWORK_ROOT/templates/.sdd"

if [ ! -f "$PROMPT" ]; then
  echo "FAIL: T206 — prompts/sdd-status.md missing at $PROMPT"
  exit 1
fi
if [ ! -d "$TPL" ]; then
  echo "FAIL: T206 — framework templates dir missing at $TPL"
  exit 1
fi

fails=()

# --- Contract: prompt body declares the three things AC7 + EC#8 require:
# zero-LLM via pi.registerCommand, the status.sh delegate, and the
# fallback message string. Without each, downstream consumers can't
# guarantee instant-command behaviour or the EC#8 user message. ---
if ! grep -qF 'pi.registerCommand' "$PROMPT"; then
  fails+=("prompt missing zero-LLM registration: pi.registerCommand")
fi
if ! grep -qF 'bash .sdd/scripts/status.sh' "$PROMPT"; then
  fails+=("prompt missing invocation: bash .sdd/scripts/status.sh")
fi
if ! grep -qF 'no SDD project found' "$PROMPT"; then
  fails+=("prompt missing EC#8 fallback message: no SDD project found")
fi

# --- Script must exist in framework templates so HRN-01 copies it into
# .pi/sdd/scripts/ on session_start. ---
SCRIPT="$TPL/scripts/status.sh"
if [ ! -f "$SCRIPT" ]; then
  fails+=("framework script missing: $SCRIPT")
fi

# --- Self-host parity check (CR cycle 2 #9). The slash command shells
# out to `bash .sdd/scripts/status.sh` (the root copy, NOT the template).
# Without checking the root copy too, the script could disappear or
# drift and the test would still pass while /sdd-status breaks. Assert
# both files exist + are byte-identical.
ROOT_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/status.sh"
if [ ! -f "$ROOT_SCRIPT" ]; then
  fails+=("root script missing: $ROOT_SCRIPT (HRN-01 self-host parity broken)")
elif [ -f "$SCRIPT" ] && ! diff -q "$SCRIPT" "$ROOT_SCRIPT" >/dev/null 2>&1; then
  fails+=("root and template status.sh differ — self-host drift between $SCRIPT and $ROOT_SCRIPT")
fi

# --- End-to-end: only run if the script exists (avoids cascading
# failures when the contract gap is the script itself). ---
if [ -f "$SCRIPT" ]; then
  # Zero-LLM proxy: status.sh must not invoke any LLM CLI. AC7 requires
  # zero LLM round-trip; an LLM CLI in the script body would violate it.
  if grep -qiE '\b(claude|openai|anthropic|ollama|gpt|gemini)\b' "$SCRIPT"; then
    fails+=("status.sh references LLM CLI — AC7 requires zero-LLM (instant command)")
  fi

  WORK="$(mktemp -d -t sdd-t206.XXXXXX)"
  trap 'rm -rf "$WORK"' EXIT

  # --- E2E #1: no .sdd/ → EC#8 fallback message + clean exit. ---
  EMPTY="$WORK/empty"
  mkdir -p "$EMPTY"
  no_sdd_out="$(cd "$EMPTY" && bash "$SCRIPT" 2>&1)"
  no_sdd_rc=$?
  [ "$no_sdd_rc" -eq 0 ] || fails+=("status.sh failed in no-SDD project (exit $no_sdd_rc): $no_sdd_out")
  case "$no_sdd_out" in
    *'no SDD project found'*) : ;;
    *) fails+=("status.sh did not emit EC#8 fallback in no-SDD project (got: $no_sdd_out)") ;;
  esac

  # --- E2E #2: populated .sdd/ with active feature → output carries
  # phase, blocker, and a Next suggestion (the three AC7 fields). ---
  PROJECT="$WORK/project"
  FEATURE="$PROJECT/.sdd/features/001-test-thing"
  mkdir -p \
    "$FEATURE" \
    "$PROJECT/.sdd/scripts" \
    "$PROJECT/.sdd/actions" \
    "$PROJECT/.sdd/playbooks"
  cp "$TPL/scripts/resolve-active.sh"     "$PROJECT/.sdd/scripts/resolve-active.sh"
  cp "$TPL/scripts/next-action.sh"        "$PROJECT/.sdd/scripts/next-action.sh"
  cp "$TPL/scripts/resolve-parameters.sh" "$PROJECT/.sdd/scripts/resolve-parameters.sh" 2>/dev/null || true
  cp "$TPL/scripts/status-banner.sh"      "$PROJECT/.sdd/scripts/status-banner.sh" 2>/dev/null || true
  cp "$TPL/scripts/status.sh"             "$PROJECT/.sdd/scripts/status.sh"
  cp "$TPL/playbooks/feature.md"          "$PROJECT/.sdd/playbooks/feature.md"
  cp "$TPL/actions/problem.md"            "$PROJECT/.sdd/actions/problem.md"

  cat > "$PROJECT/.sdd/INDEX.md" <<'EOF'
# INDEX

**Active:** features/001-test-thing
**Playbook:** feature
EOF

  cat > "$FEATURE/spec.md" <<'EOF'
# test thing

[PHASE: SPEC]

**Active blocker:** SPEC (first action: problem)

## PHASE: SPEC

### action: problem

- [ ] who: Who specifically has this problem? (real persona, not 'users')
- [ ] why-now: Why is it worth solving now?
- [ ] what-breaks: What breaks (concretely) if it isn't solved?
EOF

  st_out="$(cd "$PROJECT" && bash .sdd/scripts/status.sh 2>&1)"
  st_rc=$?
  [ "$st_rc" -eq 0 ] || fails+=("status.sh failed in SDD project (exit $st_rc): $st_out")
  for needle in 'Phase:' 'SPEC' 'Blocker:' 'Next:'; do
    case "$st_out" in
      *"$needle"*) : ;;
      *) fails+=("status.sh output missing '$needle' (got: $st_out)") ;;
    esac
  done
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T206 — AC7 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T206 — AC7 /sdd-status zero-LLM contract + status.sh emits phase + blocker + next (and EC#8 fallback when no SDD project)"
