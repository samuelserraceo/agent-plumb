#!/usr/bin/env bash
# T301 — AC3 — resolve-parameters.sh rejects invalid
# parameters.automation.level values, emits a clear stderr
# warning, and falls back to "checkpoint".
#
# An invalid value (e.g., "invalid-string", "FULL" uppercase,
# arbitrary garbage) must NOT silently pass through. The
# resolver:
#   1. Emits a warning to stderr naming the bad value + the
#      valid set (full/most/checkpoint).
#   2. Returns "checkpoint" as the effective value (safe
#      backwards-compat default).
#
# Folded edge case from §15 #5: empty string treated same as
# unset → checkpoint default (covered by T300, re-asserted here).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/resolve-parameters.sh"

WORK="$(mktemp -d -t sdd-t301.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

fails=()

setup_fixture() {
  local dir="$1"
  local level_yaml="$2"  # raw YAML, e.g.,  '"invalid"' or '"FULL"'
  mkdir -p "$dir/.sdd/scripts" "$dir/.sdd/playbooks" "$dir/.sdd/actions" \
           "$dir/.sdd/features/001-test"

  cat > "$dir/.sdd/config.md" <<EOF
---
type: config
sdd_version: 1.0.0
playbooks_available: [feature]
default_playbook: feature
parameters:
  automation:
    level: $level_yaml
---

# config

EOF

  cat > "$dir/.sdd/INDEX.md" <<'EOF'
# INDEX
**Active:** features/001-test
**Playbook:** feature
EOF

  cat > "$dir/.sdd/playbooks/feature.md" <<'EOF'
---
slug: feature
stages:
  - { id: SPEC, actions: [problem] }
---
EOF

  cat > "$dir/.sdd/actions/problem.md" <<'EOF'
---
slug: problem
tag: USER-LED
steps:
  - { id: who, prompt: "x", field: "§1.who" }
---
EOF

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

# Run resolver and capture stdout + stderr separately.
run_resolver() {
  local fixture_dir="$1"
  local out_file="$WORK/out.json"
  local err_file="$WORK/out.err"
  ( cd "$fixture_dir" && bash "$SCRIPT" .sdd/features/001-test/spec.md problem who >"$out_file" 2>"$err_file" )
  echo "$out_file" "$err_file"
}

get_level() {
  python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
auto = d.get("automation") or {}
print(auto.get("level") if isinstance(auto, dict) else "")
' "$1"
}

# --- A) Invalid tier string falls back to checkpoint + emits warning ---
A="$WORK/invalid-string"
setup_fixture "$A" '"invalid-string"'
read -r out_a err_a <<<"$(run_resolver "$A")"
level_a="$(get_level "$out_a")"
if [ "$level_a" != "checkpoint" ]; then
  fails+=("AC3 invalid-string: expected fallback to 'checkpoint', got '$level_a'")
fi
if ! grep -qi "invalid\|unknown\|warning" "$err_a"; then
  fails+=("AC3 invalid-string: expected stderr warning, got: $(cat "$err_a")")
fi

# --- B) Uppercase tier (case-sensitive — invalid) falls back ---
B="$WORK/uppercase"
setup_fixture "$B" '"FULL"'
read -r out_b err_b <<<"$(run_resolver "$B")"
level_b="$(get_level "$out_b")"
if [ "$level_b" != "checkpoint" ]; then
  fails+=("AC3 uppercase FULL: expected fallback to 'checkpoint', got '$level_b'")
fi
# Stderr assertion (CR cycle-1 #5): uppercase variant is invalid, must warn.
if [ ! -s "$err_b" ]; then
  fails+=("AC3 uppercase FULL: expected stderr warning, got empty")
elif ! grep -qi "invalid\|unknown\|warning\|fallback\|FULL" "$err_b"; then
  fails+=("AC3 uppercase FULL: stderr present but no expected token (invalid/unknown/warning/fallback/FULL): $(cat "$err_b")")
fi

# --- C) Empty string falls back (re-assert from §15 #5) ---
C="$WORK/empty"
setup_fixture "$C" '""'
read -r out_c err_c <<<"$(run_resolver "$C")"
level_c="$(get_level "$out_c")"
if [ "$level_c" != "checkpoint" ]; then
  fails+=("§15 #5 empty string: expected fallback to 'checkpoint', got '$level_c'")
fi
# Stderr assertion (CR cycle-1 #5): empty string is treated as unset; the
# framework-default path is silent (no warning needed). Either silent OR
# a warning is acceptable — assert ONLY that the level is checkpoint (above).

# --- D) Valid tiers still work (regression vs T300's A/B/C cases) ---
D="$WORK/valid-most"
setup_fixture "$D" '"most"'
read -r out_d err_d <<<"$(run_resolver "$D")"
level_d="$(get_level "$out_d")"
if [ "$level_d" != "most" ]; then
  fails+=("AC2 regression: valid 'most' broke after AC3 changes, got '$level_d'")
fi
# Stderr assertion (CR cycle-1 #5): valid tiers must NOT emit a warning.
# The resolver may still print unrelated stderr (e.g. PyYAML compatibility
# notes), so check specifically for our own automation.level warning token.
if grep -qi "parameters\.automation\.level.*invalid\|automation.*warning" "$err_d"; then
  fails+=("AC2 regression: valid 'most' should not emit automation-level warning, got: $(cat "$err_d")")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T301 — AC3 violations:"
  for e in "${fails[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo "PASS: T301 — AC3 invalid/uppercase/empty tier values fall back to checkpoint with stderr warning; AC2 regression clean"
