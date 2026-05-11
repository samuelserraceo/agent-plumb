#!/usr/bin/env bash
# T300 — AC1 + AC2 — resolve-parameters.sh exposes
# parameters.automation.level with default `checkpoint` when unset,
# and returns the configured value when set to a valid tier.
#
# AC1 (default): fresh project without parameters.automation.level
# in config.md → resolve-parameters.sh returns "checkpoint" for
# automation.level. (Backward-compat default.)
#
# AC2 (valid values): when parameters.automation.level is set to
# "full" / "most" / "checkpoint" in config.md → resolver returns
# that exact value.
#
# Fixture: temp project with minimal .sdd/ shape (just config.md
# + a fake spec.md). Invoke resolve-parameters.sh against the
# fixture and parse its JSON output.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/resolve-parameters.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: T300 — resolve-parameters.sh not executable at $SCRIPT"
  exit 1
fi

WORK="$(mktemp -d -t sdd-t300.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

fails=()

# --- Helpers ----------------------------------------------------------

setup_fixture() {
  # Build a minimal .sdd/ shape sufficient for resolve-parameters.sh.
  local dir="$1"
  local config_yaml="$2"  # the parameters: block content to inject
  mkdir -p "$dir/.sdd/scripts" "$dir/.sdd/playbooks" "$dir/.sdd/actions" \
           "$dir/.sdd/features/001-test"

  cat > "$dir/.sdd/config.md" <<EOF
---
type: config
sdd_version: 1.0.0
playbooks_available: [feature]
default_playbook: feature
parameters:
$config_yaml
---

# config

EOF

  # Minimal INDEX.md so resolve-parameters can infer playbook.
  cat > "$dir/.sdd/INDEX.md" <<'EOF'
# INDEX

**Active:** features/001-test
**Playbook:** feature
EOF

  # Minimal playbook stub.
  cat > "$dir/.sdd/playbooks/feature.md" <<'EOF'
---
slug: feature
stages:
  - { id: SPEC, actions: [problem] }
---
EOF

  # Minimal action stub.
  cat > "$dir/.sdd/actions/problem.md" <<'EOF'
---
slug: problem
tag: USER-LED
steps:
  - { id: who, prompt: "x", field: "§1.who" }
---
EOF

  # Minimal spec.md.
  cat > "$dir/.sdd/features/001-test/spec.md" <<'EOF'
---
playbook: feature
---

# test

[PHASE: SPEC]

## PHASE: SPEC

### action: problem
- [ ] who: x
EOF
}

resolve_level() {
  # Run the resolver against a fixture and extract automation.level
  # from its JSON. Returns "" on parse failure or missing key.
  local fixture_dir="$1"
  ( cd "$fixture_dir" && bash "$SCRIPT" .sdd/features/001-test/spec.md problem who 2>/dev/null ) \
    | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
# Look for parameters.automation.level — flat key OR nested.
auto = d.get("automation") or {}
level = auto.get("level") if isinstance(auto, dict) else None
if level is None:
    # Try flat key fallback
    level = d.get("automation.level")
print(level if level is not None else "")
'
}

# --- A) Default = checkpoint when parameters.automation.level unset ---
A="$WORK/no-automation"
setup_fixture "$A" "  budget:
    max_minutes: 5"
result_a="$(resolve_level "$A")"
if [ "$result_a" != "checkpoint" ]; then
  fails+=("AC1: default tier when unset → expected 'checkpoint', got '$result_a'")
fi

# --- B) parameters.automation.level = full ---
B="$WORK/level-full"
setup_fixture "$B" "  budget:
    max_minutes: 5
  automation:
    level: full"
result_b="$(resolve_level "$B")"
if [ "$result_b" != "full" ]; then
  fails+=("AC2 full: expected 'full', got '$result_b'")
fi

# --- C) parameters.automation.level = most ---
C="$WORK/level-most"
setup_fixture "$C" "  budget:
    max_minutes: 5
  automation:
    level: most"
result_c="$(resolve_level "$C")"
if [ "$result_c" != "most" ]; then
  fails+=("AC2 most: expected 'most', got '$result_c'")
fi

# --- D) parameters.automation.level = checkpoint (explicit) ---
D="$WORK/level-checkpoint"
setup_fixture "$D" "  budget:
    max_minutes: 5
  automation:
    level: checkpoint"
result_d="$(resolve_level "$D")"
if [ "$result_d" != "checkpoint" ]; then
  fails+=("AC2 checkpoint: expected 'checkpoint', got '$result_d'")
fi

# ----------------------------------------------------------------------
if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T300 — AC1+AC2 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T300 — AC1 default checkpoint when unset + AC2 returns full/most/checkpoint when set"
