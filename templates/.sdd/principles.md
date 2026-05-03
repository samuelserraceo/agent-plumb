# Principles

Project-wide non-negotiable rules. The SDD framework auto-injects this file into the AI's context on every turn (alongside `INDEX.md`, the active spec, `stack.md`, `data-model.md`, and `patterns.md`), so principles you record here apply to every feature, bug, and refactor — not just the one in flight.

This is the SDD equivalent of an ADR (Architectural Decision Record) layer. Each principle is short, concrete, and explains WHY plus HOW. The AI reads them on every turn so design decisions don't drift.

> **What goes here vs. elsewhere:**
> - `principles.md` (this file) → **rules that apply across every feature** (e.g. "all dates UTC", "never store secrets in code").
> - `stack.md` → tech stack facts (services, providers, version pins).
> - `data-model.md` → entities and their fields.
> - `patterns.md` → lessons learned from past features.
> - `decisions.md` → audit trail of approvals and phase transitions.
>
> If a rule is genuinely cross-cutting and you want EVERY feature to obey it without re-deciding, it belongs here.

## Format

Each principle is a level-2 heading describing the rule, followed by **Why**, **How to apply**, and **Adopted** lines.

```markdown
## All dates stored in UTC

**Why:** consistency across services and timezones; avoids subtle bugs at DST boundaries.
**How to apply:** new code must use UTC for storage and comparison. Display-time conversion to local timezone happens at the UI layer only.
**Adopted:** 2026-05-03
```

Keep it short. If the explanation is more than 3-4 sentences per principle, you're probably writing a design document, not a principle — link to the design doc instead.

## Removing or amending principles

Principles that no longer apply should be **superseded** rather than deleted, so the audit trail stays intact. Append `~~` strikethrough around the heading and add a `**Superseded by:**` line pointing at the replacement (or `**Retired:** YYYY-MM-DD` if no replacement exists).

```markdown
## ~~All API responses use snake_case~~

**Superseded by:** "API responses use camelCase to match frontend conventions" (2026-08-12).
**Original adoption:** 2025-11-04.
```

## Scope

Principles bind the AI to a discipline. They don't replace human review — a contributor can still propose breaking a principle in a feature spec's §5 (proposed approach), but they have to argue WHY the principle doesn't apply to that specific case. The AI will surface the principle when the proposed approach contradicts it.

---

*This is a starter template. Replace this prose with your project's actual principles. The framework only checks that the file exists; the content is yours to write.*

## (No principles recorded yet)

When you adopt your first project-wide rule, replace this placeholder with the principle's heading + Why / How to apply / Adopted lines per the format above.
