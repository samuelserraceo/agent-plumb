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
    missing = REQUIRED - set(fm.keys())
    if missing:
        failures.append((path, f"missing required fields: {sorted(missing)}"))

if failures:
    print("FAIL: frontmatter regressions:", file=sys.stderr)
    for path, reason in failures:
        print(f"  {path}: {reason}", file=sys.stderr)
    sys.exit(1)

print(f"PASS: AC10 — all {sum(1 for fn in os.listdir(actions_dir) if fn.endswith('.md'))} action files preserve their frontmatter")
PYEOF
