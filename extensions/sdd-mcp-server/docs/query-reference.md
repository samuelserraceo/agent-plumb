# Query Reference

The SDD MCP server exposes 6 named queries. Each is invoked over stdio in one of two protocol shapes:

- **Simplified SDD** (one JSON object per line): `{"query": "<name>", "args": {...}}` → `{"result": <data>}` or `{"error": "<reason>"}`
- **MCP-compatible JSON-RPC over stdio (simplified for SDD)**: `{"jsonrpc":"2.0","id":<n>,"method":"tools/call","params":{"name":"<query>","arguments":{...}}}` → standard MCP `tools/call` result with `content[0].type == "text"` carrying the JSON-encoded query result.

This page documents the simplified shape (it's the easier one to read). The MCP shape wraps the same answers.

> **Tip:** the BUILD phase typically uses three of these heavily — `get_active_step` (what's next), `get_pattern` (have we solved this before?), and `get_references` (does this feature extend another?). The other three are background queries the agent reaches for less often.

---

## get_active_step

**What's the active feature's current open step?**

Reads `.sdd/INDEX.md` for the `**Active:**` line, opens the named spec.md, finds the `[PHASE: X]` tag, and walks the matching `## PHASE: X` body for the first open `- [ ] <step-id>: <prompt>` row that isn't a work-item placeholder (AC<N> / T<N> / C-<N>).

**Args:** none.

**Sample request:**

```json
{"query": "get_active_step", "args": {}}
```

**Sample response (success):**

```json
{
  "result": {
    "feature_path": ".sdd/features/001-waitlist",
    "phase": "BUILD",
    "action": "build-task",
    "step_id": "task-003",
    "step_prompt": "form submission produces success state",
    "step_field": "tests/task-003.mjs"
  }
}
```

**Error shapes:**

- `{"error": "INDEX.md not found at <path>"}` — no .sdd/ tree.
- `{"error": "no active feature in INDEX.md"}` — `**Active:**` is `_(none)_`.
- `{"error": "no [PHASE: X] line in spec.md"}` — spec.md is malformed.
- `{"error": "no open [ ] step in PHASE: <X>", "feature_path": "...", "phase": "..."}` — phase is complete, ready to advance.

---

## get_by_tag

**Which features are in `<status>`?**

Reads `.sdd/INDEX.md` and parses the named level-2 section.

**Args:** `{"tag": "in-flight" | "shipped" | "backlog" | "blocked"}`.

**Sample request:**

```json
{"query": "get_by_tag", "args": {"tag": "in-flight"}}
```

**Sample response:**

```json
{
  "result": {
    "tag": "in-flight",
    "matches": [
      {
        "raw": "features/001-waitlist [BUILD] — public waitlist signup form",
        "id": "001-waitlist",
        "phase": "BUILD",
        "summary": "public waitlist signup form"
      }
    ]
  }
}
```

**Error shapes:**

- `{"error": "missing arg 'tag' — one of: ..."}`
- `{"error": "unknown tag '<tag>' — try one of: ..."}`
- `{"error": "INDEX.md not found at <path>"}`

---

## get_pattern

**Show me the `<slug>` pattern from patterns.md.**

Walks `.sdd/patterns.md` for a level-2 or level-3 heading whose slug matches. Slug match is loose (case-insensitive, hyphen/space-equivalent). Returns the heading's body plus a parsed `Source: <feature>` line if present.

**Args:** `{"slug": "<slug>"}`.

**Sample request:**

```json
{"query": "get_pattern", "args": {"slug": "auth-retry-logic"}}
```

**Sample response (success):**

```json
{
  "result": {
    "slug": "auth-retry-logic",
    "heading": "Auth retry logic",
    "level": 3,
    "content": "When an auth provider returns 5xx, retry with exponential backoff up to 3 times, then surface the failure to the user with a \"try again\" CTA. Do NOT retry on 4xx.\nSource: 002-login",
    "feature_source": "002-login"
  }
}
```

**Error shape (slug not found):**

```json
{
  "result": {
    "error": "pattern not found",
    "available": [
      {"slug": "architecture-decisions", "heading": "Architecture decisions", "level": 2},
      {"slug": "auth-retry-logic", "heading": "Auth retry logic", "level": 3},
      ...
    ]
  }
}
```

---

## get_references

**Who else mentions this feature/action/playbook slug?**

Walks `.sdd/` (skipping `.cache/`, `archive/`, `ideas/`) and reports every file that mentions the slug in:

1. YAML frontmatter `references:` lists
2. `extends: <slug>` declarations
3. `Source: <slug>` / `From feature <slug>` lines
4. Any other verbatim mention (fallback)

**Args:** `{"slug": "<slug>"}`.

**Sample request:**

```json
{"query": "get_references", "args": {"slug": "002-login"}}
```

**Sample response:**

```json
{
  "result": {
    "slug": "002-login",
    "referenced_in": [
      {
        "path": ".sdd/patterns.md",
        "line": 14,
        "context": "Source: 002-login",
        "kind": "source-line"
      },
      {
        "path": ".sdd/features/001-waitlist/README.md",
        "line": 5,
        "context": "- 002-login (uses same Auth retry logic pattern)",
        "kind": "mention"
      }
    ]
  }
}
```

`kind` values: `frontmatter:references`, `frontmatter:references-item`, `extends`, `source-line`, `mention`.

**Error shape:** `{"error": "missing arg 'slug'"}`.

---

## get_decisions_since

**What was decided after `<iso-date>`?**

Parses `.sdd/decisions.md` (append-only, level-2 sections shaped `## <ISO-Z>  [<work-item>]  <playbook>/<action>`) and returns entries whose timestamp >= `since`.

**Args:** `{"since": "<ISO-8601 UTC>"}`. Accepted shapes:

- `2026-04-28T16:23:00Z`
- `2026-04-28T16:23:00`  (Z auto-appended)
- `2026-04-28`           (T00:00:00Z auto-appended)

**Sample request:**

```json
{"query": "get_decisions_since", "args": {"since": "2026-04-25T00:00:00Z"}}
```

**Sample response:**

```json
{
  "result": {
    "since": "2026-04-25T00:00:00Z",
    "entries": [
      {
        "timestamp": "2026-04-28T16:23:00Z",
        "work_item": "001-waitlist",
        "action": "feature/acceptance-criteria",
        "summary": "Approved AC1–AC8. AC6 tagged [PROD-ONLY] (real Cloudflare Turnstile token can't be tested locally).",
        "hash": "deadbeefcafef00d0123456789abcdef0123456789abcdef0123456789abcdef"
      }
    ]
  }
}
```

**Error shapes:**

- `{"error": "missing arg 'since' — e.g. '2026-04-28T00:00:00Z' or '2026-04-28'"}`
- `{"error": "decisions.md not found at <path>"}`

---

## search (opt-in)

**Semantic search over `.sdd/`.**

By default this query is a stub — `.sdd/config.md` doesn't have a `parameters.mcp.semantic_search.enabled: true` block, so it returns the config shape the user needs to add.

When enabled, the real implementation will embed the query against the configured provider, retrieve top-k matching markdown blocks from `.sdd/`, and return them. **Today even when enabled the query returns a "deferred" message** — the schema is locked in, the network call ships in a follow-up.

**Args:** `{"query": "<natural-language search>"}`.

**Sample request:**

```json
{"query": "search", "args": {"query": "auth retry logic"}}
```

**Sample response (disabled — default):**

```json
{
  "result": {
    "error": "semantic search not configured — set parameters.mcp.semantic_search in .sdd/config.md",
    "config_shape": {
      "parameters": {
        "mcp": {
          "semantic_search": {
            "enabled": true,
            "provider": "<openai|anthropic|local-gemma|ollama|...>",
            "endpoint": "<https://... or http://localhost:port>",
            "model": "<embedding model name>",
            "top_k": 5
          }
        }
      }
    },
    "query": "auth retry logic"
  }
}
```

**Sample response (enabled, deferred):**

```json
{
  "result": {
    "error": "semantic search is configured but the implementation is deferred — the provider call ships in a follow-up commit",
    "configured": {
      "provider": "ollama",
      "endpoint": "http://localhost:11434",
      "model": "nomic-embed-text",
      "top_k": 5
    },
    "query": "auth retry logic"
  }
}
```

---

## Which queries the BUILD phase typically uses

During SPEC, the agent mostly reads spec.md content and asks USER-LED questions — fewer MCP queries fire. The phase that benefits most from this server is **BUILD**, which calls:

- `get_active_step` — once per `/next` call to learn what task to work on.
- `get_pattern` — when the active task touches a known cross-feature concern (auth, retries, email batching). Saves the agent from inventing a new approach when the team's already chosen one.
- `get_references` — when the user says "extend feature X" or the spec carries an `extends:` declaration. Maps the implication graph cheaply.

`get_by_tag` and `get_decisions_since` are background queries; the `/status` slash command and the SHIP phase use them to summarise context.

`search` is for fuzzy "have we discussed something like this?" questions — most useful in the SPEC phase when the user might be rediscovering an old debate.
