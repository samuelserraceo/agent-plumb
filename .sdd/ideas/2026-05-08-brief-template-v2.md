# Brief template (v2) — for SDD project / feature intake

> **What this is.** A reusable template a non-technical founder can fill in (or paste from their head) to describe what they want to build. The SDD agent reads this once, grills any vague terms, summarises its understanding back, and uses it to PRE-FILL §3 user-stories, §4 ux-brief, §6 data-contract, §7 flows, §8 dependencies, §9 out-of-scope, §10 non-functional, and §11 acceptance-criteria.
>
> **Why this exists.** Replaces the §1 Problem 3-question shape (*"who has it / why-now / what-breaks"*) which Sam called *"startup-pitch BS"* during the F01 audit on 2026-05-08. Free-form intake is faster, more honest, and lets the agent do the structuring.
>
> **Source design.** Drafted 2026-05-08 from the F01 / pipelogic_v2 SPEC ceremony audit (transcript at `docs/pipelogic_v2_FD01_feedback.txt`). 14 sections grouped into 3 passes — most projects only need Pass 1.

---

## How to use this template

**Copy the headers below into a new markdown file.** Fill them in your own words. No jargon required — the agent will grill anything ambiguous.

- **Pass 1 (5 min)** — sections 1-6: the plain story. Greenfield projects often only need this.
- **Pass 2 (10 min)** — sections 7-10: continuity + rules. Skip if greenfield with no V1 and no locked tech.
- **Pass 3 (5 min)** — sections 11-14: process + scope. Skip if you don't have answers yet — agent will ask at relevant SPEC sections.

**Skill setup.** Save this template in another Claude window's `~/.claude/skills/<name>/` and run `/<name>` to interactively walk a non-technical user through filling it in. Output: a markdown file ready to paste into the SDD agent's `/start` flow.

---

# `<project or feature name>` — brief

## Pass 1 — the plain story

### 1. One-line summary

What this thing IS, in plain English. One sentence. No jargon.

> *Example: "PipeLogic V2 is a database canvas — log into /map, see every table as a card, click any card to inspect or edit its columns and rows."*

### 2. Why I'm building it

What I do today that's painful. What changes for me when this ships. Free-form prose; 1-3 short paragraphs.

> *Example: "Today I open Supabase Studio and hunt through a 50-table sidebar. Every time. I want a single visual canvas where every table is a card, and clicking a card opens its inside."*

### 3. Who'll use it (and how technical they are)

**Pick 1-2 specific personas, in plain English. Not "users".**

Then say where each persona sits on the **tech-literacy ladder**:

- **Non-technical** — *e.g. small-business owner; understands tables but not databases; never opens a terminal.*
- **App-savvy** — *e.g. ops staff; uses Notion / Airtable / Zapier; can copy-paste a SQL query into an admin panel.*
- **Power-user** — *e.g. solo founder coding alongside the AI; reads code; pushes back on architecture.*
- **Engineer** — *e.g. teammate; reviews PR diffs; opinionated on stack.*

> *Example: "Sam (single user). Power-user — codes alongside the AI, reads PRs by clicking preview deploys not by reading diffs. Maybe later: 5 indie founders, app-savvy. NOT for non-technical end-users — this is operator-only."*

### 4. What 'done' looks like — the clickthrough QA list

The moment I'd say *"yes it works"* on a preview deploy. List specific behaviours as `M1`, `M2`, `M3`, … These become §11 acceptance criteria almost verbatim.

> *Example:*
> - *M1: I can log in, land on /map, and see every public.\* table as a card.*
> - *M2: Each card click opens a panel with the table's columns + first 50 rows.*
> - *M3: Edit a value in the panel → persists to Postgres.*

### 5. What this should NOT do (yet)

Explicit non-goals. 1-5 bullets. Empty is fine.

> *Example:*
> - *OAuth login (Supabase magic link only for v1)*
> - *Multi-tenant (single tenant for v1)*
> - *Real-time collaboration*

### 6. Look + feel

Inspiration, screenshots, similar tools, brand vibe.

