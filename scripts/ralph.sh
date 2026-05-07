#!/usr/bin/env bash
# Ralph loop — the real thing. Runs headless, one fresh Claude invocation per iteration.
#
# Best for BUILD phase auto-loop where context continuity doesn't matter and you
# want to walk away for a long time. For SPEC / PLAN / VERIFY / LEARN, use
# conversation mode (/next inside Claude Code) — those phases need discussion.
#
# Usage:
#   cd <project-root>
#   ./scripts/ralph.sh                # default: 50 iter max, 10 min/iter timeout
#   MAX_ITERS=20 ./scripts/ralph.sh   # override
#
# Requires: claude CLI in PATH, git, agent-browser, .sdd/ with active feature in BUILD phase.
#   On macOS, `timeout` ships only via Homebrew coreutils — this script
#   auto-detects and falls back to `gtimeout` if `timeout` isn't on PATH.
#   Both absent: claude invocations run without a timeout (with a warning).
#   Install coreutils on macOS: `brew install coreutils`.
#
# Halts on: all tasks GREEN (phase advances), halting rule fires, max iterations, Ctrl-C.

set -euo pipefail

# v0.10: read defaults from .sdd/config.md `parameters.ralph` if present;
# env vars still override. Cascade: env > config.md > hardcoded fallback.
read_ralph_config() {
  # CodeRabbit cycle 1 (PR #31): the unused `fallback` second param
  # was decorative — bash `${VAR:-fallback}` on the call site provides
  # the fallback chain. Single key arg is enough.
  local key="$1"
  if [ -f .sdd/config.md ] && command -v python3 >/dev/null 2>&1; then
    python3 -c "
import re, sys
try:
    import yaml
except ImportError:
    sys.exit(0)  # PyYAML missing — fall through to fallback
with open('.sdd/config.md', encoding='utf-8') as f: t = f.read()
m = re.match(r'^---\n(.*?)\n---', t, re.DOTALL)
if not m: sys.exit(0)
fm = yaml.safe_load(m.group(1)) or {}
v = (fm.get('parameters') or {}).get('ralph', {}).get('$key')
if v is not None: print(v)
" 2>/dev/null
  fi
}

MAX_ITERS="${MAX_ITERS:-$(read_ralph_config max_iters)}"
MAX_ITERS="${MAX_ITERS:-50}"
TIMEOUT_PER_ITER="${TIMEOUT_PER_ITER:-$(read_ralph_config timeout_per_iter)}"
TIMEOUT_PER_ITER="${TIMEOUT_PER_ITER:-600}"

# CodeRabbit cycle 2 (PR #31): validate the resolved values are
# positive integers. Without this, a typo like MAX_ITERS=foo would
# fail confusingly inside the arithmetic `[ "$iter" -lt "$MAX_ITERS" ]`
# expansion below; better to fail loud here with a clear message.
case "$MAX_ITERS" in
  ''|*[!0-9]*)
    echo "ERROR: MAX_ITERS must be a positive integer (got: '$MAX_ITERS')." >&2
    echo "       Set via env (MAX_ITERS=20) or .sdd/config.md parameters.ralph.max_iters." >&2
    exit 1 ;;
esac
case "$TIMEOUT_PER_ITER" in
  ''|*[!0-9]*)
    echo "ERROR: TIMEOUT_PER_ITER must be a positive integer in seconds (got: '$TIMEOUT_PER_ITER')." >&2
    echo "       Set via env (TIMEOUT_PER_ITER=300) or .sdd/config.md parameters.ralph.timeout_per_iter." >&2
    exit 1 ;;
esac
[ "$MAX_ITERS" -gt 0 ] || { echo "ERROR: MAX_ITERS must be > 0 (got: $MAX_ITERS)" >&2; exit 1; }
[ "$TIMEOUT_PER_ITER" -gt 0 ] || { echo "ERROR: TIMEOUT_PER_ITER must be > 0 (got: $TIMEOUT_PER_ITER)" >&2; exit 1; }

# ─── Detect timeout binary (macOS portability, #177) ───────────────
# GNU `timeout` ships with coreutils — present on Linux by default,
# absent on macOS unless `brew install coreutils` is run (which installs
# it as `gtimeout` by default; plain `timeout` only resolves after
# /opt/homebrew/opt/coreutils/libexec/gnubin is on PATH).
# Fall through to no-timeout if neither is found, with a warning.
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
else
  TIMEOUT_BIN=""
  if [ "$(uname -s)" = "Darwin" ]; then
    echo "[ralph] note: 'timeout' command not found. On macOS, install via:" >&2
    echo "             brew install coreutils       # provides 'gtimeout'" >&2
    echo "         Without it, claude invocations run with NO timeout (could hang indefinitely)." >&2
  else
    echo "[ralph] warning: no 'timeout' binary found on PATH — claude invocations will run with NO timeout." >&2
  fi
fi

# ─── Preflight ──────────────────────────────────────────────────────

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found. Install Claude Code first." >&2
  exit 1
fi

if [ ! -d .sdd ] || [ ! -f .sdd/INDEX.md ]; then
  echo "ERROR: run from the project root (.sdd/ + INDEX.md must exist)." >&2
  exit 1
fi

active=$(grep -m1 -E '^\*\*Active:\*\*' .sdd/INDEX.md | grep -oE 'features/[A-Za-z0-9._-]+' | head -1 || echo "")
if [ -z "$active" ]; then
  echo "ERROR: no active feature in .sdd/INDEX.md" >&2
  exit 1
