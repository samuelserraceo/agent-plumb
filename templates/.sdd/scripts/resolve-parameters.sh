#!/usr/bin/env bash
# resolve-parameters.sh — F5 cascading parameter resolver.
#
# Reads .sdd/config.md `parameters:` (project default), then layers
# work-item / stage / action / step overrides on top, returning the
# merged effective parameters as JSON to stdout.
#
# Cascade order (lowest priority first; later wins):
#   1. config.md frontmatter `parameters:`              (project)
#   2. spec.md frontmatter `overrides:` (if any)         (work item)
#   3. playbook.md per-stage `overrides:` (if any)       (stage)
#   4. action.md frontmatter `overrides:` (and legacy
#      `budget:` aliased to `parameters.budget:`)        (action)
#   5. step row's `overrides:` field (if any)            (step)
#
# Usage (full form):
#   resolve-parameters.sh <spec.md> <playbook-slug> <stage-id> <action-slug> <step-id>
#
# Usage (3-arg ergonomic shortcut, v0.10.2):
#   resolve-parameters.sh <spec.md> <action-slug> <step-id>
#   ↳ playbook + stage are auto-inferred:
#     - playbook from INDEX.md `**Playbook:**` line (fallback: `feature`)
#     - stage from spec.md's current `## PHASE: <X>` heading
#
# Output (stdout):
#   JSON object with merged parameter keys + a `_provenance` map naming
#   the level that contributed each leaf value (e.g.,
#   "budget.max_minutes": "action:proposed-approach").
#
# Determinism: pure file walk + frontmatter read; no $RANDOM, no
# timestamps. JSON emitted via json.dumps(sort_keys=True,
# ensure_ascii=False).

set -uo pipefail

# Argument handling: support both 5-arg full form and 3-arg shortcut.
# UAT v0.10.1 (#51): the original 5-arg signature was hard to remember
# and the UAT plan called it with 3 args. Keep both — the framework HAS
# the spec, so playbook + stage can be inferred at zero cost.
if [ $# -eq 5 ]; then
  SPEC="$1" PB="$2" STAGE="$3" ACTION="$4" STEP="$5"
elif [ $# -eq 3 ]; then
  SPEC="$1" ACTION="$2" STEP="$3"
  # Infer playbook from INDEX.md (fallback: feature)
  PROJECT_DIR_TMP="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  PB=$(awk '/^\*\*Playbook:\*\*/{print $2; exit}' "$PROJECT_DIR_TMP/.sdd/INDEX.md" 2>/dev/null || echo "")
  [ -z "$PB" ] && PB="feature"
  # Infer stage from spec.md's last `## PHASE: <X>` heading.
  # CodeRabbit cycle 2 fix (PR #53): the earlier pattern `\[PHASE: X\]`
  # was wrong — that bracketed form doesn't appear in spec.md; the
  # actual heading shape is `## PHASE: X`. Match the heading form so
  # STAGE actually resolves instead of always falling through to SPEC.
  STAGE=$(grep -oE '^##\s*PHASE:\s*[A-Z]+' "$SPEC" 2>/dev/null | grep -oE '[A-Z]+$' | tail -1 || echo "")
  [ -z "$STAGE" ] && STAGE="SPEC"
else
  cat >&2 <<EOF
{"error":"usage: resolve-parameters.sh <spec> <action> <step> (3-arg shortcut)\n              OR resolve-parameters.sh <spec> <playbook> <stage> <action> <step> (full)"}
EOF
  exit 1
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

SPEC="$SPEC" PB="$PB" STAGE_ID="$STAGE" ACTION_SLUG="$ACTION" STEP_ID="$STEP" \
  PROJ="$PROJECT_DIR" python3 <<'PYEOF'
import json, os, re, sys

proj   = os.environ["PROJ"]
spec   = os.environ["SPEC"]
pb     = os.environ["PB"]
stage  = os.environ["STAGE_ID"]
action = os.environ["ACTION_SLUG"]
step   = os.environ["STEP_ID"]

def read_frontmatter(path):
    if not os.path.isfile(path):
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            t = f.read()
        m = re.match(r'^---\n(.*?)\n---', t, re.DOTALL)
        if not m:
            return {}
        import yaml
        return yaml.safe_load(m.group(1)) or {}
    except Exception:
        return {}

def deep_merge(base, overlay, source_label, provenance, prefix=""):
    """Merge `overlay` into `base` recursively; record provenance for each
    leaf the overlay actually changed (intermediate dicts are NOT stamped
    — only scalar leaves). Returns merged dict; mutates provenance in
    place. Lists overwrite (no concat) — consistent with most config-merge
    libraries (e.g., Helm)."""
    if not isinstance(overlay, dict):
        return overlay
    out = dict(base) if isinstance(base, dict) else {}
    for k, v in overlay.items():
        path = f"{prefix}{k}" if prefix == "" else f"{prefix}.{k}"
        if isinstance(v, dict):
            base_sub = out.get(k) if isinstance(out.get(k), dict) else {}
            out[k] = deep_merge(base_sub, v, source_label, provenance, path)
        else:
            out[k] = v
            provenance[path] = source_label
    return out

# 1. Project defaults from config.md.
config_fm = read_frontmatter(os.path.join(proj, ".sdd", "config.md"))
project_params = config_fm.get("parameters") or {}

provenance = {}
# CodeRabbit cycle 9/10/11: removed unused `stamp()` helper. Earlier
# revisions used it to seed provenance from project_params; deep_merge
# now records provenance inline as it walks each level, so stamp()
# became dead code.

resolved = {}
resolved = deep_merge(resolved, project_params, "project", provenance)

# 2. Work-item overrides — spec.md frontmatter `overrides:`.
spec_fm = read_frontmatter(spec)
wi_over = spec_fm.get("overrides") or {}
if wi_over:
    resolved = deep_merge(resolved, wi_over, f"work-item:{os.path.basename(os.path.dirname(spec))}", provenance)

# 3. Stage overrides — playbook.md per-stage block.
pb_path = os.path.join(proj, ".sdd", "playbooks", f"{pb}.md")
pb_fm = read_frontmatter(pb_path)
stage_over = {}
for s in (pb_fm.get("stages") or []):
    if (s.get("id") or "") == stage:
        stage_over = s.get("overrides") or {}
        break
if stage_over:
    resolved = deep_merge(resolved, stage_over, f"stage:{stage}", provenance)

# 4. Action overrides — action.md frontmatter.
#    Two sources merged: legacy `budget:` (top-level) AND new
#    `overrides:`. Legacy `budget:` is treated as `overrides.budget`.
action_path = os.path.join(proj, ".sdd", "actions", f"{action}.md")
action_fm = read_frontmatter(action_path)
action_over = {}
if action_fm.get("budget"):
    action_over["budget"] = action_fm["budget"]
if action_fm.get("overrides"):
    # `overrides:` wins over legacy `budget:` when both present.
    action_over = deep_merge(action_over, action_fm["overrides"], f"action:{action}", {})
if action_over:
    resolved = deep_merge(resolved, action_over, f"action:{action}", provenance)

# 5. Step overrides — declared on the matching step row.
step_over = {}
for s in (action_fm.get("steps") or []):
    if (s.get("id") or "") == step:
        step_over = s.get("overrides") or {}
        break
if step_over:
    resolved = deep_merge(resolved, step_over, f"step:{action}/{step}", provenance)

# Emit.
out = dict(resolved)
out["_provenance"] = provenance
sys.stdout.write(json.dumps(out, sort_keys=True, ensure_ascii=False) + "\n")
PYEOF
