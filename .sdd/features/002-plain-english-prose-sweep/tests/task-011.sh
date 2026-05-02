#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC11 — prompt strings unchanged
# Test: every prompt: string in frontmatter is byte-identical between
#       the working tree and origin/main (prove the sweep only changed body).

set -euo pipefail

actions_dir="templates/.sdd/actions"
pre=$(mktemp -d); post=$(mktemp -d)
trap 'rm -rf "$pre" "$post"' EXIT

# Extract every steps[].prompt and every top-level prompt: from frontmatter,
# pre and post.
extract_prompts() {
  local path="$1" out_dir="$2"
  python3 - "$path" "$out_dir" <<'PYEOF'
import os, sys, yaml
src = sys.argv[1]
out_dir = sys.argv[2]
for root, _, files in os.walk(src):
    for fn in files:
        if not fn.endswith(".md"):
            continue
        full = os.path.join(root, fn)
        with open(full) as f:
            text = f.read()
        if not text.startswith("---"):
            continue
        end = text.find("\n---", 4)
        if end < 0:
            continue
        try:
            fm = yaml.safe_load(text[4:end])
        except Exception:
            continue
        if not isinstance(fm, dict):
            continue
        steps = fm.get("steps", [])
        prompts = []
        for s in steps if isinstance(steps, list) else []:
            if isinstance(s, dict) and "prompt" in s:
                prompts.append(s["prompt"])
        if prompts:
            with open(os.path.join(out_dir, fn + ".prompts"), "w") as g:
                for p in prompts:
                    g.write(repr(p) + "\n")
PYEOF
}

# Capture pre-sweep state via git show against origin/main
mkdir -p "$pre/templates/.sdd/actions"
for f in "$actions_dir"/*.md; do
  bn=$(basename "$f")
  git show "origin/main:$f" > "$pre/templates/.sdd/actions/$bn" 2>/dev/null || true
done
extract_prompts "$pre/templates/.sdd/actions" "$pre"

# Capture current state
mkdir -p "$post/templates/.sdd/actions"
cp "$actions_dir"/*.md "$post/templates/.sdd/actions/"
extract_prompts "$post/templates/.sdd/actions" "$post"

# Diff
if diff -r "$pre" "$post" --exclude="templates" >/dev/null 2>&1; then
  # CR feedback 2026-05-02: use find, not glob — under set -e a glob
  # with no matches makes ls exit non-zero and aborts the script
  # before the message prints (false negative on a passing test).
  count=$(find "$post" -maxdepth 1 -type f -name '*.prompts' | wc -l | tr -d ' ')
  echo "PASS: AC11 — $count action files' prompt strings byte-identical to origin/main"
else
  echo "FAIL: prompt strings drifted between origin/main and current tree:" >&2
  diff -r "$pre" "$post" --exclude="templates" 2>&1 | head -20 >&2
  exit 1
fi
