---
type: action
slug: minimal-diff-verify
tag: AGENT-LED
model_tier: mechanical
title: "§4 Minimal-diff verify"
short_label: "Minimal-diff"
steps:
  - { id: verify, action: "run git diff --shortstat against the branch base; halt if the line-count delta is positive", field: "§4.delta" }
used_by: [refactor]
references: [refactor-scope, regression-coverage, refactor-approach]
touches: []
trust: framework
budget:
  max_minutes: 5
  max_tokens: 1500
  max_commits: 1
requires_user_approval: false
---

Mechanical check at the end of SPEC: did we actually shrink the codebase, or did we accidentally grow it?

**Run this command** in the project root. Detect the base branch first — `main` is the most common but some projects use `master`, `develop`, or a release-line branch — and HALT if neither the base ref nor the merge-base resolves (silent failure here would defeat the safety gate by reporting an empty diff):

```bash
# 1. Detect the base branch. Try (a) origin/HEAD, (b) common origin
# branches, (c) common LOCAL branches. The local fallback matters
# because a fresh project pre-first-push has no `origin/*` refs at
# all — telling the user to run `git remote set-head origin` would be
# nonsense before they've pushed anything.
base_ref=""  # full ref to compare against (e.g. "origin/main" or "main")
base="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
        | sed 's@^refs/remotes/origin/@@')"
if [ -n "$base" ]; then
  base_ref="origin/$base"
fi
if [ -z "$base_ref" ]; then
  for candidate in main master develop trunk; do
    if git rev-parse --verify --quiet "origin/$candidate" >/dev/null; then
      base_ref="origin/$candidate"; break
    fi
  done
fi
if [ -z "$base_ref" ]; then
  # No origin refs available — fall back to local branches.
  for candidate in main master develop trunk; do
    if git rev-parse --verify --quiet "$candidate" >/dev/null; then
      base_ref="$candidate"; break
    fi
  done
fi
if [ -z "$base_ref" ]; then
  echo "ERROR: cannot detect base branch (no origin/HEAD, no origin/main|master|develop|trunk, no local main|master|develop|trunk)." >&2
  echo "       If you have a remote: git remote set-head origin <branch>" >&2
  echo "       If you don't yet:    create a base branch (e.g. \`git branch main\` if your work is on a different branch)." >&2
  exit 1
fi

# 2. Compute the merge-base. If this fails, HALT — don't advance with no signal.
mb="$(git merge-base HEAD "$base_ref")" || {
  echo "ERROR: cannot compute merge-base against $base_ref." >&2
  echo "       Branch may not be tracking the right base, or $base_ref may be missing." >&2
  exit 1
}

# 3. Run the shortstat with the language globs you care about.
shortstat="$(git diff --shortstat "$mb...HEAD" -- '*.py' '*.sh' '*.ts' '*.tsx' '*.js' '*.jsx' '*.go' '*.rb' '*.rs')"

# 4. HALT on empty output. `git diff --shortstat` exits 0 with NO
# output when no files match the globs — that gives the agent no
# delta signal, which would silently disable the gate. Treat empty
# as a halt: the refactor either matches none of the listed file
# types (narrow the globs to your stack) or didn't actually touch
# any tracked files (this isn't a refactor — switch to feature.md).
if [ -z "$shortstat" ]; then
  echo "ERROR: git diff --shortstat produced no output." >&2
  echo "       Either no files match the language globs (narrow them" >&2
  echo "       to your stack), or this branch hasn't actually modified" >&2
  echo "       any tracked source files yet." >&2
  exit 1
fi

echo "$shortstat"
```

(Adjust the file globs to match the project's primary language. The default list above is broad; if your refactor only touches `.sh`, narrow accordingly.)

**If the command exits non-zero:** stop and surface the error to the user. Don't paste an empty `### §4.delta` and advance — that would silently disable the gate, which is exactly the load-bearing safety this section provides.

**Expected output shape:**

```text
N files changed, X insertions(+), Y deletions(-)
```

**Compute the delta:** `delta = X - Y`.

- **`delta <= 0`** → ✅ refactor reduced or held steady. Record the numbers in §4.delta and advance to BUILD. *"Diff: 4 files changed, 12 insertions(+), 28 deletions(-). Delta: -16 (refactor shrunk by 16 lines)."*
- **`delta > 0`** → ⚠️ HALT. The refactor added net lines. Three legitimate paths from here:
  1. **Trim the diff** — re-open §3 (refactor-approach) and tighten the new shape. The smallest helper that achieves the goal.
  2. **Switch playbooks** — if the new lines are genuine new behaviour, this isn't a refactor. Stop, scrap the branch, restart with `feature.md`.
  3. **Override (rare)** — if you have a legitimate reason for the growth (e.g., the new helper needs more inline documentation than the duplication had), record the rationale in §4.delta and proceed. Hashed-locked: *"Net +12 lines because the new helper carries 14 lines of doctrine documentation that didn't exist in the duplicated form. Approved override."*

**Why mechanical, not vibes-based.** The "refactor that grew during the work" is the canonical anti-pattern this playbook prevents. Doing the check at SPEC's end (not at SHIP) means you catch it BEFORE the regression tests have to pass on a bigger surface.

**Output:** fill `spec.md` under `### §4.delta` with the shortstat numbers, the delta, and either "advance to BUILD" or "halt — see options 1/2/3 above".

**What it looks like:**

Quick check: is the diff I'm shipping the smallest one that does the job?

Example: *"`git diff main...HEAD` is +120 lines / -8 lines across 4 files. I scanned it: no unrelated refactors, no whitespace-only renames, no auto-format churn. Every line traces back to an AC."* If I see noise (e.g. a 50-line whitespace re-flow) I clean it before opening the PR.

**End the turn with:**
- *On clean delta:* *"Diff is minimal (delta: $delta). Run `/next` to advance to BUILD — the agent will run the regression tests and apply the §3 approach."*
- *On positive delta:* *"⚠️ HALT — refactor grew by $delta lines. Reply with one of: `trim` (re-open §3), `switch` (this is feature work), `override <reason>` (genuine growth, captured)."*
