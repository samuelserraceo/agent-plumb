#!/usr/bin/env bash
# T211 — AC12 — NPM publish workflow at .github/workflows/publish-pi-adapter.yml
# fires on a release tag matching `pi-v*`, publishes
# extensions/sdd-pi-extension/ to npm as sdd-pi-adapter, and re-running
# on the same tag is a no-op.
#
# GitHub Actions can't be executed locally, so the test inspects the
# workflow YAML for shape:
#
#   A) File exists at the canonical path.
#   B) Trigger is `on: push: tags: [pi-v*]` (or `'pi-v*'`) — matches
#      §14 plan-decompose's release-tag contract.
#   C) Job runs `npm publish` from the extensions/sdd-pi-extension
#      directory (working-directory or `cd`) — proves the right
#      artifact is published, not the SDD repo root.
#   D) NPM_TOKEN is wired through the env or the publish step's auth
#      mechanism (npm requires authentication for publish).
#   E) Idempotence — re-running on the same tag is a no-op. Achieved
#      either by:
#        (i) a pre-publish guard that checks `npm view <name>@<version>`
#            and short-circuits if the version is already on npm, or
#        (ii) tolerating npm's natural E409 / EPUBLISHCONFLICT on
#             duplicate versions via `continue-on-error` / explicit
#             rc handling.
#      Either pattern satisfies the no-op contract; the test accepts
#      any of the documented shapes.
#   F) The job name or workflow name references the adapter so a human
#      reading the Actions tab can identify it without opening the file.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
WF="$FRAMEWORK_ROOT/.github/workflows/publish-pi-adapter.yml"

# --- A) File exists --------------------------------------------------
if [ ! -f "$WF" ]; then
  echo "FAIL: T211 — publish workflow missing at $WF"
  exit 1
fi

# --- B-F) Inspect YAML shape via python3 + PyYAML --------------------
python3 - "$WF" <<'PY'
import sys, re
import yaml

path = sys.argv[1]
errs = []

with open(path) as f:
    raw = f.read()

try:
    wf = yaml.safe_load(raw)
except Exception as e:
    print(f"FAIL: T211 — workflow YAML not parseable: {e}")
    sys.exit(1)

# YAML 1.1 quirk: `on:` becomes True without quoting. Tolerate both.
on = wf.get("on") if "on" in wf else wf.get(True)
if not isinstance(on, dict):
    errs.append('workflow `on:` must be a mapping with a `push.tags` filter')
else:
    push = on.get("push") or {}
    tags = push.get("tags") or []
    if not any(t == "pi-v*" or t.startswith("pi-v") for t in tags):
        errs.append(f'`on.push.tags` must include `pi-v*` (got: {tags!r})')

jobs = wf.get("jobs") or {}
if not jobs:
    errs.append("workflow has no jobs")

found_publish = False
found_idempotence = False
found_token = False
found_workdir = False

# Search the raw text for NPM_TOKEN — env wiring sometimes lands at
# top-level env, job env, step env, or as `with: token: ...` in a
# setup-node action. Token detection is best done on raw text.
if "NPM_TOKEN" in raw or "NODE_AUTH_TOKEN" in raw:
    found_token = True

# Walk all steps in all jobs.
for jname, job in jobs.items():
    steps = job.get("steps") or []
    job_wd = (job.get("defaults") or {}).get("run", {}).get("working-directory", "")
    for step in steps:
        run = step.get("run") or ""
        wd = step.get("working-directory") or job_wd or ""

        # Publish step: contains `npm publish` in its run script.
        if "npm publish" in run:
            found_publish = True
            # Working directory must point at the extension package.
            if "extensions/sdd-pi-extension" in wd or "extensions/sdd-pi-extension" in run:
                found_workdir = True

        # Idempotence: either a pre-check via `npm view ... version` /
        # `npm view ... versions` short-circuit, or explicit handling
        # of duplicate-version exit codes via continue-on-error /
        # `|| true` / `|| exit 0` / `EPUBLISHCONFLICT` text.
        if (re.search(r"\bnpm view\b.*\bversion", run) or
                step.get("continue-on-error") is True or
                "EPUBLISHCONFLICT" in run or
                re.search(r"npm publish.*\|\|\s*(true|exit\s+0)", run) or
                "already published" in run.lower()):
            found_idempotence = True

if not found_publish:
    errs.append("no step runs `npm publish`")
if not found_workdir:
    errs.append("`npm publish` not scoped to extensions/sdd-pi-extension/ (wrong artifact would publish)")
if not found_token:
    errs.append("NPM_TOKEN / NODE_AUTH_TOKEN not wired into the workflow (auth missing)")
if not found_idempotence:
    errs.append("no idempotence guard — re-running on the same tag would error spuriously instead of being a no-op")

# F) Workflow / job name references adapter for Actions-tab readability.
wf_name = (wf.get("name") or "").lower()
if "sdd-pi" not in wf_name and "pi-adapter" not in wf_name and "sdd pi" not in wf_name:
    job_names = " ".join((j.get("name") or k).lower() for k, j in jobs.items())
    if "sdd-pi" not in job_names and "pi-adapter" not in job_names and "sdd pi" not in job_names:
        errs.append("workflow / job name does not reference sdd-pi-adapter (hard to identify in Actions tab)")

if errs:
    print("FAIL: T211 — AC12 publish-pi-adapter.yml shape violations:")
    for e in errs:
        print(f"  - {e}")
    sys.exit(1)

print("PASS: T211 — AC12 publish workflow has pi-v* trigger, scoped npm publish, NPM_TOKEN wiring, and idempotence guard")
PY
