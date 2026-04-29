#!/usr/bin/env bash
# advance.sh — body of the post-commit ADVANCE step in the 4-step inner loop.
#
# Reads INDEX.md to find the active work item + action, walks the
# active playbook's stages[] to find the next action, and updates
# INDEX.md's "**Active blocker:**" pointer.
#
# Why this isn't a real post-commit hook: Claude Code's hook chain is
# PreToolUse only (no post-commit). In v0.9, the agent invokes this
# script explicitly after each /next's commit succeeds. A future
# release may add proper post-commit-via-Claude-Code support.
#
# Usage:
#   advance.sh                  # uses CLAUDE_PROJECT_DIR or pwd
#   advance.sh <project-dir>
#
# Behavior:
#   - If active action is NOT the last in its stage: advance to next
#   - If active action IS the last in its stage AND there's a next
#     stage: transition to that stage's first action
#   - If active action is the last action of the last stage:
#     mark INDEX.md's active blocker as `(work item complete — run
#     /next to advance to SHIPPED)`
#
# Exit:
#   0 — INDEX.md updated (or no-op if no active work item)
#   1 — error (file not found, malformed, no next action found)
#
# Idempotency stamp (v0.9.1 fix for the cycle-7 finding):
# Running advance.sh twice without an intervening commit would re-read
# the already-advanced INDEX.md and re-advance, skipping an action.
# Fix: record the HEAD sha at the moment of advance into a stamp file
# `.sdd/.advance.last-head`. On entry, if the stamp matches current
# HEAD, exit 0 as a no-op (no commit happened since last advance).
# After a successful advance, write the current HEAD sha to the stamp.
#
# This stamp file is RUNTIME STATE — should be gitignored (the install
# scaffold adds it). Earlier C-10 attempts at comparing INDEX.md
# content directly were rejected as false-positive-prone.

set -uo pipefail

PROJECT_DIR="${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
cd "$PROJECT_DIR" || exit 1

if [ ! -f ".sdd/INDEX.md" ]; then
  echo "[advance] .sdd/INDEX.md not found — nothing to advance." >&2
  exit 0
fi

command -v python3 >/dev/null 2>&1 || {
  echo "[advance] python3 required but not on PATH" >&2
  exit 1
}

# Idempotency stamp check: if we've already advanced for this HEAD,
# refuse to re-advance. The stamp lives at .sdd/.advance.last-head.
#
# CodeRabbit cycle 12 fix: use `git rev-parse HEAD` directly instead of
# `[ -d ".git" ]`. The directory check fails for git worktrees (where
# .git is a FILE, not a dir) — the stamp would silently never fire.
# Relying on `git rev-parse HEAD 2>/dev/null` succeeding is the
# canonical "am I in a git repo?" check; it works for both regular
# checkouts and worktrees.
STAMP_FILE=".sdd/.advance.last-head"
LOCK_FILE=".sdd/.advance.lock"
LOCK_DIR=".sdd/.advance.lock.d"
STALE_LOCK_SECONDS=300  # 5 min — anything older is from a killed run

