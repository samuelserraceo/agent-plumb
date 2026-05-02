#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC10 — frontmatter preserved
# Test: every action file's YAML frontmatter still parses with the original field set

set -euo pipefail

python3 <<'PYEOF'
import os
import sys
import yaml

REQUIRED = {
    "type", "slug", "tag", "title", "short_label", "steps",
    "used_by", "references", "touches", "trust", "budget",
    "requires_user_approval",
}
# Optional fields some actions legitimately use (e.g. push-pr's
# `requires_setup` lets the framework refuse to advance until a
# deferred setup question is answered). Allowed but not mandated.
OPTIONAL_KNOWN = {
    "requires_setup",
}

actions_dir = "templates/.sdd/actions"
failures = []

for fn in sorted(os.listdir(actions_dir)):
    if not fn.endswith(".md"):
        continue
    path = os.path.join(actions_dir, fn)
    with open(path) as f:
        text = f.read()
    if not text.startswith("---"):
        failures.append((path, "no frontmatter"))
        continue
    end = text.find("\n---", 4)
    if end < 0:
        failures.append((path, "unterminated frontmatter"))
        continue
    try:
        fm = yaml.safe_load(text[4:end])
    except yaml.YAMLError as e:
        failures.append((path, f"YAML error: {e}"))
        continue
    if not isinstance(fm, dict):
        failures.append((path, f"frontmatter is {type(fm).__name__}, not dict"))
        continue
    keys = set(fm.keys())
    missing = REQUIRED - keys
    extra = keys - REQUIRED - OPTIONAL_KNOWN
    if missing:
        failures.append((path, f"missing required fields: {sorted(missing)}"))
    if extra:
        # CR feedback 2026-05-02: enforce schema — flag fields that
        # are neither required nor in the optional-known list.
        failures.append((path, f"unexpected top-level fields (schema regression): {sorted(extra)}"))

if failures:
    print("FAIL: frontmatter regressions:", file=sys.stderr)
    for path, reason in failures:
        print(f"  {path}: {reason}", file=sys.stderr)
    sys.exit(1)

print(f"PASS: AC10 — all {sum(1 for fn in os.listdir(actions_dir) if fn.endswith('.md'))} action files preserve their frontmatter")
PYEOF
