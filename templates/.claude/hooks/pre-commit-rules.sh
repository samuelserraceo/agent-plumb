#!/usr/bin/env bash
# pre-commit-rules.sh — F1 generic rule-enforcer.
#
# Single hook reading frontmatter + config to enforce framework rules
# at commit time. Designed to subsume 6+ specific hooks one by one as
# Phase-C progresses. **Phase C-5 (2/N) base scope:**
#
#   1. Action frontmatter `touches:` — every declared file must be
#      staged when the action's spec.md is staged. (Was:
#      pre-commit-touches.sh — runs in parallel for now; retired in
#      C-5 (3/N).)
#   2. Path safety — every declared `touches:` path is validated
#      against validate-sdd-path.sh before enforcement. Refuses
#      absolute paths, `..` segments, and paths outside `.sdd/`.
#
# Future scope (later C-5 commits):
#   3. Action `requires_user_approval:` — block phase advance if a
#      required-approval section's hash is stale.
#   4. Config `file_classes:` (POLICY vs CLAIM) — block cross-class
#      co-staging. (Subsumes pre-commit-cofile-block.sh.)
#   5. Config `file_rules:` (append-only, size cap, claude-md-managed) —
#      generalised. (Subsumes pre-commit-decisions-append-only.sh,
#      pre-commit-size-cap.sh, pre-commit-claude-md-managed.sh.)
#   6. Config `events:` — fire-time validation that staged files match
#      the event's declared actions. (Subsumes pre-commit-learn-sync.sh,
#      pre-commit-schema-sync.sh.)
#   7. Config `state_rules:` — phase advance with open `[ ]`. (Subsumes
#      pre-commit-block.sh — last to retire, highest leverage.)
#
# Behaviour:
#   - Empty-cmd safe default (exit 0)
#   - Non-commit Bash → exit 0
#   - No spec.md staged → exit 0 (nothing for SYNC to enforce yet)
#   - Active action unknown → exit 0
#   - Action `touches:` empty/absent → exit 0
#   - Any declared file missing OR unsafe path → BLOCK (exit 2)
#
# Wires up as a Claude Code PreToolUse hook on Bash. Parallel-fires
# with pre-commit-touches.sh until C-5 (3/N) retires that hook.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Fail-open on cd failure: if CLAUDE_PROJECT_DIR points somewhere
# unreachable, this hook can't enforce anything anyway, and blocking
# every Bash call in that case would be worse than letting the agent
# proceed (the moat hook applies the same fail-open contract). The
# tradeoff is conscious: framework-trusted hooks fail-open on env
# errors; the moat catches actual fabrication regardless.
cd "$PROJECT_DIR" || exit 0

# Parse stdin (Claude Code PreToolUse Bash payload).
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[ -z "$cmd" ] && exit 0

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

staged=$(git diff --cached --name-only 2>/dev/null || echo "")
[ -z "$staged" ] && exit 0

# === MERGE / REBASE / CHERRY-PICK detection (closes #220) ===
# Legitimate parallel-stream merges that preserve HEAD's bytes as a strict
# prefix of resolved content (e.g. decisions.md appends from both branches)
# previously forced a `git commit-tree` plumbing bypass — see dae7758 on
# F009's branch + #220 for the failure mode.
#
# In merge / rebase / cherry-pick modes, two rule paths relax:
#   1. append_only (file_rules) — keep the byte-prefix check (the merge case
#      already satisfies it); the audit log line below distinguishes
#      legitimate-merge-allow from regular-commit-allow for forensic review.
#   2. cofile-block (file_classes) — SKIP entirely. Merge commits span
#      CLAIM + POLICY classes by nature (verification.json from one branch,
#      manifest.json + actions from another).
#
# Gating on .git/<MODE>_HEAD is git-native; an attacker who can write
# .git/ can already bypass via `git commit-tree` directly, so this adds
# no new attack surface. The byte-prefix check in lenient mode still
# refuses tampering merges that rewrite prior entries.
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo ".git")
LENIENT_MODE=0
LENIENT_MODE_LABEL=""
if [ -f "$GIT_DIR/MERGE_HEAD" ]; then
  LENIENT_MODE=1
  LENIENT_MODE_LABEL="merge"
