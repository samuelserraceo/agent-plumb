# Tier 3 LLM-driven synthesis

[PHASE: SPEC]

**Active blocker:** §7 (flows)

## PHASE: SPEC

### action: problem

- [x] who: agent + Sam (primary in v1.1); future teammates + downstream adopters (later — design must not preclude them)
- [x] why-now: complex projects need full-picture agent + token efficiency — both co-equal drivers, not one then the other
- [x] what-breaks: roadmap velocity wall — Sam ends up patching agent-memory issues instead of shipping features

### action: success

- [x] metric: dual co-equal — (1) quality: ≥80% of synthesised answers cite-check correctly on framework corpus (baseline: no synthesis exists today); (2) cost: avg synthesised answer <1 KB (baseline: Tier 2 returns ~5–20 KB raw chunks per question)

### action: user-stories

- [x] stories: 5 stories — agent (mid-SPEC pattern lookup, /ship learn synthesis) + Sam (decision recall, milestone sweep, health review); freshness routed to §10 non-functional

**The 5 stories:**

1. **Agent — mid-SPEC pattern lookup.** As the SDD agent walking §5 proposed-approach, I want to ask *"is there already a pattern for X in this project?"* and get a synthesised answer with cited corpus chunks, so that I lock onto an existing pattern instead of inventing a duplicate and don't burn 20 KB re-reading every related spec.

2. **Agent — /ship lessons synthesis.** As the SDD agent at /ship time running the `learn` action, I want to ask *"what should this feature contribute to patterns.md, given what we shipped vs what already exists?"* and get a synthesised proposal with cited support, so that the lessons-learned block is a corpus-aware diff rather than a hand-typed guess.

3. **Sam — decision recall.** As the project owner days or weeks after a decision was made, I want to ask *"why did we pick X for project Y?"* and get the matching decisions.md entry quoted with a citation, so that I don't have to grep decisions.md by hand or re-read context I'll have forgotten.

4. **Sam — milestone sweep.** As the project owner planning the next milestone, I want to ask *"list every [PROD-ONLY] AC across all shipped features"* and get a synthesised list with citations, so that I can sweep the deferred prod-verifications without manually walking each feature folder.

5. **Sam — health review.** As the project owner reviewing project health, I want to ask *"what TODOs / deferred items have piled up across all in-flight features?"* and get a synthesised list with citations, so that nothing gets lost in the in-flight tier and I can triage them in one sitting.

**Cross-cutting (carried to §10 non-functional):** every synthesised answer must reflect the latest corpus state at retrieval time, not a stale cache. The graph cache is already content-hash invalidated at v1.0; Tier 3 must inherit that freshness guarantee. The spec must verify in SHIP that synthesis cannot serve stale answers.

### action: ux-brief

- [x] brief: feels like a knowledgeable-colleague you can ask anything about your project, with receipts; one core call with structured/prose views; inline [[…]] citations; ambiguity surfaced; empty results spelled out; <1 KB default length

**The chosen UX direction:** Tier 3 should feel like *a knowledgeable colleague you can ask anything about your project, who always shows their receipts.*

**Three concrete moments it produces (approved verbatim, 2026-05-01):**

1. **Sam asks** — *"Why did we pick Postgres for the waitlist?"* → *"Postgres was picked because the v1 schema is small enough to colocate with the app — you flagged this in [[001-waitlist]] about a month ago. Switching to a managed database came up in [[005-pivot]] but you parked it."*
2. **Agent asks (mid-SPEC)** — *"Is there already a pattern for retrying failed signups in this project?"* → structured data response (yes/no + citation) the agent reads directly. Same brain, different wrapping for the consumer.
3. **Sam asks** — *"What's deferred across all my features right now?"* → *"Three things deferred: cookie consent banner ([[002-checkout]]), Stripe webhook retry ([[004-billing]]), import CSV (parked, [[007-onboarding]]). Want me to expand on any of them?"*

**Three design choices that produce that feel:**

- **One core synthesise call, two views.** A single MCP query (likely named `synthesise`) with a `format: "structured" | "prose"` argument. Agent calls it with `format: "structured"` for direct consumption; the slash-command wrapper calls with `format: "prose"` for chat. Same LLM call, same cite-check, two thin renderers.
- **Inline `[[wiki-link]]` citations** in the prose path. Reuses v1.0's graph cache. Click to jump in editors that render Obsidian-style links; readable as text otherwise.
- **Knowledgeable-colleague voice.** Plain English, declarative, no "I think" hedging. Where the corpus is silent, say so explicitly.