> *Example: "Like Excel meets Figma — dense info but clickable. Mobile not a target — desktop only. Reference: figma.com/<file> + screenshot at notes/inspiration.png"*

### 7. Documents attached

Paths or URLs to anything that should be read alongside this brief. Especially load-bearing when there's a Google Sheets formula or V1 schema dump the implementation must match — agent mines these for §6 data-contract pre-fill.

> *Example:*
> - *`~/Notes/topishop-current-schema.md` (existing tables)*
> - *`https://docs.google.com/spreadsheets/d/<id>` (the formula F01 must match)*
> - *`./docs/v1-architecture.md` (V1 system map)*
> - *`./brand-guidelines.pdf` (look + feel)*

Empty is fine for greenfield projects.

---

## Pass 2 — continuity + rules (skip if greenfield)

### 7. Carrying forward from a prior version (and why)

What V1 already evaluated and decided so V2 doesn't re-run those experiments. 1-3 bullets. Skip entirely if greenfield.

> *Example:*
> - *V1 evaluated Drizzle ORM and rejected it (introspection lag on schema changes). V2 sticks with raw `postgres.js`. See V1 ADR-0002.*
> - *V1 had a JWT-allowlist-bypass bug (proxy.ts trusted unsigned email claim). V2 inherits the fix: `supabase.auth.getUser()` always re-verifies.*
> - *V1 found pgBoss too heavy for cron-style work. V2 uses Railway-native cron only.*

### 8. Stack constraints (MANDATORY only)

What's already decided that this MUST fit into. Don't list "preferences" — only HARD constraints.

> *Example: "Vercel + Supabase Postgres. Supabase Auth already wired. Don't propose a different DB or auth provider."*

### 9. Locked rules — what the AI must NEVER violate

Cross-cutting rules that apply to every feature. **These land in `principles.md` and the agent re-reads them every session.** Critical for projects with strong opinions.

> *Example:*
> - *NEVER use an ORM. Raw SQL via `postgres.js` only. (V1 ADR-0002.)*
> - *NEVER trust an unsigned JWT claim. Auth re-verification on every server boundary.*
> - *NEVER read across tenants — every JOIN must include `tenant_id` in the ON clause.*
> - *NEVER ship user-facing copy with jargon, error codes, or SHAs. Plain English only.*
> - *NEVER use AI in product runtime. Dev-side only.*
> - *NEVER write to `public.*` schema — read-only contract with Topishop.*

### 10. Hard constraints from reality

Deadlines, budget caps, things that must not break.

> *Example: "Demo 2026-06-15. Free tier only across every service. Can't break the existing topishop.com cron jobs that read these tables."*

---

## Pass 3 — process + scope (skip if no answers yet)

### 11. What's in THIS ship vs later (with phase sequencing if known)

