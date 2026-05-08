#!/usr/bin/env bash
# next-action.sh — Resolve the next blocker in a SDD spec.md.
#
# v0.9 atomic-step iteration:
#   - Walks spec.md, finds active phase, finds first `[ ]` outside fences
#     and not matching work-item placeholders (AC/T/C-).
#   - Recognises the v0.9 step-row shape `- [ ] <step-id>: <prompt>` under
#     a `### action: <slug>` heading and looks up the step's frontmatter
#     entry from `.sdd/actions/<slug>.md`.
#   - For step-row matches, calls `resolve-parameters.sh` to compute the
#     F5 cascade (project → work item → stage → action → step) and embeds
#     the resolved parameters block in the JSON output.
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
#   parameters  — resolved F5 cascade (object) or null when the step
#                 isn't recognisable / the resolver fails
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

# Phase progression — derived from active playbook's stages: frontmatter
# rather than hardcoded. Per CLAUDE.md foundation 2 (Lego): each playbook
# owns its own phase sequence; this script reads what the playbook declares.
# Falls back to the feature playbook's stages when INDEX.md / playbook
# missing (preserves Phase A test compatibility on minimal scaffolds).
def _build_next_phase():
    fallback_stages = ["SPEC", "BUILD", "SHIP"]
    fallback_terminal = "SHIPPED"
    stages = fallback_stages
    terminal = fallback_terminal
    try:
        playbook_slug = "feature"
        index_path = os.path.join(proj, ".sdd", "INDEX.md")
        if os.path.isfile(index_path):
            with open(index_path, encoding="utf-8") as _f:
                m = re.search(r'^\*\*Playbook:\*\*\s+(\S+)\s*$', _f.read(), re.M)
                if m and re.match(r'^[a-z][a-z0-9-]*$', m.group(1)):
                    playbook_slug = m.group(1)
        pb_path = os.path.join(proj, ".sdd", "playbooks", f"{playbook_slug}.md")
        if os.path.isfile(pb_path):
            import yaml
            with open(pb_path, encoding="utf-8") as _f:
                _t = _f.read()
            _fm = re.match(r'^---\n(.*?)\n---', _t, re.DOTALL)
            if _fm:
                _meta = yaml.safe_load(_fm.group(1)) or {}
                _stages = [s.get("id") for s in (_meta.get("stages") or [])
                           if isinstance(s, dict) and s.get("id")]
                if _stages:
                    stages = _stages
                # Optional: playbook can declare a terminal_state.
                # If absent, last stage is the terminal (no further transition).
                terminal = _meta.get("terminal_state") or ""
    except Exception:
        pass
    result = {}
    for i in range(len(stages) - 1):
        result[stages[i]] = stages[i + 1]
    # Last stage maps to terminal (could be SHIPPED for feature, "" for project)
    result[stages[-1]] = terminal
    if terminal:
        result[terminal] = ""
    return result

NEXT_PHASE = _build_next_phase()

def emit(d):
    # ensure_ascii=False keeps UTF-8 verbatim (e.g. § literal, not §)
    # so downstream consumers can grep with the same string they see in spec.md.
    sys.stdout.write(json.dumps(d, sort_keys=True, ensure_ascii=False))
    sys.stdout.write("\n")

# Read spec.md.
# D1 (stress-test) — catch UnicodeDecodeError so a UTF-16 spec.md (Windows
# editor, `iconv -t UTF-16`) gives a plain-English error instead of a
# Python traceback.
# D5 (stress-test) — strip a leading UTF-8 BOM (﻿, written by Notepad
# on Windows) so the [PHASE: X] line on row 1 is recognised. Without this
# the script reports "no [PHASE: X] line found" when there is one.
try:
    with open(spec_path, encoding="utf-8") as f:
        spec_text = f.read()
except OSError as e:
    sys.stderr.write(json.dumps({"error": f"cannot read spec: {e}"}) + "\n")
    sys.exit(1)