**Behavioural guarantees (must verify in SHIP):**

- **No invention.** Every claim must point at a real `[[…]]` — graph cache verifies the link resolves, or the answer is rejected.
- **Ambiguity surfaced, not picked.** Two valid answers → *"two candidates — [[001]] says X, [[005]] says Y. Which do you mean?"*
- **Empty corpus spelled out.** No silent return. *"Nothing in your project covers that. Closest was [[X]] but tangential. Want me to broaden?"*
- **Length cap.** Default answer < 1 KB (matches §2 cost target). Expand-on-demand for deeper dives.

### action: proposed-approach

- [x] approval: APPROVED 2026-05-01 — Approach A (single-shot RAG) + exact-match cache; user-configured provider (no baked-in defaults); recursion deferred to v1.2+

**The locked design — Approach A + exact-match cache.**

**1. What Tier 3 actually does, in one sentence.** When you (or the agent) asks a question about your project, Tier 3 takes the relevant pieces of `.sdd/` markdown that v1.0's wiki-graph retrieval already returns, sends them to the language model you've configured with strict cite-only instructions, and returns the answer with `[[…]]` citations that resolve to real graph nodes.

**2. The five-step flow per question.**

```
Step 0 — CACHE LOOKUP        Key: (question, corpus signature)
                             Hit  → return cached (instant, $0)
                             Miss → continue
Step 1 — v1.0 RETRIEVAL      Graph + semantic search gather ~5 chunks (instant, $0)
Step 2 — LANGUAGE MODEL      User-configured provider; strict cite-only template
                             (~1 sec, ~$0.001 — or $0 on local Ollama)
Step 3 — CITE-CHECK          Every [[link]] resolves to real graph node
                             Broken → reject; show raw chunks instead
Step 4 — CACHE WRITE         on success (instant, $0)
```

**3. Two render formats from one core call.** The agent calls `synthesise(slug, question, format="structured")` and gets a JSON object with fields `answer`, `cite_chunks`, `ambiguity`, `ok`. The slash-command wrapper calls with `format="prose"` and renders inline `[[…]]` citations to chat. Same LLM call, same cite-check, two thin renderers — never two separate model calls.

**4. Behavioural guarantees (must verify in SHIP):**