fi

spec=".sdd/$active/spec.md"
[ -f "$spec" ] || { echo "ERROR: $spec not found" >&2; exit 1; }

phase=$(grep -m1 -oE '\[PHASE: [A-Z]+\]' "$spec" | grep -oE '[A-Z]+' | tail -1 || echo "")
if [ "$phase" != "BUILD" ]; then
  echo "ERROR: ralph only operates in BUILD phase. Current phase: $phase" >&2
  echo "       For $phase, use conversation mode (/next in Claude Code)." >&2
  exit 1
fi

# ─── The prompt — minimum viable contract ──────────────────────────

read -r -d '' PROMPT <<'PROMPT_EOF' || true
You are one iteration of a Ralph shell loop. You have FRESH context. You MUST re-read state from files this turn — do NOT rely on memory of any previous iterations.

Your job this iteration is to do exactly ONE task and exit.

1. Read .sdd/INDEX.md → find the active feature.
2. Read .sdd/features/<active>/spec.md → find current phase and the first RED task in the PHASE: PLAN Tasks list.
3. Read .sdd/CLAUDE.md → refresh on TDD order, commit conventions, universal halting rules, non-technical lens.

Then do EXACTLY ONE of these:

A) Phase is BUILD and there is a RED task (the common case):
   - Write the agent-browser test file at the path named in the task line (if missing).
   - Run the test → must be RED (no code yet).
   - Write the code to make it GREEN. **Code-quality discipline (CLAUDE.md):**
     * Conciseness is an asset — write the shortest code that works.
     * Don't over-engineer — no factory patterns, no premature abstractions.
     * Reuse > reinvent — check if a well-known package solves this before writing custom logic.
   - Run the test → must be GREEN.
   - **Self-check before committing: "Can this be shorter without losing clarity?"** If yes, tighten. If no, proceed.
   - **Wireframe check (BEFORE the code commit):** if the task touches a UI file, update `wireframe.html` to reflect what was just built and stage it. Order matters: wireframe must be in the same atomic commit as the code change, not in a follow-up. The framework refuses commits that touch UI without staging the wireframe.
   - Commit the code atomically (with wireframe.html if applicable): [SDD:<id>][T<n>] <short message>
   - Flip the task line status RED → GREEN in spec.md.
   - Commit the spec update: [SDD:<id>] task: T<n> GREEN
   - On your VERY LAST LINE, print exactly: RALPH_STATUS: CONTINUE T<n> <short phrase>
   - End your turn.

B) Phase is BUILD and ALL tasks are now GREEN:
   - Advance phase to VERIFY in spec.md. Update INDEX.md Active line.
   - Commit: [SDD:<id>] phase: BUILD -> VERIFY
   - On your VERY LAST LINE, print exactly: RALPH_STATUS: PHASE_ADVANCE VERIFY
   - End your turn.

C) Halting rule fires (test stays RED after 3 attempts, pre-commit hook blocks you, you discover a §5/§6 gap that needs a real design decision, or the next task needs credentials/infra the user hasn't provided):
   - Do NOT force through. Do NOT commit broken state.
   - On your VERY LAST LINE, print exactly: RALPH_STATUS: HALT <one-line reason>
   - End your turn.

Do exactly ONE task per iteration. Do not chain. Do not continue after CONTINUE. That is the Ralph contract.
PROMPT_EOF

# ─── Loop ───────────────────────────────────────────────────────────

trap 'echo ""; echo "Ralph interrupted by user."; exit 130' INT TERM

iter=0
while [ "$iter" -lt "$MAX_ITERS" ]; do
  iter=$((iter + 1))
  echo ""
  echo "───── Ralph iteration $iter / $MAX_ITERS ─────"

  set +e
  if [ -n "$TIMEOUT_BIN" ]; then
    output=$("$TIMEOUT_BIN" "$TIMEOUT_PER_ITER" claude -p "$PROMPT" --dangerously-skip-permissions 2>&1)
  else
    output=$(claude -p "$PROMPT" --dangerously-skip-permissions 2>&1)
  fi
  claude_exit=$?
  set -e

  if [ $claude_exit -ne 0 ]; then
    echo "Claude invocation failed (exit $claude_exit). Last 30 lines:"
    echo "$output" | tail -30
    exit 1
  fi

  status=$(echo "$output" | grep -oE 'RALPH_STATUS:.*' | tail -1 || echo "")

  if [ -z "$status" ]; then
    echo "No RALPH_STATUS in output. The agent may have not finished a task."
    echo "Last 30 lines:"
    echo "$output" | tail -30
    exit 1
  fi

  echo "$status"

  case "$status" in
    "RALPH_STATUS: CONTINUE"*)
      continue
      ;;
    "RALPH_STATUS: PHASE_ADVANCE"*)
      echo ""
      echo "✓ BUILD complete. Phase advanced to VERIFY."
      echo "  Next: switch to conversation mode in Claude Code → /verify"
      exit 0
      ;;
    "RALPH_STATUS: HALT"*)
      echo ""
      echo "✗ Ralph halted."
      echo "  Read the reason above, fix the blocker, then re-run ./scripts/ralph.sh"
      exit 1
      ;;
    *)
      echo "Unknown RALPH_STATUS — investigate."
      exit 1
      ;;
  esac
done

echo ""
echo "Ralph hit max iterations ($MAX_ITERS) without completing. Re-run to continue."
exit 1
