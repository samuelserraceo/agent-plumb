#!/usr/bin/env bash
# scope-guard-config.sh — read `scope_guard:` config from .sdd/config.md
# and emit shell-friendly outputs for the CI workflow's diff calls.
#
# Closes #16: scope-guard's hardcoded file-extensions + UI-dirs are now
# per-project configurable. Defaults match the v0.13.x Next.js shape so
# existing projects don't change behaviour when the helper lands.
#
# Why a helper script vs. inlining the YAML-load in the CI workflow:
# the framework's CI workflow already has a lot of inline shell; pulling
# YAML reading into a separate script keeps the workflow readable AND
# makes the config-reading independently testable (T116 / T116b / T116c
# in test/run-framework-test.sh).
#
# Usage:
#   scope-guard-config.sh --globs       # path globs (one per line) for `git diff -- <globs>`
#   scope-guard-config.sh --regex       # path-prefix regex `^(dir1|dir2)/.*\.(ext1|ext2)$`
#   scope-guard-config.sh --min-chars   # integer threshold for copy-string length
#
# Reads the YAML frontmatter of $CLAUDE_PROJECT_DIR/.sdd/config.md (or
# $(pwd)/.sdd/config.md if CLAUDE_PROJECT_DIR isn't set), pulls the
# `scope_guard:` block, falls back to the defaults baked in below if any
# of the three keys is missing or malformed.
#
# Defaults (must match `templates/.sdd/config.md`'s scope_guard: block):
#   file_extensions: [tsx, jsx, ts, js]
#   ui_dirs: [app, components, pages, src/app, src/components, src/pages]
#   copy_min_chars: 30
#
# Exit:
#   0 — emitted output to stdout
#   1 — usage error (no/unknown mode argument)

set -uo pipefail

if [ $# -lt 1 ]; then
  echo "[scope-guard-config] usage: scope-guard-config.sh {--globs|--regex|--min-chars}" >&2
  exit 1
fi

MODE="$1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_DIR/.sdd/config.md"

# Defaults — must stay in sync with `templates/.sdd/config.md` so a
# project without a scope_guard: block gets the same behaviour as one
# with the defaults written out.
DEFAULT_EXTS="tsx jsx ts js"
DEFAULT_DIRS="app components pages src/app src/components src/pages"
DEFAULT_MIN_CHARS="30"

# Try to read config.md's scope_guard block. Falls through to defaults
# silently on any failure (missing config, malformed YAML, missing
# python3, missing PyYAML).
EXTS=""
DIRS=""
MIN_CHARS=""
if [ -f "$CONFIG" ] && command -v python3 >/dev/null 2>&1; then
  yaml_out=$(CONFIG="$CONFIG" python3 - <<'PYEOF' 2>/dev/null
import os, re, sys
try:
    import yaml
except ImportError:
    sys.exit(0)
try:
    with open(os.environ["CONFIG"], encoding="utf-8") as f:
        text = f.read()
except OSError:
    sys.exit(0)
# Normalise line endings so a CRLF-committed config.md (common on
# Windows) still matches the frontmatter delimiter regex. Without
# this, the parser silently treated CRLF files as "no frontmatter"
# and every per-project override fell back to the Next.js defaults.
text = text.replace("\r\n", "\n").replace("\r", "\n")
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    sys.exit(0)
sg = fm.get("scope_guard") or {}
exts = sg.get("file_extensions")
dirs = sg.get("ui_dirs")
mc   = sg.get("copy_min_chars")
# `|` separator between fields; space separator within each field.
print("|".join([
    " ".join(str(e) for e in exts) if isinstance(exts, list) else "",
    " ".join(str(d) for d in dirs) if isinstance(dirs, list) else "",
    str(mc) if isinstance(mc, int) and mc > 0 else "",
]))
PYEOF
)
  IFS='|' read -r EXTS DIRS MIN_CHARS <<< "$yaml_out"
fi

# Apply defaults for any field that didn't resolve from config.md.
[ -z "$EXTS" ] && EXTS="$DEFAULT_EXTS"
[ -z "$DIRS" ] && DIRS="$DEFAULT_DIRS"
[ -z "$MIN_CHARS" ] && MIN_CHARS="$DEFAULT_MIN_CHARS"

case "$MODE" in
  --globs)
    # Cross-product of dirs × extensions, each as `<dir>/**/*.<ext>`.
    # One per line so the caller can read with `mapfile` or pass with
    # `xargs` / `$()`.
    for dir in $DIRS; do
      for ext in $EXTS; do
        printf '%s/**/*.%s\n' "$dir" "$ext"
      done
    done
    ;;
  --regex)
    # Build the path-prefix regex `^(dir1|dir2|...)/.*\.(ext1|ext2|...)$`.
    # Each token is escaped before being joined with `|` so a config
    # value like `app.[v1]` doesn't corrupt the regex (CR cycle-3
    # major). Python does the escaping (already a framework dep);
    # if python3 isn't available, fall through to the unescaped path
    # — same compatibility contract as the rest of this script.
    if command -v python3 >/dev/null 2>&1; then
      dirs_or=$(EXTS="$DIRS" python3 -c "
import os, re
print('|'.join(re.escape(t) for t in os.environ['EXTS'].split() if t))
")
      exts_or=$(EXTS="$EXTS" python3 -c "
import os, re
print('|'.join(re.escape(t) for t in os.environ['EXTS'].split() if t))
")
    else
      dirs_or=$(printf '%s' "$DIRS" | tr ' ' '|')
      exts_or=$(printf '%s' "$EXTS" | tr ' ' '|')
    fi
    printf '^(%s)/.*\\.(%s)$' "$dirs_or" "$exts_or"
    ;;
  --min-chars)
    printf '%s' "$MIN_CHARS"
    ;;
  *)
    echo "[scope-guard-config] unknown mode: $MODE" >&2
    echo "[scope-guard-config] usage: scope-guard-config.sh {--globs|--regex|--min-chars}" >&2
    exit 1
    ;;
esac
