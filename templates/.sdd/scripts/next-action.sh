#!/usr/bin/env bash
# next-action.sh — Resolve the next blocker in a SDD spec.md.
#
# v0.9 atomic-step iteration:
#   - Walks spec.md, finds active phase, finds first `[ ]` outside fences
#     and not matching work-item placeholders (AC/T/C-).
#   - Recognises the v0.9 step-row shape `- [ ] <step-id>: <prompt>` under
#     a `### action: <slug>` heading and looks up the step's frontmatter
#     entry from `.sdd/actions/<slug>.md`.
#
# Output JSON keys (always emitted; v0.9 fields populated when the step
# is recognisable, otherwise null):
#   phase       — active phase ID (e.g. SPEC)
#   action      — action slug (e.g. problem) or null
#   step        — step ID (e.g. who) or null
#   tag         — USER-LED / AGENT-LED / BUILD-TASK or null
#   prompt      — step's prompt or action label or null
#   field       — where in spec.md the answer goes or null
#   sub_action  — legacy: the literal `[ ]` line from spec.md (or null)
#   transition  — null, or "X→Y" when the active phase has no open `[ ]`
#
# Determinism: pure file walk + frontmatter read; no $RANDOM, no
# timestamps. JSON emitted via json.dumps(sort_keys=True) so two
# invocations on the same inputs produce byte-identical output.

set -uo pipefail

if [ $# -lt 1 ]; then
  echo '{"error":"missing spec path"}' >&2
  exit 1
fi

spec="$1"
if [ ! -f "$spec" ]; then
  echo '{"error":"spec not found"}' >&2
  exit 1
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SPEC="$spec" PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import json, os, re, sys

spec_path = os.environ["SPEC"]
proj = os.environ["PROJ"]

# Phase progression — aligned with the 3-phase v0.8/v0.9 feature playbook.
NEXT_PHASE = {"SPEC": "BUILD", "BUILD": "SHIP", "SHIP": "SHIPPED", "SHIPPED": ""}

def emit(d):
    # ensure_ascii=False keeps UTF-8 verbatim (e.g. § literal, not §)
    # so downstream consumers can grep with the same string they see in spec.md.
    sys.stdout.write(json.dumps(d, sort_keys=True, ensure_ascii=False))
    sys.stdout.write("\n")

# Read spec.md.
try:
    with open(spec_path) as f:
        spec_lines = f.read().split("\n")
except OSError as e:
    sys.stderr.write(json.dumps({"error": f"cannot read spec: {e}"}) + "\n")
    sys.exit(1)

# 1. Find [PHASE: X] line.
phase = None
for line in spec_lines:
    m = re.match(r'^\[PHASE:\s*([A-Z]+)\]', line)
    if m:
        phase = m.group(1)
        break

if not phase:
    sys.stderr.write('{"error":"no [PHASE: X] line found"}\n')
    sys.exit(1)

# 2. Walk active phase body. Track fence state and the most recent
# `### action: <slug>` heading. Skip work-item placeholders. Return the
# first `[ ]` line + the action slug active at that point.
target_heading = f"## PHASE: {phase}"
in_phase = False
in_fence = False
active_action = None
first_open_line = None

for line in spec_lines:
    if line.startswith("## "):
        if line == target_heading:
            in_phase = True
            in_fence = False
            active_action = None
            continue
        elif in_phase:
            break  # left our phase
        else:
            continue
    if not in_phase:
        continue
    # Toggle fence state on lines that start with ``` (with optional language tag).
    if re.match(r'^\s*```', line):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    # Track the active action heading.
    am = re.match(r'^###\s+action:\s+([a-z][a-z0-9_-]*)\s*$', line)
    if am:
        active_action = am.group(1)
        continue
    # Skip `[ ]` lines that are work-item placeholders (AC<N>, T<N>, C-<N>) —
    # those are filled by other mechanisms (BUILD task lifecycle / verify-stage).
    if re.match(r'^\s*-\s*\[ \]\s+(AC|T|C-)[A-Za-z0-9_-]', line):
        continue
    if "[ ]" in line:
        first_open_line = line
        break

# 3a. No open [ ] in active phase → transition signal.
if first_open_line is None:
    nxt = NEXT_PHASE.get(phase, "")
    transition = f"{phase}→{nxt}" if nxt else None
    emit({
        "phase": phase,
        "action": None, "step": None, "tag": None,
        "prompt": None, "field": None,
        "sub_action": None,
        "transition": transition,
    })
    sys.exit(0)

# 3b. Try to enrich with action+step lookup.
step_id = None
sm = re.match(r'^\s*-\s*\[ \]\s+([a-z][a-z0-9_-]*)\s*:', first_open_line)
if sm:
    step_id = sm.group(1)

action_tag = None
step_meta = {}
if active_action and step_id:
    action_path = os.path.join(proj, ".sdd", "actions", f"{active_action}.md")
    if os.path.isfile(action_path):
        try:
            import yaml
            with open(action_path) as f:
                t = f.read()
            fm = re.match(r'^---\n(.*?)\n---', t, re.DOTALL)
            if fm:
                meta = yaml.safe_load(fm.group(1)) or {}
                action_tag = meta.get("tag")
                for s in (meta.get("steps") or []):
                    if (s.get("id") or "").strip() == step_id:
                        step_meta = s
                        break
        except Exception:
            # PyYAML missing or frontmatter malformed: degrade gracefully —
            # legacy fields stay null, sub_action still echoes the line.
            pass

emit({
    "phase": phase,
    "action": active_action,
    "step": step_id,
    "tag": action_tag,
    "prompt": step_meta.get("prompt") or step_meta.get("action"),
    "field": step_meta.get("field"),
    "sub_action": first_open_line,
    "transition": None,
})
PYEOF
