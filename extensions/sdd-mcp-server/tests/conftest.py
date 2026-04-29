"""Test fixture helpers — build a minimal but realistic .sdd/ tree.

Used by `test_queries.py`. We don't import pytest fixtures here (the suite
runs under stdlib `unittest`), but the file's name follows the framework's
convention so a future pytest run would also pick up these helpers.
"""

from __future__ import annotations

import os
import shutil
import tempfile


INDEX_MD = """# Project Index

**Active:** features/001-waitlist   [BUILD]   blocker: §11 acceptance-criteria

## In flight
<!-- Features currently being worked on. -->

- features/001-waitlist [BUILD] — public waitlist signup form

## Backlog
<!-- Queued features. -->

- features/002-admin-dash — internal admin panel for signups

## Shipped
<!-- Completed + merged. -->

- features/000-bootstrap — PR #1 — merged 2026-04-01 — repo skeleton + CI

## Live state

### Environments
- **Development (local):** http://localhost:3001
"""


SPEC_MD = """# 001-waitlist — Public waitlist

[PHASE: BUILD]

**Active blocker:** §11 acceptance-criteria

## PHASE: SPEC

### action: problem

- [x] who: founders launching pre-product
- [x] why-now: traffic ramp from launch tweet next week

### action: proposed-approach

- [x] approach: single-page form → Postgres row → Resend email

## PHASE: BUILD

### action: plan-decompose

- [x] decompose: 5 tasks identified

### action: build-task

- [x] task-001: form renders → tests/task-001.mjs
- [x] task-002: form validates email → tests/task-002.mjs
- [ ] task-003: form submission produces success state → tests/task-003.mjs
- [ ] task-004: signup row written to Postgres → tests/task-004.mjs
- [ ] task-005: confirmation email sent via Resend → tests/task-005.mjs

## PHASE: SHIP

### action: verify-test-run

- [ ] run: full suite green locally
"""


DECISIONS_MD = """# SDD Decisions Log

> Append-only event log.

<!-- entries below this line; do not edit existing lines, only append -->

## 2026-04-15T10:00:00Z  [001-waitlist]  feature/proposed-approach
Approved single-page form architecture with Resend for email and Postgres for persistence. Alternatives (Mailchimp embed, Firebase) rejected for cost and lock-in.
Hash: a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90

## 2026-04-20T12:30:00Z  [001-waitlist]  feature/phase-transition
Phase advance SPEC → BUILD. All §1–§12 sections approved; verification.json hash-pinned to manifest.

## 2026-04-28T16:23:00Z  [001-waitlist]  feature/acceptance-criteria
Approved AC1–AC8. AC6 tagged [PROD-ONLY] (real Cloudflare Turnstile token can't be tested locally).
Hash: deadbeefcafef00d0123456789abcdef0123456789abcdef0123456789abcdef
"""


PATTERNS_MD = """# Patterns & Cross-Feature Learnings

> Append-only.

---

## Architecture decisions

### Auth retry logic
When an auth provider returns 5xx, retry with exponential backoff up to 3 times, then surface the failure to the user with a "try again" CTA. Do NOT retry on 4xx.
Source: 002-login

### Email delivery batching
Resend rate-limits at 100/sec on the free tier. Queue confirmation emails in chunks of 50 with 1s spacing.
Source: 001-waitlist

---

## Coding conventions

_(empty)_

---

## Cross-feature regressions to watch

_(empty)_
"""


CONFIG_MD = """---
type: config
sdd_version: 0.10.2
playbooks_available: [feature]
default_playbook: feature
extensions: {}
parameters:
  budget:
    max_minutes: 5
---

# SDD project configuration
"""


CONFIG_MD_WITH_SEARCH = """---
type: config
sdd_version: 0.10.2
playbooks_available: [feature]
default_playbook: feature
extensions: {}
parameters:
  mcp:
    semantic_search:
      enabled: true
      provider: openai
      endpoint: http://127.0.0.1:1
      model: nomic-embed-text
      top_k: 5
      max_chunks_per_run: 1000
---

# SDD project configuration
"""


FEATURE_001_README = """# 001-waitlist

extends: 000-bootstrap

References:
- 002-login (uses same Auth retry logic pattern)
"""


def build_fixture_tree(root: str, *, with_semantic_search: bool = False) -> None:
    """Populate `root` with a minimal .sdd/ tree."""
    sdd = os.path.join(root, ".sdd")
    os.makedirs(sdd, exist_ok=True)
    os.makedirs(os.path.join(sdd, "features", "001-waitlist"), exist_ok=True)

    with open(os.path.join(sdd, "INDEX.md"), "w", encoding="utf-8") as fh:
        fh.write(INDEX_MD)
    with open(os.path.join(sdd, "decisions.md"), "w", encoding="utf-8") as fh:
        fh.write(DECISIONS_MD)
    with open(os.path.join(sdd, "patterns.md"), "w", encoding="utf-8") as fh:
        fh.write(PATTERNS_MD)
    config_text = CONFIG_MD_WITH_SEARCH if with_semantic_search else CONFIG_MD
    with open(os.path.join(sdd, "config.md"), "w", encoding="utf-8") as fh:
        fh.write(config_text)
    with open(os.path.join(sdd, "features", "001-waitlist", "spec.md"), "w", encoding="utf-8") as fh:
        fh.write(SPEC_MD)
    with open(os.path.join(sdd, "features", "001-waitlist", "README.md"), "w", encoding="utf-8") as fh:
        fh.write(FEATURE_001_README)


def make_temp_project(*, with_semantic_search: bool = False) -> "tuple[str, callable]":
    """Build a fresh tempdir-backed project. Returns (root, cleanup_fn)."""
    root = tempfile.mkdtemp(prefix="sdd-mcp-test-")
    build_fixture_tree(root, with_semantic_search=with_semantic_search)

    def cleanup():
        shutil.rmtree(root, ignore_errors=True)

    return root, cleanup