elif [ -f "$GIT_DIR/REBASE_HEAD" ] || [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ]; then
  LENIENT_MODE=1
  LENIENT_MODE_LABEL="rebase"
elif [ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]; then
  LENIENT_MODE=1
  LENIENT_MODE_LABEL="cherry-pick"
fi
if [ "$LENIENT_MODE" -eq 1 ]; then
  echo "[moat] $LENIENT_MODE_LABEL in progress — lenient mode (cofile-block skipped; append_only keeps byte-prefix check)" >&2
fi
export LENIENT_MODE

# === STATE_RULES enforcement (refuse on state condition) ===
# Read config.md `state_rules:` (list of { id, when, refuse, message } entries)
# and apply each entry's condition recogniser. Today's only recogniser:
#   phase_advance_with_open_blockers
#     - this commit changes the [PHASE: X] line in spec.md
#     - AND the source phase (read from HEAD's spec) still has `[ ]` step rows
#     - subsumes pre-commit-block.sh's central guarantee
#
# Adding a new rule type = a new `when:` value + a new branch below.
state_rules_result=$(STAGED="$staged" python3 - <<'PYEOF' || echo "ALLOW"
import os, re, subprocess, sys
try:
    import yaml
except Exception:
    print("ALLOW"); sys.exit(0)

try:
    text = open(".sdd/config.md").read()
except OSError:
    print("ALLOW"); sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    print("ALLOW"); sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    print("ALLOW"); sys.exit(0)

rules = fm.get("state_rules") or []
if not rules:
    print("ALLOW"); sys.exit(0)

# Helper: get the active work-item path from STAGED INDEX.md (anti-tamper).
def staged_active_path():
    try:
        r = subprocess.run(
            ["git", "show", ":.sdd/INDEX.md"],
            capture_output=True, check=False, text=True,
        )
    except Exception:
        return None
    if r.returncode != 0:
        return None
    for ln in r.stdout.splitlines():
        m2 = re.match(r"^\*\*Active:\*\*\s+(\S+)", ln)
        if m2:
            p = m2.group(1).strip()
            # R3 strict shape — lowercase folder / alphanumeric item, no traversal.
            if re.match(r"^[a-z][a-z0-9_-]*/[A-Za-z0-9._-]+$", p):
                return p
            return None
    return None

# Helper: phase_advance_with_open_blockers recogniser.
def phase_advance_open_blockers():
    active = staged_active_path()
    if not active:
        return None  # no active feature → rule doesn't apply
    spec = f".sdd/{active}/spec.md"
    # Bootstrap exception: spec.md status A → first creation, allow.
    try:
        ns = subprocess.run(
            ["git", "diff", "--cached", "--name-status", "--", spec],
            capture_output=True, check=False, text=True,
        )
    except Exception:
        return None
    if ns.returncode == 0 and ns.stdout:
        first = ns.stdout.splitlines()[0].split("\t")[0] if ns.stdout.splitlines() else ""
        if first == "A":
            return None  # bootstrap commit
    # NUL guard. Check the STAGED blob bytes first — if it contains NUL,
    # any phase-advance regex on `git diff` would see "Binary files differ"
    # and silently miss the change. Block any spec.md staged with NUL.
    # (Same defence as the legacy pre-commit-block.sh round-4 fix.)
    nul_check = None
    try:
        sb_pre = subprocess.run(
            ["git", "show", f":{spec}"],
            capture_output=True, check=False,
        )
        if sb_pre.returncode == 0 and b"\x00" in sb_pre.stdout:
            nul_check = "NUL"
    except Exception:
        pass
    if nul_check == "NUL":
        return ("NUL bytes in staged spec.md — refusing", [])
    # Phase-advance detection: staged diff changes [PHASE: X] line.
    try:
        diff = subprocess.run(
            ["git", "diff", "--cached", "--", spec],
            capture_output=True, check=False, text=True,
        )
    except Exception:
        return None
    if diff.returncode != 0 or not diff.stdout:
        return None
    if not re.search(r'^[+-]\[PHASE:\s*[A-Z]+\]', diff.stdout, re.MULTILINE):
        return None  # not a phase-advance commit
    # Source phase from HEAD.
    try:
        head = subprocess.run(
            ["git", "show", f"HEAD:{spec}"],
            capture_output=True, check=False, text=True,
        )
    except Exception:
        return None
    if head.returncode != 0:
        return None
    src_match = re.search(r'\[PHASE:\s*([A-Z]+)\]', head.stdout)
    if not src_match:
        return None
    source_phase = src_match.group(1)
    # Read STAGED spec, walk source phase body, fence-aware, AC/T/C- skip.
    try:
        sb = subprocess.run(
            ["git", "show", f":{spec}"],
            capture_output=True, check=False,
        )
    except Exception:
        return None
    if sb.returncode != 0:
        return None
    # NUL guard.
    if b"\x00" in sb.stdout:
        return ("NUL bytes in spec.md — refusing", [])
    text = sb.stdout.decode("utf-8", errors="replace")
    in_phase = False
    in_fence = False
    open_blockers = []
    target = f"## PHASE: {source_phase}"
    for line in text.split("\n"):
        if line.startswith("## "):
            if line == target:
                in_phase = True; in_fence = False; continue
            elif in_phase:
                break
            else:
                continue
        if not in_phase: continue
        if re.match(r'^\s*```', line):
            in_fence = not in_fence; continue
        if in_fence: continue
        if re.match(r'^\s*-\s*\[ \]\s+(AC|T|C-)[A-Za-z0-9_-]', line):
            continue
        if "[ ]" in line:
            open_blockers.append(line)
            if len(open_blockers) >= 5:
                break
    if open_blockers:
        return (source_phase, open_blockers)
    return None

# Dispatch.
recognisers = {
    "phase_advance_with_open_blockers": phase_advance_open_blockers,
}

for rule in rules:
    if not isinstance(rule, dict): continue
    if not rule.get("refuse"): continue
    when = rule.get("when") or ""
    rec = recognisers.get(when)
    if rec is None:
        continue  # unknown condition — silently skip (forwards-compat)
    hit = rec()
    if hit is None:
        continue
    msg = rule.get("message") or "state_rule violation"
    print("BLOCK")
    print(f"RULE: {rule.get('id') or when}")
    print(f"MESSAGE: {msg.strip()}")
    if isinstance(hit, tuple):
        ctx_label, ctx_items = hit
        if isinstance(ctx_items, list) and ctx_items:
            print(f"CONTEXT: source phase {ctx_label}, open blockers (first 5):")
            for ln in ctx_items:
                print(f"  {ln}")
        else:
            print(f"CONTEXT: {ctx_label}")
    sys.exit(0)

print("ALLOW")
PYEOF
)