- **No invention** — cite-check rejects any answer with a broken `[[link]]`
- **Ambiguity surfaced** — multiple valid answers → return both, ask the user to pick (don't silently choose)
- **Empty corpus spelled out** — *"Nothing in your project covers that. Closest was [[X]] but tangential. Want me to broaden?"* — never silent
- **Length cap** — default response < 1 KB (matches §2 cost target); expand-on-demand for deeper
- **Freshness** — synthesis cache keyed by content-hash corpus signature (inherits v1.0 graph cache mechanism); ANY relevant `.sdd/` change invalidates the cached answer

**5. Provider story — no baked-in defaults.** New `parameters.mcp.tier3` block in `templates/.sdd/config.md`, opt-in, off by default. Required fields when enabled: `provider` (`openai` / `anthropic` / `ollama-chat` / etc.), `endpoint`, `model`. Cost ceiling: `max_calls_per_run` and `cost_limit_usd`. Same shape as v1.0 Playwright explorer + v1.0 semantic_search — foundation 3 ("we never assume an external service").

**6. Cost math scaled to expected usage.** ~20 questions/week, ~30% repeats with no corpus changes (cache hits, $0). At OpenAI gpt-4o-mini: ~$0.02/week per project. At Anthropic Haiku 4.5: ~$0.03/week. Self-hosted Ollama: $0. **Per-project per-month ≤ $1** unless using a top-tier model.

**7. Two alternatives considered + rejected.**

| Alternative | What | Why not |
|---|---|---|
| **Lazy escalation** | Only call the LLM when v1.0 retrieval returns >K chunks | State-dependent answer shape; cost rises non-linearly with corpus growth; foundation 1 violation |
| **Pre-computed at /ship** | Synthesise per-feature summaries up front; no real-time LLM calls | Breaks §3 story 3 (unanticipated questions); breaks §3 stories 4+5 (cross-feature queries); couples Tier 3 to ship cadence |

**8. Future extension — not for v1.1.** `synthesise.py` is single-shot by design. An RLM-style recursive layer ([Zhang/Kraska/Khattab, MIT, Dec 2025](https://arxiv.org/abs/2512.24601)) could call this as its sub-LM in a v1.2+ work-item without rewriting the foundation — each recursive sub-call would still cite-check via the graph. That paper's own listed open problems (no cost guarantees, no async, depth=1 unproven at scale, training gap) are exactly the gaps single-shot v1.1 closes by design. v1.2+ layers recursion on top when corpus growth makes single-shot retrieval insufficient.

### action: data-contract

- [x] approval: APPROVED 2026-05-01 — two new framework-domain entities (SynthesisCache + Tier3Config); reads existing graph nodes + v1.0 query layer + corpus signature; data-model.md synced in same commit

**Two new framework-domain entities:**

**SynthesisCache (derived artifact, gitignored)** — lives at `.sdd/.cache/synthesis.json`. Cached answers from past synthesise calls. Invalidates lazily when corpus signature flips. Same shape pattern as v1.0 graph cache.

```json
{
  "version": 1,
  "entries": {
    "<sha256(question)>:<corpus_signature>": {
      "answer": "Postgres was picked because…",
      "cite_chunks": [{"slug": "001-waitlist", "path": "...", "line": 42}],
      "format_seen": ["structured", "prose"],
      "ambiguity": null,
      "created_at": "2026-05-01T14:39:15Z"
    }
  }
}
```

**Tier3Config (config block in `templates/.sdd/config.md`)** — `parameters.mcp.tier3`. Off by default, opt-in. No baked-in defaults. Same shape as v1.0 `parameters.mcp.semantic_search`.

```yaml
parameters:
  mcp:
    tier3:
      enabled: false
      provider: ""              # openai | anthropic | ollama-chat
      endpoint: ""              # http(s)://host:port
      model: ""                 # chat model name
      max_calls_per_run: 10
      cost_limit_usd: 0.50
      auth_header: ""           # ${ENV_VAR} indirection supported
```

**What Tier 3 reads (existing — no schema changes):**
- Graph-cache nodes (`features/<id>` / `pattern:<slug>` / `entity:<slug>` / `decision:<slug>`) — for cite-check
- v1.0 MCP queries (`get_neighbours`, `get_backlinks`, `search_within`, `search`) — for retrieval
- Corpus content-hash signature from `_graph_cache._file_signature` — for cache key + invalidation

**Two trivial alternatives rejected:**
- *Cache as SQLite* — adds a dependency; foundation 1 violation. JSON fits the realistic cache size (few MB).
- *Cache keyed by question only* — wastes valid entries on unrelated changes. Two-key (question, corpus_signature) keeps cross-edit valid entries warm.

**Relationships:**
- `Tier3Config` → `SynthesisCache`: config controls when the cache gets read/written
- `SynthesisCache` → graph-cache nodes: every `cite_chunks[*].slug` must resolve (cite-check enforces)

`data-model.md` synced in this commit with the two new entities.

### action: flows

- [ ] flows: draft 1-3 critical flows, each referencing the user story it implements

### action: dependencies

- [ ] deps: draft external services + pricing math scaled to success-volume targets

### action: out-of-scope

- [ ] list: What are we explicitly NOT building this round? 1-5 bullets, each: name + reason. Empty is fine.
- [ ] approval: user_approves

### action: non-functional

- [ ] constraints: draft performance, security, and compliance constraints

### action: acceptance-criteria

- [ ] approval: draft the acceptance criteria, run a constraint-coverage check vs §4, iterate, get approval

### action: signoff-steps

- [ ] manual-steps: What manual smoke tests do YOU need to do before SHIP, beyond the automated tests? 1-5 bullets.

### action: wireframe

- [ ] wireframe: draft wireframe.html — one screen per user story

### action: plan-decompose

- [ ] tasks: convert acceptance criteria into ordered build tasks (one test file per task)

### action: edge-case-sweep

- [ ] ec-sweep: draft
- [ ] ec-pick: ask

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11
- [ ] C-spec-tasks: ≥1 task in plan-decompose section