- **This PRD ships:** `<one-line>`
- **Later features (don't build yet, but here's the order I'd build them):** `<list with rough phase grouping>`

> *Example:*
> - *This PRD: F01 = log in + see /map with cards.*
> - *Phase 1 (foundation): F02 (panel + edit), F03 (CSV import).*
> - *Phase 2 (connectors): F04 (adapter pattern), F05 (Google Sheets), F07 (Baselinker).*
> - *Phase 3 (intelligence): F08-F12 (enrichment, rules, computed columns).*
> - *Phase 4 (visual + monitor): F13-F15 (joins UI, edge-case inbox, production monitor).*

### 12. How I sign off on work

How will I review what the agent built? Pick one or describe your own:

- **Diff review** — I read the code change line-by-line.
- **Preview deploy clickthrough** — I click around the preview URL on Vercel and tick boxes.
- **Staging smoke test** — I run scripted tests against a staging environment.
- **Production canary** — I ship to 1% of users and watch metrics.
- **Talk it through** — agent walks me through what changed in plain English.

> *Example: "Preview deploy clickthrough on Vercel. I never read PR diffs."*

This shapes §11 ACs (every AC must be checkable from the chosen sign-off surface — e.g. preview-deploy-clickthrough-checkable, not "the function returns the right type").

### 13. Anything weird / specific

Domain quirks, regulatory, integrations, gotchas.

> *Example: "All times Europe/Madrid. The 'orders_raw' table is materialised — querying it triggers a refresh. Stripe webhook signing key rotates monthly."*

### 14. Documents attached

Paths or URLs to anything that should be read alongside this brief. The agent will mine these for §6 data-contract pre-fill, especially when there's a validated formula or schema the implementation must match.

> *Example:*
> - *`~/Notes/topishop-current-schema.md` (existing tables)*
> - *`https://docs.google.com/spreadsheets/d/<id>` (the formula F01 must match)*
> - *`./docs/v1-architecture.md` (V1 system map)*
> - *`./brand-guidelines.pdf` (look + feel)*

---

## What the SDD agent does with this brief

When you paste/upload this filled-in brief into `/start --queued <feature-name>` (or the future `/start --brief=<path>`), the agent:

1. **Reads the whole brief** — Pass 1 minimum, Pass 2/3 if present.
2. **Grills any vague terms** per the §173/§174 protocol — *"You said 'all tables'. Including views? Including matviews? `pl_draft.*` schemas too?"*
3. **Summarises understanding** — *"Here's what I read. Confirm or tell me what to fix."* Single restate-block; not a 30-line wall.
4. **Pre-fills SPEC sections** from the brief:
   - §1 Problem ← prose from sections 1 + 2
   - §3 User stories ← personas from section 3 + behaviours from section 4
   - §4 UX brief ← look-and-feel from section 6
   - §6 Data contract ← entities derivable from section 4 (M1/M2/M3) + uploads from section 14
   - §7 Flows ← M1/M2/M3 walk-throughs from section 4
   - §8 Dependencies ← stack from section 8
   - §9 Out-of-scope ← non-goals from section 5
   - §10 Non-functional ← reality constraints from section 10
   - §11 Acceptance criteria ← clickthrough M1/M2/M3 from section 4
   - §12 Signoff steps ← from section 12 (sign-off surface)
   - `principles.md` ← locked rules from section 9
5. **Hands you the pre-filled spec.md** — you only fill the gaps the brief didn't cover. Most projects have ~3-5 follow-up questions instead of ~20.

Each pre-filled section still goes through the standard SPEC ceremony — agent proposes the pre-fill, you approve / adjust / reject. The brief is a **shortcut**, not a bypass: the moat (hash-locked sections, append-only decisions, manifest pin) still fires.

---

## Where the brief lives after intake

**For features:** `.sdd/<work-item-folder>/<id>-<slug>/brief.md` — committed alongside spec.md so the brief is auditable.

**For projects:** `.sdd/projects/<id>-<slug>/brief.md` — same shape, project-scoped.

The brief is **immutable** after `/start` — if your understanding changes, you don't rewrite the brief; you `/re-approve <section>` the affected SPEC section, and `decisions.md` records the change.

---

## Limitations (be honest)

- **The brief is a one-shot artefact.** It captures intent at one moment. If you discover a §1 misunderstanding at §6, the brief is stale; the spec is the source of truth.
- **Pass 1 alone is rarely enough for projects.** Sections 7 + 9 + 10 are where projects (vs single features) diverge. Pass them through anyway, even if you write *"none yet"*.
- **The agent CAN miss things in the brief.** The §171 refresher block re-quotes from spec.md §1, not from the brief — once §1 is approved, the brief's role is done.
- **Documents in section 14 are bounded.** Agent reads markdown, plain text, JSON, CSV cleanly. PDFs are spotty. Google Sheets needs the doc copied to a CSV first. Screenshots are read at the model's vision capability.

---

## Changelog

- **2026-05-08** — v2 draft. 14 sections (was 11). Added: locked rules, V1 carry-forward, audience tech-literacy ladder, sign-off mode, phase sequencing within "this ship vs later". Removed nothing. Source: F01/pipelogic_v2 audit.
- **2026-05-08** — v1 draft (proposed in chat, never saved). 11 sections.