case "$state_rules_result" in
  ALLOW*) ;;
  BLOCK*)
    cat >&2 <<EOF

[SDD rules / state_rules] State-condition refusal triggered.

$(printf '%s\n' "$state_rules_result" | sed -n '2,$p')

To soften this rule (project owners), edit .sdd/config.md
\`state_rules:\` and set \`refuse: false\` on the matching entry,
or remove the entry. Fill the open blockers, then retry.
EOF
    exit 2
    ;;
esac

# === FOLDER_RULES enforcement (Option B — warn-only by default) ===
# Read config.md `folder_rules:` and warn (no block by default) when:
#   - any staged path starts with a `deferred_paths:` prefix
#   - any staged path at the project root isn't in `root_allowed:`
# Project owners can flip default_action to "block" if they want strict
# enforcement — defaults to warn so the framework signals discipline
# without breaking dev flows.
folder_rules_result=$(STAGED="$staged" python3 - <<'PYEOF' || echo "ALLOW"
import os, re, sys
try:
    import yaml
except Exception:
    print("ALLOW"); sys.exit(0)

try:
    text = open(".sdd/config.md").read()
except OSError:
    print("ALLOW"); sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    print("ALLOW"); sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    print("ALLOW"); sys.exit(0)

rules = fm.get("folder_rules") or {}
if not rules:
    print("ALLOW"); sys.exit(0)

default_action = (rules.get("default_action") or "warn").lower()
deferred = rules.get("deferred_paths") or []
root_allowed = set(rules.get("root_allowed") or [])

violations = []  # list of (path, kind, hint)
for line in os.environ.get("STAGED", "").splitlines():
    p = line.strip()
    if not p:
        continue
    # deferred_paths: any staged file under one of these prefixes is flagged.
    for pref in deferred:
        if p.startswith(pref):
            violations.append((p, "deferred", f"{pref} is reserved for Phase C+; do not write here yet"))
            break
    # root_allowed: a top-level file (no slash) must be in the allow-list.
    if "/" not in p:
        if p not in root_allowed:
            violations.append((p, "stray-root", "use .sdd/ideas/<name>.md for one-off notes; per-feature artifacts go in .sdd/<work_item>/<NNN>-<slug>/"))

if not violations:
    print("ALLOW"); sys.exit(0)

# Emit warn (or block, if default_action == block).
if default_action == "block":
    print("BLOCK")
else:
    # Warn → write to stderr but mark ALLOW for the case-statement.
    sys.stderr.write("\n  ⚠  SDD folder_rules — staged paths are out of the canonical map:\n")
    for p, kind, hint in violations:
        sys.stderr.write(f"     - [{kind}] {p}\n       → {hint}\n")
    sys.stderr.write("     See CLAUDE.md \"Where things live\" for the canonical layout.\n\n")
    print("ALLOW"); sys.exit(0)

# block path
for p, kind, hint in violations:
    print(f"PATH: {p}")
    print(f"KIND: {kind}")
    print(f"HINT: {hint}")
PYEOF
)

case "$folder_rules_result" in
  ALLOW*) ;;
  BLOCK*)
    cat >&2 <<EOF

[SDD rules / folder_rules] Staged path violates the canonical folder map.

$(printf '%s\n' "$folder_rules_result" | sed -n '2,$p')

See CLAUDE.md "Where things live (canonical folder map)" for the
allowed layout. To soften this hook back to warn-only, set
\`folder_rules.default_action: warn\` in .sdd/config.md.
EOF
    exit 2
    ;;
esac

# === FILE_CLASSES + CO_STAGE_BLOCK enforcement ===
# Read config.md `file_classes:` (named regex pattern lists) and
# `co_stage_block:` (pairs of class names that cannot co-stage). Refuse
# any commit that stages files from both classes of any blocked pair.
# Subsumes pre-commit-cofile-block.sh's hardcoded CLAIM/POLICY rule
# while keeping the schema extensible: projects can declare more
# classes + pairs without changing this hook.
#
# Runs on EVERY commit with staged files (not gated on spec.md) — the
# cofile-block defends the framework against tampered-policy + fabricated-
# claim pairs regardless of whether the agent is doing action work.
#
# LENIENT_MODE skip (closes #220, T02): merge / rebase / cherry-pick
# commits span classes by nature (verification.json from one branch,
# manifest.json + actions from another). The audit log line above
# already recorded the lenient-mode entry; no extra log here.
if [ "$LENIENT_MODE" -eq 1 ]; then
  class_block_result="ALLOW"
else
class_block_result=$(STAGED="$staged" python3 - <<'PYEOF' 2>/dev/null || echo "ALLOW"
import os, re, sys
try:
    import yaml
except Exception:
    print("ALLOW"); sys.exit(0)

try:
    with open(".sdd/config.md") as f:
        text = f.read()
except OSError:
    print("ALLOW"); sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    print("ALLOW"); sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    print("ALLOW"); sys.exit(0)

classes = fm.get("file_classes") or {}
blocks  = fm.get("co_stage_block") or []
if not classes or not blocks:
    print("ALLOW"); sys.exit(0)

compiled = {}
for name, pats in classes.items():
    if not isinstance(pats, list): continue
    compiled[name] = [re.compile(p) for p in pats if isinstance(p, str)]

buckets = {name: [] for name in compiled}
for line in os.environ.get("STAGED", "").splitlines():
    line = line.strip()
    if not line: continue
    for name, pats in compiled.items():
        if any(p.search(line) for p in pats):
            buckets[name].append(line)

for pair in blocks:
    if not isinstance(pair, list) or len(pair) != 2: continue
    a, b = pair
    if buckets.get(a) and buckets.get(b):
        print("BLOCK")
        print(f"PAIR: {a} × {b}")
        print(f"{a}:")
        for f in buckets[a]: print(f"  {f}")
        print(f"{b}:")
        for f in buckets[b]: print(f"  {f}")
        sys.exit(0)
print("ALLOW")
PYEOF
)

# === FILE_RULES enforcement (per-file append_only / size cap / etc.) ===
# Read config.md `file_rules:` (path → rules map) and apply each rule
# handler against the matching staged file. Today's handlers:
#
#   append_only: true       — staged blob must start with HEAD blob byte-for-byte
#                              (subsumes pre-commit-decisions-append-only.sh)
#   size_warn / size_block  — line-count cap; warn writes stderr, block exits 2
#   managed_section         — warn-only; CLAUDE.md MANAGED block edits without
#                              version bump
#
# CodeRabbit fix (2nd review): the legacy `reset_phrase:` escape hatch was
# REMOVED. An append-only audit log shouldn't have a documented reset
# escape — it turns the log into rewriteable history. If decisions.md
# is genuinely corrupt, recovery is a manual operation outside this hook.
file_rules_result=$(STAGED="$staged" CMD="$cmd" python3 - <<'PYEOF' || echo "ALLOW"
import os, re, subprocess, sys
try:
    import yaml
except Exception:
    print("ALLOW"); sys.exit(0)

try:
    text = open(".sdd/config.md").read()
except OSError:
    print("ALLOW"); sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    print("ALLOW"); sys.exit(0)
try:
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    print("ALLOW"); sys.exit(0)

rules = fm.get("file_rules") or {}
if not rules:
    print("ALLOW"); sys.exit(0)

cmd = os.environ.get("CMD", "")
staged_lines = [ln.strip() for ln in os.environ.get("STAGED","").splitlines() if ln.strip()]

for path, rule in rules.items():
    if not isinstance(rule, dict): continue
    if path not in staged_lines: continue

    # size_warn / size_block handler — line-count cap on the STAGED blob.
    # CodeRabbit fix (5th cycle): read the staged blob via `git show :<path>`,
    # not the working-tree copy. The user can stage a small file then keep
    # editing it past the cap; the working-tree count would block them on
    # uncommitted edits, while the staged blob is what actually goes into
    # the commit. Falls back to working tree if `git show` fails (e.g., file
    # is in --intent-to-add state).
    sw = rule.get("size_warn")
    sb = rule.get("size_block")
    if sw or sb:
        line_count = None
        try:
            r = subprocess.run(
                ["git", "show", f":{path}"],
                capture_output=True, check=False,
            )
            if r.returncode == 0:
                line_count = r.stdout.count(b"\n")
        except Exception:
            pass
        # Fallback to working tree if git show didn't yield a usable count.
        if line_count is None:
            try:
                with open(path, encoding="utf-8") as f:
                    line_count = sum(1 for _ in f)
            except OSError:
                line_count = None
        if line_count is not None:
            if sb is not None and line_count >= int(sb):
                advice = rule.get("advice") or ""
                print("BLOCK")
                print(f"PATH: {path}")
                print(f"REASON: size_block — {line_count} lines (cap: {sb})")
                if advice:
                    print(f"ADVICE: {advice}")
                sys.exit(0)
            if sw is not None and line_count >= int(sw):
                advice = rule.get("advice") or ""
                # Soft warn — write to stderr, don't block.
                sys.stderr.write(
                    f"\n  ⚠  SDD size-cap (warn) — {path} is {line_count} lines "
                    f"(warn: {sw}, block: {sb if sb is not None else '-'})\n"
                )
                if advice:
                    sys.stderr.write(f"     {advice}\n")
                sys.stderr.write("\n")

    # managed_section handler — warn-only when CLAUDE.md's MANAGED block is
    # touched without a bump_marker file co-staged. (See claude-md-managed.sh
    # legacy hook for the original logic.)
    ms = rule.get("managed_section")
    if isinstance(ms, dict):
        # Only fires if THIS path is staged; check via subprocess.
        try:
            staged_diff = subprocess.run(
                ["git", "diff", "--cached", "--", path],
                capture_output=True, check=False, text=True,
            )
        except Exception:
            staged_diff = None
        if staged_diff and staged_diff.returncode == 0 and staged_diff.stdout:
            open_mark = ms.get("open") or ""
            close_mark = ms.get("close") or ""
            bump_marker = ms.get("bump_marker")
            on_edit = (ms.get("on_edit") or "warn").lower()
            # Walk the diff hunks; count +/- lines INSIDE the managed block.
            in_managed = False
            changes = 0
            for ln in staged_diff.stdout.splitlines():
                if ln.startswith("@@"):
                    in_managed = False
                    continue
                if open_mark and open_mark in ln:
                    in_managed = True
                    continue
                if close_mark and close_mark in ln:
                    in_managed = False
                    continue
                if in_managed and ln and ln[0] in "+-" and (len(ln) == 1 or ln[1] not in "+-"):
                    changes += 1
            if changes > 0:
                # Was bump_marker also staged? Allow silently.
                if bump_marker and bump_marker in staged_lines:
                    pass
                else:
                    sys.stderr.write(
                        f"\n  ⚠  SDD warning — you're editing {path}'s MANAGED section\n"
                        f"\n  Edits inside {open_mark!r} / {close_mark!r} will be overwritten\n"
                        f"  next time the framework updates. To signal deliberate customisation:\n"
                        f"    1. bump {bump_marker}\n"
                        f"    2. stage it alongside this commit\n"
                        f"\n  Commit proceeding — this is a warning, not a block ({on_edit}).\n\n"
                    )

    # append_only handler.
    if rule.get("append_only"):
        try:
            head = subprocess.run(
                ["git", "show", f"HEAD:{path}"],
                capture_output=True, check=False,
            )
        except Exception:
            continue
        if head.returncode != 0:
            # Not in HEAD — first creation, allow.
            continue
        try:
            staged_blob = subprocess.run(
                ["git", "show", f":{path}"],
                capture_output=True, check=False,
            )
        except Exception:
            continue
        if staged_blob.returncode != 0:
            print("BLOCK")
            print(f"PATH: {path}")
            print("REASON: could not read staged blob")
            sys.exit(0)
        if b"\x00" in staged_blob.stdout or b"\x00" in head.stdout:
            print("BLOCK")
            print(f"PATH: {path}")
            print("REASON: NUL bytes in file content")
            sys.exit(0)
        if not staged_blob.stdout.startswith(head.stdout):
            print("BLOCK")
            print(f"PATH: {path}")
            print("REASON: append_only — staged blob does not start with HEAD blob")
            sys.exit(0)

print("ALLOW")
PYEOF
)

case "$file_rules_result" in
  ALLOW*) ;;
  BLOCK*)
    cat >&2 <<EOF

[SDD rules / file_rules] A per-file rule blocked this commit.

$(printf '%s\n' "$file_rules_result" | sed -n '2,$p')

The framework's audit trail relies on append_only files staying
immutable — modifying or removing prior content breaks the trust
model. To fix: revert your edits to existing entries and APPEND your
new entry instead:

    git restore --staged <path>
    git checkout <path>
    # then append the new entry, re-stage, re-commit

If you genuinely need to rebuild the whole file (e.g., recovering
from corruption), do it manually outside the framework's contract:
restore from a known-good commit (\`git checkout <sha> -- <path>\`),
or rewrite history on a branch and review the result before merge.
There is no in-band escape hatch — the file is sacred.

The file_rules definitions live in .sdd/config.md \`file_rules:\`.
EOF
    exit 2
    ;;
esac

case "$class_block_result" in
  ALLOW*) ;;
  BLOCK*)
    cat >&2 <<EOF

[SDD rules / cofile-block] This commit stages files from two classes
that the framework refuses to mix in one commit.

$(printf '%s\n' "$class_block_result" | sed -n '2,$p')

Why this is blocked:
  Each cross-class pair lets a tampered policy ship with a matching
  fabricated claim in the same atomic commit. SDD requires policy
  changes and claim changes to be SEPARATE auditable commits.

How to fix (pick one):
  1. Unstage one class, commit the other:
       git reset HEAD <files-from-one-class>
       git commit
     Then commit the other class separately.

  2. If you genuinely need both, run /next first so the framework
     regenerates the claim against the new policy, then commit each
     class on its own.

The class definitions live in .sdd/config.md \`file_classes:\` and
\`co_stage_block:\`. Project owners can extend them.
EOF
    exit 2
    ;;
esac
fi  # end LENIENT_MODE cofile-block skip (closes #220, T02)

# === TOUCHES: enforcement (action-step gated) ===
# Touches: enforcement only fires when an action's spec.md is staged.
# Other commits (typo fixes, README updates, framework upgrades) don't
# need to honour the active action's touches: declaration.
if ! echo "$staged" | grep -qE '(^|/)spec\.md$'; then
  exit 0
fi

[ -f .sdd/INDEX.md ] || exit 0

# Resolve active action slug from INDEX.md.
active_slug=$(python3 - <<'PYEOF' 2>/dev/null || echo ""
import re, sys
try:
    text = open(".sdd/INDEX.md").read()
except OSError:
    sys.exit(0)
m = re.search(r"action:\s*([a-z][a-z0-9-]*)", text, re.IGNORECASE)
if m:
    print(m.group(1)); sys.exit(0)
m = re.search(r"\*\*Active blocker:\*\*\s*([a-z][a-z0-9-]+)", text, re.IGNORECASE)
if m:
    print(m.group(1))
PYEOF
)
[ -z "$active_slug" ] && exit 0

action_path=".sdd/actions/${active_slug}.md"
[ -f "$action_path" ] || exit 0

# Read the action's `touches:` list.
touches_files=$(SA_PATH="$action_path" python3 - <<'PYEOF' 2>/dev/null || echo ""
import os, re, sys
try:
    text = open(os.environ["SA_PATH"]).read()
except OSError:
    sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m: sys.exit(0)
try:
    import yaml
    fm = yaml.safe_load(m.group(1)) or {}
except Exception:
    sys.exit(0)
for t in (fm.get("touches") or []):
    if isinstance(t, str):
        print(t)
PYEOF
)

# If no touches: declared, the cofile-block above was the only check; allow.
[ -z "$touches_files" ] && exit 0

# Path-safety check: every declared `touches:` path must pass
# validate-sdd-path.sh. Catches drift in the action library where a
# malicious or buggy edit declares a path outside .sdd/ — F1 audit A1.
#
# CodeRabbit cycle 9 fix: build the unsafe-paths list as real
# newline-separated lines (not literal `\n` accumulated in a string).
# The earlier `printf "        - %s\n" $(printf '%s' "$unsafe")` shape
# word-split on whitespace, so any path containing a space would
# render incorrectly in the error message.
unsafe_lines=""
while IFS= read -r tf; do
  [ -z "$tf" ] && continue
  # Skip placeholder-templated paths (handled per-action in older code;
  # F1's full template substitution lands in a future commit).
  if echo "$tf" | grep -q '<'; then
    continue
  fi
  if ! bash .sdd/scripts/validate-sdd-path.sh "$tf" >/dev/null 2>&1; then
    if [ -z "$unsafe_lines" ]; then
      unsafe_lines="        - $tf"
    else
      unsafe_lines="$unsafe_lines
        - $tf"
    fi
  fi
done <<< "$touches_files"

if [ -n "$unsafe_lines" ]; then
  cat >&2 <<EOF

[SDD] action '$active_slug' declares 'touches:' paths that are unsafe:

$unsafe_lines

      The framework refuses paths that are absolute, contain '..'
      segments, or sit outside '.sdd/'. Edit the action's
      $action_path frontmatter to use a path under '.sdd/'.

EOF
  exit 2
fi

# Touches-staged check: every declared file (sans templated paths)
# must be in the staged set.
#
# Same word-splitting fix as the unsafe block above: build a real
# newline-separated string instead of accumulating literal `\n`.
missing_lines=""
while IFS= read -r tf; do
  [ -z "$tf" ] && continue
  tf_clean="${tf#/}"
  if echo "$tf_clean" | grep -q '<'; then
    continue
  fi
  if ! echo "$staged" | grep -qxF "$tf_clean"; then
    if [ -z "$missing_lines" ]; then
      missing_lines="        - $tf_clean"
    else
      missing_lines="$missing_lines
        - $tf_clean"
    fi
  fi
done <<< "$touches_files"

if [ -n "$missing_lines" ]; then
  cat >&2 <<EOF

[SDD] action '$active_slug' declares files it MUST also stage,
      but you committed without including all of them.

      Missing from this commit:
$missing_lines

      The action's frontmatter at $action_path declares
      \`touches: [...]\`. Each file in that list MUST be staged in the
      same commit as spec.md. Reason: declared sync points keep the
      project state coherent (e.g., schema changes → data-model.md
      stays in lockstep with spec.md).

      Either:
        - Stage the missing file(s):  git add <file>
        - Or undo this action's spec.md change

EOF
  exit 2
fi

exit 0