# Issue #32 (v0.9.2): concurrency lock around the stamp check + write.
# Without it, two simultaneous advance.sh runs could both pass the
# pre-check before either writes the stamp, then both advance — losing
# one step.
#
# CodeRabbit cycle 1 (PR #53) hardening:
#   - flock path now FAIL-CLOSES on exec or flock errors (was: silently
#     continued unlocked)
#   - mkdir-based fallback now detects + recovers stale locks (was:
#     deadlocked after a hard kill since trap only fires on normal EXIT)
if command -v git >/dev/null 2>&1; then
  HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
  if [ -n "$HEAD_SHA" ]; then
    mkdir -p .sdd
    if command -v flock >/dev/null 2>&1; then
      # flock-based mutual exclusion. Fail-close on every step.
      if ! exec 9>>"$LOCK_FILE"; then
        echo "[advance] cannot open lock file $LOCK_FILE — refusing to advance unlocked." >&2
        exit 1
      fi
      if ! flock -n 9 2>/dev/null; then
        echo "[advance] another advance.sh is running on this project — waiting..." >&2
        if ! flock 9; then
          echo "[advance] flock failed even after wait — refusing to advance unlocked." >&2
          exit 1
        fi
      fi
    else
      # mkdir-based fallback. Stale-lock recovery: if a lock dir exists
      # and its mtime is older than STALE_LOCK_SECONDS, it's from a
      # killed run; remove and retry. PID file inside helps diagnostics.
      stale_check_and_retry() {
        if [ -d "$LOCK_DIR" ]; then
          # Compute age in seconds (portable across mac + linux)
          age=$(python3 -c "
import os, time
try:
    mtime = os.path.getmtime('$LOCK_DIR')
    print(int(time.time() - mtime))
except OSError:
    print(0)
" 2>/dev/null || echo 0)
          if [ "$age" -gt "$STALE_LOCK_SECONDS" ]; then
            # PID liveness check (closes #56). mtime > STALE_LOCK_SECONDS
            # is a NECESSARY condition for "stale," but not SUFFICIENT —
            # a long-running advance (e.g. waiting on a slow verify-stage
            # or external command) might legitimately hold the lock past
            # the threshold. If the recorded PID is still a live process,
            # respect it: don't clobber a working run.
            #
            # Only remove the lock when BOTH (a) mtime is past the
            # threshold AND (b) the recorded PID is dead OR the PID file
            # is missing/unreadable.
            stale_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
            if [ -n "$stale_pid" ] && kill -0 "$stale_pid" 2>/dev/null; then
              # Process still alive → not stale; caller keeps waiting.
              # Print a one-liner so the user knows why we're not clobbering.
              if [ "$attempts" -eq 1 ]; then
                echo "[advance] lock held by pid $stale_pid (alive, age ${age}s); waiting." >&2
              fi
              return 1
            fi
            # Process dead or PID file unreadable — safe to clean up.
            display_pid="${stale_pid:-?}"
            echo "[advance] stale lock detected (pid $display_pid, age ${age}s > ${STALE_LOCK_SECONDS}s, process not alive) — removing." >&2
            rm -rf "$LOCK_DIR" 2>/dev/null
            return 0  # caller should retry mkdir
          fi
        fi
        return 1  # not stale — caller should keep waiting
      }
      attempts=0
      while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        attempts=$((attempts + 1))
        if stale_check_and_retry; then
          continue  # try mkdir again
        fi
        if [ "$attempts" -eq 1 ]; then
          echo "[advance] another advance.sh is running — waiting..." >&2
        fi
        sleep 1
        if [ "$attempts" -gt 600 ]; then  # 10 min max wait
          echo "[advance] timeout waiting for lock $LOCK_DIR — refusing to advance unlocked." >&2
          exit 1
        fi
      done
      # Write PID for diagnostics + stale-detection
      echo "$$" > "$LOCK_DIR/pid" 2>/dev/null || true
      trap 'rm -rf "'"$LOCK_DIR"'" 2>/dev/null || true' EXIT INT TERM
    fi
    # Now we hold the lock. Check the stamp.
    if [ -f "$STAMP_FILE" ]; then
      LAST_SHA=$(cat "$STAMP_FILE" 2>/dev/null | tr -d '[:space:]')
      if [ "$LAST_SHA" = "$HEAD_SHA" ]; then
        echo "[advance] already advanced for HEAD $HEAD_SHA — no-op (commit a new step before next advance)."
        exit 0
      fi
    fi
  fi
fi

PROJ="$PROJECT_DIR" ADVANCE_HEAD_SHA="${HEAD_SHA:-}" python3 <<'PYEOF'
import os, re, sys
try:
    import yaml
except ImportError:
    print("[advance] PyYAML is required (install with: pip install pyyaml).",
          file=sys.stderr)
    sys.exit(1)

proj = os.environ["PROJ"]
index_path = os.path.join(proj, ".sdd", "INDEX.md")

with open(index_path, encoding="utf-8") as f:
    index_text = f.read()

# Parse current state from INDEX.md header lines.
m_active = re.search(r"^\*\*Active:\*\*\s+(.+)$", index_text, re.MULTILINE)
m_playbook = re.search(r"^\*\*Playbook:\*\*\s+(\S+)$", index_text, re.MULTILINE)
m_blocker = re.search(r"^\*\*Active blocker:\*\*\s+(.+)$", index_text, re.MULTILINE)

if not m_active or m_active.group(1).strip() in ("", "none", "_(none)_", "*(none)*"):
    print("[advance] no active work item in INDEX.md — nothing to do.")
    sys.exit(0)

if not m_playbook:
    print("[advance] INDEX.md missing **Playbook:** header line.", file=sys.stderr)
    sys.exit(1)

if not m_blocker:
    print("[advance] INDEX.md missing **Active blocker:** header line.", file=sys.stderr)
    sys.exit(1)

playbook_slug = m_playbook.group(1).strip()
blocker_text = m_blocker.group(1).strip()

# Parse active action slug from blocker line.
# Formats supported:
#   "§1 (first action: problem)"   ← /start scaffold
#   "§N (action: <slug>)"
#   "<slug>"                            ← bare slug
#   "(work item complete ...)"          ← terminal state — no advance
sa_match = re.search(r"action:\s*([a-z][a-z0-9-]*)", blocker_text)
if sa_match:
    active_slug = sa_match.group(1)
elif re.search(r"\bwork item complete\b", blocker_text, re.IGNORECASE):
    # Anchored to the canonical terminal phrase emitted below
    # (`(work item complete — run /next ...)`). Earlier `"complete"
    # in blocker_text.lower()` was too loose — a slug like
    # `complete-onboarding` would have been misclassified.
    print(f"[advance] work item already at terminal state: {blocker_text}")
    sys.exit(0)
else:
    bare = blocker_text.strip()
    if re.match(r"^[a-z][a-z0-9-]*$", bare):
        active_slug = bare
    else:
        print(f"[advance] cannot parse active action from blocker line: "
              f"{blocker_text!r}", file=sys.stderr)
        sys.exit(1)

# Load the playbook to walk its stages[].
playbook_path = os.path.join(proj, ".sdd", "playbooks", f"{playbook_slug}.md")
if not os.path.isfile(playbook_path):
    print(f"[advance] playbook not found: {playbook_path}", file=sys.stderr)
    sys.exit(1)

with open(playbook_path, encoding="utf-8") as f:
    pb_text = f.read()
pb_fm_match = re.match(r"^---\n(.*?)\n---", pb_text, re.DOTALL)
if not pb_fm_match:
    print(f"[advance] playbook has no YAML frontmatter: {playbook_path}",
          file=sys.stderr)
    sys.exit(1)

try:
    pb_fm = yaml.safe_load(pb_fm_match.group(1))
except Exception as e:
    print(f"[advance] playbook frontmatter parse error: {e}", file=sys.stderr)
    sys.exit(1)

# Shape guard: frontmatter must be a YAML mapping (dict). An empty `---\n---`
# block parses to None; a stray top-level list/string parses to list/str. Any
# of those would trace back unhandled at .get() below — surface a plain-English
# error instead.
if not isinstance(pb_fm, dict):
    print(f"[advance] playbook frontmatter is not a YAML mapping "
          f"(got {type(pb_fm).__name__}): {playbook_path}", file=sys.stderr)
    sys.exit(1)

stages = pb_fm.get("stages", []) or []
if not stages:
    print(f"[advance] playbook has no stages: {playbook_path}", file=sys.stderr)
    sys.exit(1)

# Find the stage containing the active action, then next slug.
next_slug = None
next_stage_id = None
terminal = False
for i, stage in enumerate(stages):
    sa_list = stage.get("actions", []) or []
    if active_slug in sa_list:
        idx = sa_list.index(active_slug)
        if idx + 1 < len(sa_list):
            # Next within same stage.
            next_slug = sa_list[idx + 1]
            next_stage_id = stage.get("id", "?")
        elif i + 1 < len(stages):
            # Stage transition.
            next_stage = stages[i + 1]
            next_stage_subs = next_stage.get("actions", []) or []
            if next_stage_subs:
                next_slug = next_stage_subs[0]
                next_stage_id = next_stage.get("id", "?")
            else:
                # Empty next stage — terminal.
                terminal = True
        else:
            # Last action of last stage — terminal.
            terminal = True
        break

if next_slug is None and not terminal:
    print(f"[advance] active action {active_slug!r} not found in any "
          f"stage of playbook {playbook_slug!r}.", file=sys.stderr)
    sys.exit(1)

# Update INDEX.md's "Active blocker" line.
if terminal:
    new_blocker = (
        f"(work item complete — run /next to mark shipped, or close out "
        f"the SHIP stage's last action manually)"
    )
else:
    new_blocker = f"§ ({next_stage_id} action: {next_slug})"

new_index = re.sub(
    r"^(\*\*Active blocker:\*\*\s+).*$",
    rf"\1{new_blocker}",
    index_text,
    count=1,
    flags=re.MULTILINE,
)

# Atomic write: write to a sibling tempfile then rename. Prevents
# partially-written INDEX.md if the process is interrupted mid-write
# (catches CodeRabbit's atomic-replace concern).
import tempfile
tmp_dir = os.path.dirname(index_path) or "."
fd, tmp_path = tempfile.mkstemp(prefix=".INDEX.tmp.", dir=tmp_dir)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(new_index)
    os.replace(tmp_path, index_path)
except Exception:
    if os.path.exists(tmp_path):
        os.unlink(tmp_path)
    raise

# Idempotency stamp write — moved here from after metrics append.
# CodeRabbit cycle 13 finding: if a downstream non-idempotent
# operation (metrics append, event resolution) failed, the stamp
# wouldn't write and a re-run could re-advance. Stamping right after
# the atomic INDEX.md replace is the correct ordering: as soon as the
# advance is durably visible in INDEX.md, record it.
#
# Only reached when a real advance happened — the early-exit paths
# (no active work item, terminal state) sys.exit(0) before getting
# here.
head_sha = os.environ.get("ADVANCE_HEAD_SHA", "").strip()
if head_sha:
    stamp_path = os.path.join(proj, ".sdd", ".advance.last-head")
    try:
        with open(stamp_path, "w", encoding="utf-8") as f:
            f.write(head_sha + "\n")
    except OSError as e:
        # Don't fail the whole advance if the stamp can't be written.
        # Worst case: the next /next call advances twice — annoying
        # but recoverable. Better than locking out a real advance.
        print(f"[advance] warning: could not write stamp {stamp_path}: {e}",
              file=sys.stderr)

# Theme 12 — token instrumentation. Append one line to .sdd/metrics.md
# per /next iteration. Format:
#   <ISO-Z timestamp>  <work-item-path>  <slug>  <tag>  <tokens>  <duration-s>
# v0.9 ships timestamp + slug + tag (token count + duration require
# LLM-level data unavailable from a shell script; Phase C extension
# can plumb them via the agent's own usage metadata).
import time
metrics_path = os.path.join(proj, ".sdd", "metrics.md")
work_item = m_active.group(1).strip()
# Read tag from the just-completed action's frontmatter.
sa_path = os.path.join(proj, ".sdd", "actions", f"{active_slug}.md")
tag = "?"
if os.path.isfile(sa_path):
    try:
        with open(sa_path, encoding="utf-8") as f:
            sa_text = f.read()
        sa_fm_match = re.match(r"^---\n(.*?)\n---", sa_text, re.DOTALL)
        if sa_fm_match:
            sa_fm = yaml.safe_load(sa_fm_match.group(1))
            if isinstance(sa_fm, dict):
                tag = sa_fm.get("tag", "?")
    except Exception:
        pass
ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
metrics_line = f"{ts}  {work_item}  {active_slug}  {tag}  -  -\n"
# Append-only — never edit prior lines (decisions.md / metrics.md are
# event logs per handoff Theme 7, Theme 12).
with open(metrics_path, "a", encoding="utf-8") as f:
    f.write(metrics_line)

# Note: idempotency stamp moved earlier — it now writes immediately
# after the atomic INDEX.md replace, so a metrics append failure
# can't leave the advance unrecorded.

if terminal:
    print(f"[advance] {active_slug} was the last action — work item "
          f"is now at terminal state.")
else:
    print(f"[advance] advanced {active_slug} → {next_slug} "
          f"(stage: {next_stage_id})")

# F2 events: when this advance produced a phase transition (the previous
# active action's stage differs from the next slug's stage), surface the
# `phase_transition` event flow. The agent reads this on its next turn
# and knows which files the event expects to be staged. Read-only —
# the actual append/rewrite work is the agent's job per CLAUDE.md;
# F1 generic enforcer (Phase C-5) will validate the staged commit
# against this declaration.
if not terminal and next_slug is not None:
    # Detect: did we just cross a stage boundary?
    prev_stage = None
    for stage in stages:
        if active_slug in (stage.get("actions") or []):
            prev_stage = stage.get("id", "?")
            break
    if prev_stage and prev_stage != next_stage_id:
        events_resolver = os.path.join(proj, ".sdd", "scripts", "read-events.sh")
        work_item_rel = m_active.group(1).strip()
        if os.path.isfile(events_resolver):
            import subprocess
            try:
                r = subprocess.run(
                    ["bash", events_resolver, "phase_transition", work_item_rel],
                    capture_output=True, timeout=10, cwd=proj,
                )
                if r.returncode == 0 and r.stdout:
                    import json as _json
                    try:
                        ev = _json.loads(r.stdout.decode("utf-8"))
                        actions = ev.get("actions") or []
                        if actions:
                            print(f"[advance] event fired: phase_transition "
                                  f"({prev_stage}→{next_stage_id}) — expects:")
                            for a in actions:
                                print(f"  - {a.get('action')} → {a.get('target')}")
                    except Exception:
                        pass
            except Exception:
                pass
PYEOF