except UnicodeDecodeError:
    sys.stderr.write(json.dumps({
        "error": "spec.md isn't UTF-8 — re-save it as UTF-8 (most editors offer "
                 "'Save As → UTF-8'). The framework's tools and the agent both "
                 "expect UTF-8."
    }) + "\n")
    sys.exit(1)
if spec_text.startswith("﻿"):
    spec_text = spec_text[1:]
# CR cycle-6 Critical — normalise CRLF/CR endings before split. Windows-saved
# files (Notepad, GitBash on Windows, sed -i on a CRLF source) leave \r at
# every line tail; later string equality checks like `line == target_heading`
# silently never match, and the script reports "no open [ ] step in PHASE: X"
# even when there ARE open steps. That returns a transition signal, which the
# agent then mistakes for "phase done" — drift-by-line-ending.
spec_text = spec_text.replace("\r\n", "\n").replace("\r", "\n")
spec_lines = spec_text.split("\n")

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

# Closes #169. Refuse to advance on a QUEUED feature. Queued items
# are pre-active scaffolds — folder + spec.md exist, but the user
# hasn't promoted them to "actively worked on" yet. /next on a queued
# feature would prematurely start asking §1 questions, breaking the
# user's mental model that only one feature is "in flight" at a time.
# The plain-English fix path: run /promote-to-active <id> to flip
# QUEUED → the playbook's first stage; OR pick a different active
# feature (one that's already in flight) by checking out its branch.
if phase == "QUEUED":
    sys.stderr.write(
        '{"error":"phase is QUEUED — this feature is scaffolded but not '
        'yet active. Run /promote-to-active to start it for real, '
        'or check out a different in-flight feature\'s branch."}\n'
    )
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
    #
    # Closes #197. The regex now accepts BOLD or non-bold labels:
    # `- [ ] AC1: ...` (canonical) AND `- [ ] **AC1:** ...` (bolded by
    # agents for emphasis). Without this, bolded labels fall through to
    # the generic step-row branch and stall /next at §11→§13 forever
    # — bricking SPEC for non-technical users.
    if re.match(r'^\s*-\s*\[ \]\s+(\*\*)?(AC|T|C-)[A-Za-z0-9_-]', line):
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
        "parameters": None,
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
            with open(action_path, encoding="utf-8") as f:
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

# F5 cascade: read playbook from INDEX.md, then call resolve-parameters.sh
# to compute the merged effective parameters. Failure of any sub-step
# leaves `parameters` as null — degrades gracefully (T75 covers this).
parameters = None
if active_action and step_id:
    playbook_slug = None
    index_path = os.path.join(proj, ".sdd", "INDEX.md")
    if os.path.isfile(index_path):
        try:
            with open(index_path, encoding="utf-8") as f:
                for ln in f:
                    pm = re.match(r'^\*\*Playbook:\*\*\s*([a-z][a-z0-9_-]*)\s*$', ln)
                    if pm:
                        playbook_slug = pm.group(1)
                        break
        except OSError:
            pass
    resolver = os.path.join(proj, ".sdd", "scripts", "resolve-parameters.sh")
    if playbook_slug and os.path.isfile(resolver):
        try:
            import subprocess
            r = subprocess.run(
                ["bash", resolver, spec_path, playbook_slug, phase, active_action, step_id],
                capture_output=True, timeout=10, cwd=proj,
            )
            if r.returncode == 0 and r.stdout:
                parameters = json.loads(r.stdout.decode("utf-8"))
        except Exception:
            parameters = None

emit({
    "phase": phase,
    "action": active_action,
    "step": step_id,
    "tag": action_tag,
    "prompt": step_meta.get("prompt") or step_meta.get("action"),
    "field": step_meta.get("field"),
    "sub_action": first_open_line,
    "transition": None,
    "parameters": parameters,
})
PYEOF
