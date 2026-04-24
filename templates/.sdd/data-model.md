# Data Model

> Single source of truth for every entity, field, relation, and state transition in the project.
> Every feature's SPEC Section 5 references this file by entity name and proposes diffs that get applied here on user approval.
> Never duplicate schema elsewhere.

---

## Conventions

- **Types:** use language-agnostic names: `string`, `text`, `int`, `bigint`, `decimal(10,2)`, `boolean`, `timestamptz`, `uuid`, `json`, `enum(...)`. Map to your stack's actual types in migrations.
- **Constraints:** spell out `NOT NULL`, `UNIQUE`, `PRIMARY KEY`, `FOREIGN KEY → <table>.<field>`, `DEFAULT <value>`, `CHECK (<expr>)`.
- **State fields:** if an entity has a lifecycle, use an explicit `enum` type and list every valid transition.
- **Naming:** `snake_case` for fields, `CamelCase` for entity names.

---

## Entities

<!--
Template for each entity:

### <EntityName>

**Purpose:** <one line — what this entity represents in the domain>

**Fields:**
| name | type | constraints | notes |
|------|------|-------------|-------|
| id | uuid | PRIMARY KEY | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

**Relations:**
- belongs_to: <OtherEntity> via <field>
- has_many: <OtherEntity> via <field on the other side>

**State transitions** _(if applicable)_:
- `draft → pending → active`
- `active → archived`
- `any → deleted` (soft delete)

**Indexes:**
- `(field_a, field_b)` for <use case>

**Feature history:**
- Created by: `features/<id>-<slug>` (PR #N)
- Modified by: ...
-->

_(empty — first entity gets added here when a feature's SPEC Section 5 proposes one)_

---

## Cross-entity constraints

<!-- Things that can't live inside one entity's constraints block. Uniqueness across tables, referential integrity rules, business invariants. -->

_(empty)_

---

## Migration / rollout notes

<!-- For changes that affect existing data: backfill strategy, migration order, feature flag, downtime expectations. One entry per schema change. -->

_(empty)_
