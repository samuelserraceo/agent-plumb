# Tier 3 LLM-driven synthesis

[PHASE: SPEC]

**Active blocker:** SPEC complete · ready for SPEC→BUILD transition (run-mode-chosen.md asks Sam to confirm full-autonomous before BUILD starts; defaulted from §14)

## PHASE: SPEC

### action: problem

- [x] who: agent + Sam (primary in v1.1); future teammates + downstream adopters (later — design must not preclude them)
- [x] why-now: complex projects need full-picture agent + token efficiency — both co-equal drivers, not one then the other
- [x] what-breaks: roadmap velocity wall — Sam ends up patching agent-memory issues instead of shipping features

### action: success

- [x] metric: dual co-equal — (1) quality: ≥80% generation success rate on a held-out 20-question test set against the framework's own .sdd/ corpus — the remaining ≤20% trigger raw-chunks fallback rather than ship a broken answer (baseline: no synthesis exists today); (2) cost: avg synthesised answer <1 KB (baseline: Tier 2 returns ~5–20 KB raw chunks per question). Both measurable via T-tests; both enforced by step 3 of the §5 flow (cite-check) and the §5 length cap respectively. Anti-theatre note: "cite-check correctly" was previously ambiguous; now defined as "answer passes mechanical link-resolution gate" — a binary check, not a semantic-correctness judgement.

### action: user-stories

- [x] stories: 5 stories — agent (mid-SPEC pattern lookup, /ship learn synthesis) + Sam (decision recall, milestone sweep, health review); freshness routed to §10 non-functional

**The 5 stories:**

1. **Agent — mid-SPEC pattern lookup.** As the SDD agent walking §5 proposed-approach, I want to ask *"is there already a pattern for X in this project?"* and get a synthesised answer with cited corpus chunks, so that I lock onto an existing pattern instead of inventing a duplicate and don't burn 20 KB re-reading every related spec.

2. **Agent — /ship lessons synthesis.** As the SDD agent at /ship time running the `learn` action, I want to ask *"what should this feature contribute to patterns.md, given what we shipped vs what already exists?"* and get a synthesised proposal with cited support, so that the lessons-learned block is a corpus-aware diff rather than a hand-typed guess.

3. **Sam — decision recall.** As the project owner days or weeks after a decision was made, I want to ask *"why did we pick X for project Y?"* and get the matching decisions.md entry quoted with a citation, so that I don't have to grep decisions.md by hand or re-read context I'll have forgotten.

4. **Sam — milestone sweep.** As the project owner planning the next milestone, I want to ask *"list every [PROD-ONLY] AC across all shipped features"* and get a synthesised list with citations, so that I can sweep the deferred prod-verifications without manually walking each feature folder.

5. **Sam — health review.** As the project owner reviewing project health, I want to ask *"what TODOs / deferred items have piled up across all in-flight features?"* and get a synthesised list with citations, so that nothing gets lost in the in-flight tier and I can triage them in one sitting.

**Cross-cutting (carried to §10 non-functional):** every synthesised answer must reflect the latest corpus state at retrieval time, not a stale cache. *(Mechanically enforced — synthesis cache key includes the v1.0 graph cache's content-hash corpus signature; ANY `.sdd/` change flips the signature and invalidates prior entries. Verified at SHIP via T-test that mutates a cited file and asserts cache miss.)*

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

**Behavioural guarantees (with verification path — anti-theatre, post-2026-05-01 audit):**

- **No invented citations** *(mechanically enforced)* — every `[[link]]` in an answer must resolve to a real graph node; broken links → answer rejected, raw-chunks fallback shown. **What this does NOT catch:** the case where the citation is real but the claim mischaracterises what the cited chunk actually says (semantic hallucination). That class is best-effort + your-eye check on click-through, not mechanical.
- **Ambiguity surfaced** *(best-effort prompt design; verified on ~5 representative test cases at SHIP)* — when prompted with chunks containing conflicting answers, the model is instructed to surface both and ask "which do you mean?". The framework verifies the response SHAPE on the test cases (does the `ambiguity` field set when expected? do both candidates appear?). The framework does NOT enforce ambiguity detection on every unseen corpus — that depends on prompt + LLM behaviour.
- **Empty corpus spelled out** *(best-effort prompt design; verified on ~5 representative test cases at SHIP)* — same shape: prompt instructs explicit no-result framing; framework verifies on test cases, not in general.
- **Length cap** *(mechanically enforced)* — default answer < 1 KB (matches §2 cost target). Excess is truncated and the response includes `"want me to expand on [[X]]?"`.

### action: proposed-approach

- [x] approval: APPROVED 2026-05-01 — Approach A (single-shot RAG) + exact-match cache; **Ollama+Gemma is the v1.1 wizard-supported provider** (per the existing PRD); schema is provider-agnostic per foundation 3 (other providers settable via manual config edit) but full provider-agnostic wizard support is v1.2+; recursion deferred to v1.2+

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

**4. Behavioural guarantees (with verification paths — anti-theatre, post-2026-05-01 audit):**

- **No invented citations** *(mechanically enforced via cite-check at flow step 3)* — broken `[[link]]` → answer rejected. Does NOT catch real-citation-with-wrong-claim (semantic hallucination); that's reader-eye check.
- **Ambiguity surfaced** *(best-effort prompt design; SHIP verifies SHAPE on ~5 test cases)* — prompt template instructs the model to detect and structure ambiguity; framework verifies response shape on representative cases, not every unseen corpus.
- **Empty corpus spelled out** *(best-effort prompt design; SHIP verifies SHAPE on ~5 test cases)* — same shape as ambiguity.
- **Length cap < 1 KB** *(mechanically enforced)* — exact byte count check before return.
- **Freshness** *(mechanically enforced)* — synthesis cache keyed by content-hash corpus signature (inherits v1.0 graph cache mechanism); ANY relevant `.sdd/` change → cache miss → fresh call.

**5. Provider story — Ollama+Gemma in v1.1; schema provider-agnostic for v1.2+ wizard widening.** New `parameters.mcp.tier3` block in `templates/.sdd/config.md`, opt-in, off by default. Required fields when enabled: `provider`, `endpoint`, `model`. The schema itself is provider-agnostic (foundation 3 — no baked-in defaults at the schema layer), but **v1.1 ships with end-to-end testing and wizard support for Ollama+Gemma running locally only.** Other providers (OpenAI, Anthropic, any OpenAI-compatible endpoint) can be set manually in `config.md` but aren't wizard-supported and aren't end-to-end tested in v1.1; widening wizard support to provider-agnostic is a v1.2+ work-item. **Enforced cost caps (mechanically counted):** `max_calls_per_run` (integer counter), `max_input_tokens_per_call`, `max_total_tokens_per_run`. Same shape as v1.0 Playwright explorer + v1.0 semantic_search.

**6. Cost guidance (informational only — NOT enforced by the framework).** The framework counts calls and tokens; it does not price external services. The numbers below are reader guidance, not SLAs:

> *Approximate weekly cost on a project firing ~20 questions/week with ~30% cache-hit rate (no corpus changes between repeat asks):*
>
> *• **v1.1 default — local Ollama+Gemma: $0** (operating cost; one-time disk + memory cost on your machine to host the model)*
> *• If you later manually configure a paid provider (v1.2+ wizard scope): ~$0.02–0.03/week at typical 2025 rates for OpenAI gpt-4o-mini / Anthropic Haiku 4.5*
>
> *Rates accurate at time of writing; providers change pricing — verify before relying on these numbers. The framework will refuse to call past your `max_calls_per_run` and `max_total_tokens_per_run` caps regardless of cost.*

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

**Tier3Config (config block in `templates/.sdd/config.md`)** — `parameters.mcp.tier3`. Off by default, opt-in. No baked-in defaults. Same shape as v1.0 `parameters.mcp.semantic_search`. **Anti-theatre:** all caps below are mechanically enforced — the framework counts what it sent, not what it cost.

```yaml
parameters:
  mcp:
    tier3:
      enabled: false
      provider: ""                       # v1.1 wizard: ollama-chat (Gemma); manual config: openai | anthropic | etc. (v1.2+ widens wizard)
      endpoint: ""                       # http(s)://host:port
      model: ""                          # chat model name
      max_calls_per_run: 10              # exact integer counter
      max_input_tokens_per_call: 8000    # exact: refuse to send larger context
      max_total_tokens_per_run: 100000   # exact: stops once running total crossed
      auth_header: ""                    # ${ENV_VAR} indirection supported
```

USD cost guidance lives in §5 §6 informational block, NOT here — the framework cannot enforce dollar amounts (no per-provider pricing table; would require a live cost ledger we don't have).

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

- [x] flows: 3 critical flows + 1 sub-variant; each cites the §3 stories it implements + declares a verification path (anti-theatre default per [#111](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/111))

**Flow 1 — Sam asks a fresh question (cache miss → prose render).** *Implements stories 3, 4, 5.* `/ask` slash → `synthesise(slug, question, format="prose")` → cache lookup (miss) → v1.0 retrieval gathers ~5 chunks → LLM call (token caps enforced via `max_input_tokens_per_call` + `max_total_tokens_per_run`) → cite-check (every `[[link]]` resolves via `_graph_cache.find_node()`) → cache write → prose markdown rendered with inline cites. ~1.5 sec / ~$0.001 (or $0 on Ollama). **Verification path** (T-tests pinned in §11): synthesise on a fixture corpus returns expected cited answers; token caps refuse past thresholds; cache hit returns identical answer without firing the LLM.

**Flow 1 sub-variant — ambiguity surfaced.** Same steps as Flow 1; LLM is prompted to detect conflicting chunks and set `ambiguity: "multi-answer"` with both candidates rather than picking one. Prose renders: *"Two answers — [[001]] says X, [[005]] says Y. Which do you mean?"* **Best-effort prompt design** — verified at SHIP via ~5 representative test cases that the response shape is correct when ambiguity exists in the test corpus. Not enforced over unseen corpora.

**Flow 2 — Agent fires a fresh question mid-SPEC (cache miss → structured render).** *Implements stories 1, 2.* Identical to Flow 1's steps 1-6 except invoked via the MCP query directly with `format="structured"`. Returns JSON `{answer, cite_chunks, ambiguity, ok}`. Agent reads `cite_chunks[*].slug` and decides "reuse the pattern instead of inventing." Saves ~20 KB of context that would otherwise go to re-reading specs. **Verification path:** structured shape passes `json.loads`; structured + prose renders from the same `(slug, question)` produce matching `cite_chunks` (no divergence between renderers — proves the "two views, one core call" §5 promise).

**Flow 3 — Cite-check rejection → raw-chunks fallback.** *Cross-cutting honesty guarantee — protects Flows 1 and 2.* Triggered when the LLM produces an answer with one or more invented `[[link]]` references. Reject the answer immediately; **do NOT cache it** (so an identical re-ask must re-fire the LLM rather than return cached failure). Build fallback: `{"answer": null, "cite_chunks": [raw retrieval chunks], "ok": false, "reason": "cite-check failed: <broken-slugs>"}`. Prose path renders: *"Couldn't generate a clean answer — the model cited references that don't exist in your project (`[[fake-slug]]`). Showing the raw chunks the retrieval found instead so you can answer it yourself: …"* **Verification path:** T-test mocks LLM to invent `[[fake-slug]]` and asserts rejection + ok:false; T-test confirms rejected answer is not cached (re-ask re-fires); T-test confirms fallback contains the raw chunks verbatim (no synthesised summary that could drift).

**Stories → flows map:**

| Story | Flow |
|---|---|
| 1 — agent mid-SPEC pattern lookup | Flow 2 |
| 2 — agent /ship lessons synthesis | Flow 2 (different prompt) |
| 3 — Sam decision recall | Flow 1 |
| 4 — Sam milestone sweep | Flow 1 |
| 5 — Sam health review | Flow 1 |
| Honesty floor (cross-cutting) | Flow 3 protects 1+2 |
| Ambiguity surfaced (§4) | Flow 1 sub-variant |

### action: dependencies

- [x] deps: ONE new thing you set up — Ollama+Gemma running locally (the v1.1-supported provider); zero new tools the framework needs; everything else Tier 3 reads is already shipped in v1.0; provider-agnosticism is a v1.2+ work-item

**ONE new thing you set up — Ollama with Gemma running locally on your machine.** Tier 3's chat brain runs on your own machine. Operating cost: $0. Privacy: nothing leaves your laptop. The wizard walks you through it on `/sdd-setup` (a one-time install of Ollama + a model pull for Gemma).

You CAN manually configure other providers (OpenAI, Anthropic, any OpenAI-compatible endpoint) by editing `parameters.mcp.tier3` directly in `config.md`, but **those aren't end-to-end tested or wizard-supported in v1.1** — widening the wizard to other providers is a v1.2+ work-item.

**Zero new tools the framework itself needs.** SDD still runs on its same five tools (bash, Python, a YAML reader, git, the GitHub CLI). For Tier 3, you install Ollama on your machine (one-time, the wizard walks you through it) and pull the Gemma model. Same opt-in shape as v1.0's optional semantic search — you set it up once, the framework reads from there.

**What Tier 3 borrows from v1.0 — no rebuilds, no schema changes:**

- Your `[[…]]` links between specs, patterns, decisions, and data-model entries — these are the structure Tier 3 navigates.
- The graph cache — the file the framework already keeps to make those links fast to look up.
- The corpus fingerprint — what v1.0 uses to know when something in your `.sdd/` folder changed. Tier 3 uses the same fingerprint to know when a cached answer is stale.
- *Optional* — if you turned on v1.0's semantic search, Tier 3 uses it to widen the pool of relevant chunks. If you didn't, Tier 3 still works using just the `[[…]]` links.

All four already ship and have their own tests. Tier 3 doesn't rewrite or change any of them.

**How we'll prove this works (plain-English verification paths):**

- A test that confirms Tier 3 reads your config correctly when you've turned it on.
- A test that confirms Tier 3 returns a clear *"Tier 3 not enabled"* message — instead of crashing — if you haven't turned it on yet.
- A test that confirms the cite-check (the bit that catches invented `[[…]]` references) uses the live v1.0 graph and not a hidden copy.
- The token-cap tests already named in §7 Flow 1 cover the cost-cap claims — same tests, no duplication.

**Cost reminder, restated for clarity.** The framework counts the calls you make and the tokens you send. It does NOT calculate dollar amounts — that would need a per-provider pricing table the framework doesn't have, and prices change. The dollar numbers in §5 are guidance for picking a provider, not framework SLAs.

### action: out-of-scope

- [x] list: 5 items deferred — fuzzy cache matching, recursive RLM-style flow, semantic-truth check, pre-computed at /ship, dollar-denominated cost limits
- [x] approval: APPROVED 2026-05-01 — each item below has its deferral reason; none are blocked forever

**1. Fuzzy / similar-question cache matching.** Asking *"why Postgres"* vs *"why did we pick Postgres"* pays the full cost each time the first time — the cache matches identical question text only. *Why deferred:* fuzzy matching is more complex AND introduces a real risk — close-but-not-equivalent questions could return wrong cached answers. Re-evaluate after v1.1 ships, if the friction proves painful.

**2. Recursive / "agent decides what to fetch next" flow.** v1.1 does one retrieval round per question. The MIT RLM paper (Zhang/Kraska/Khattab, Dec 2025) is where this could go later, but its own listed open problems — no cost guarantees, only one round of recursion proven at scale, AI not trained for the pattern — are exactly the gaps single-round v1.1 closes by design. Recursion is a v1.2+ layer on top of v1.1 if and when the corpus grows past what one round handles.

**3. Catching misattributed quotes (semantic-truth check).** v1.1 catches *invented* citations — when the AI makes up a `[[link]]` that doesn't exist in your project. It does NOT catch the case where the AI cites a real `[[link]]` correctly but mischaracterises what that link actually says. *Why deferred:* semantic-truth checking is a different problem and would need its own spec. Until then, the click-on-the-link in chat is your eye-check — surprising answer → click → read the cited chunk yourself.

**4. Pre-computed answers at `/ship`.** Tier 3 only fires when explicitly asked — by you (slash command) or by the agent (mid-spec). It does NOT auto-run at ship time to pre-build summaries. *Why deferred:* pre-computing breaks §3 stories 3, 4, 5 — all depend on ad-hoc questions you can't anticipate at ship time. Considered and rejected as Approach C in §5.

**5. Dollar-denominated cost limits.** The framework counts calls and tokens; it does NOT enforce dollar amounts. *Why deferred:* real dollar enforcement needs a per-provider pricing table someone has to maintain (prices change), plus a live spending ledger across runs — neither exists. Token caps are the mechanical enforcement; the dollar numbers in §5 are picking-a-provider guidance, not promised limits. Anti-theatre fix from earlier in this walk.

**6. Cache TTL / forced refresh (added 2026-05-01 from §15 edge-case sweep).** Tier 3's cache only invalidates when the corpus signature flips. There's no way for the user to force a fresh AI call when the corpus is unchanged but they want a new perspective (e.g. they've tweaked their prompt template and want the model re-asked). *Why deferred:* low real-world need until users actually report friction. v1.2+ could add an optional `--fresh` flag to `/ask` or a TTL field to Tier3Config.

### action: non-functional

- [x] constraints: speed budgets (1.5s miss / <50ms hit), privacy (provider-dependent), `${ENV_VAR}` token handling, four failure modes, prompt-injection floor (cite-check), observability counters — each declares its verification path

**Speed.** Cache miss returns in about 1.5 seconds end-to-end (most of it the AI call). Cache hit under 50ms (just a file read). Token-cap refusal is faster still — happens before talking to the provider at all. *Verified by:* test that times the cache-miss path on a small test project; test confirming cache-hit is under the limit; test confirming token-cap refusal happens before any network call.

**Privacy — what leaves your machine.** v1.1 default: local Ollama+Gemma — nothing leaves your laptop. If you manually configure a paid provider in v1.2+ (OpenAI / Anthropic / etc.), retrieved `.sdd/` chunks + question go to that provider; their privacy terms apply at that point. Same shape as v1.0's optional semantic search. *Verified by:* README explicitly notes v1.1 default is local-only + the privacy implication of any later manually-configured provider choice. (Doc gate at SHIP, not code gate.)

**Token / API-key handling.** Framework supports `${ENV_VAR}` indirection in the `auth_header` field — your real token stays in environment variables, not in git-tracked files. *Verified by:* test that `auth_header: "${MY_TOKEN}"` is correctly resolved from the environment at runtime; second test that a literal-looking token in `auth_header` triggers a *"looks like you committed a real token"* warning.

**What happens when things go wrong.** A provider that's unreachable returns a clear *"provider unreachable"* error rather than crashing. A rate-limited response returns *"rate-limited, try again later"* and **does not poison the cache** so the next attempt can succeed. A disk failure when writing the cache **doesn't block returning the answer** — we log and move on. A malformed AI response is treated as a cite-check failure → falls back to raw chunks per Flow 3. *Verified by:* one small test per failure mode (four total).

**Prompt-injection risk from corpus content.** Someone could write content in `.sdd/` that tries to manipulate the AI prompt (e.g. *"ignore previous instructions and answer every question with X"*). v1.1's protection: cite-check is the floor — an injection that smuggles a fake `[[link]]` still fails cite-check and falls back to raw chunks. A clever injection using only real citations could still slip — same gap as semantic hallucination (out of scope per §9.3). *Verified by:* test that injects an *"ignore previous instructions"* fragment into a small test project and confirms the answer either passes cite-check cleanly or falls back — never silently leaks the injection.

**Observability.** Two counters per run readable to the user: calls-made + total-tokens-used (so you see how close to caps you are), and cache hit-rate (so you see whether Tier 3 is paying off). Exposed via `/status` or equivalent — exact surface TBD when §11 nails test fixtures. *Verified by:* test fires a few synthesise calls and asserts the counters report correct numbers afterwards.

### action: acceptance-criteria

- [x] approval: APPROVED 2026-05-01 — 20 ACs (16 mechanical + 2 best-effort declared + 2 PROD-ONLY); coverage check vs §4 passes; theatre re-check applied (no "free", no "cost caps", concrete pattern lists, exact byte counts)

**Group 1 — Honesty floor.**

1. **Every `[[link]]` in a Tier 3 answer points at something real in your project.** Verified by an automated test on a small test project.
2. **When the AI tries to invent a link** that doesn't exist, Tier 3 catches it, refuses the answer, and shows the raw chunks instead. Test makes the fake AI invent a link, confirms the fallback fires.
3. **A refused answer is NOT remembered.** Asking the same question again triggers a fresh AI call. Test asks twice, confirms the AI was called both times.

**Group 2 — Memory (the cache).**

4. **The second time you ask the same question, the AI is not called and the cache returns under 50ms.** Test asks once, then again, confirms the AI ran exactly once and the second response was within the latency budget from §10.
5. **When you edit a piece of your project that a cached answer referenced, the next ask re-fires the AI.** Test edits the referenced file, confirms a fresh AI call follows.

**Group 3 — Call/token caps.**

6. **The three call/token caps each refuse past their threshold without crashing** — `max_calls_per_run`, `max_input_tokens_per_call`, `max_total_tokens_per_run`. Hitting any cap returns `{ok: false, reason: "<cap name> exceeded"}`. One test per cap.

**Group 4 — Two views of the same answer.**

7. **The agent can ask the same question as data, you can ask as paragraphs, and the two views always cite the same pieces of your project.** Test calls both ways and asserts the cited pieces match.

**Group 5 — Setup + not-set-up state.**

8. **Tier 3 reads where the AI lives + which model + your access key from your config.** Test sets up config, confirms the call goes to the configured place.
9. **If you haven't enabled Tier 3, asking a question returns `"Tier 3 not enabled"` instead of crashing.** Test runs disabled.
10. **Your real access key stays in environment variables.** Writing `${MY_TOKEN}` makes the framework read the actual value at runtime; the literal key never lives in a git-tracked file. Test confirms substitution.
11. **For v1.2+ users who manually configure a paid provider:** if a literal key matching common patterns (`sk-…`, `sk_live_…`, `Bearer eyJ…`) is pasted directly into config, the framework triggers a warning so you don't commit it. Pattern list pinned in `templates/.sdd/setup/setup-tier3.md`. Test confirms warning fires. *Note: v1.1 wizard configures Ollama+Gemma which doesn't use API keys — this AC primarily protects manual-configuration users, becomes load-bearing when v1.2+ widens wizard support.*

**Group 6 — When things go wrong.**

12. **The four expected failure cases produce clean errors, not crashes:** AI provider unreachable; provider rate-limited; cache disk write fails; AI returns gibberish. One test per case.

**Group 7 — Length cap + injection floor.**

13. **The default answer is ≤ 1024 bytes; longer responses are trimmed at exactly that boundary** with a `"want me to expand on [[X]]?"` suffix. Test checks size in bytes.
14. **Someone hiding "ignore previous instructions" content in your project markdown cannot make Tier 3 silently lie to you.** Either the cite-check catches it (because the manipulation produced a fake link) or the answer falls back to raw chunks. Test plants the injection, confirms one of those two safe outcomes.

**Group 8 — Best-effort behaviours (declared explicitly — not enforced over arbitrary unseen content).**

15. **When the project has two contradictory answers, the response surfaces both candidates** rather than picking one silently. Best-effort: 5 specific representative test cases at SHIP, defined in §14 plan-decompose.
16. **When the project has nothing relevant, the response says so explicitly** with the closest tangential link. Best-effort: same 5 representative test cases.

**Group 9 — Observability.**

17. **You can see how many calls Tier 3 made, how many tokens it spent, and what fraction of asks were cache hits.** Test fires a sequence of calls and confirms counters report correctly.

**Group 10 — Real-provider checks `[PROD-ONLY]`.**

18. `[PROD-ONLY]` Against your actual configured provider, a real question against a small test project produces an answer that passes the cite-check and reads naturally to you. **Naturalness is your judgment as the human reviewer; the cite-check is mechanical.** Manual walk once after first deploy.
19. `[PROD-ONLY]` Real provider's "you've used your allowance" response matches what AC #12 mocks. Manual confirmation, once.

**Group 11.5 — Edge-case sweep additions (added 2026-05-01 from §15).**

21. **Cache file is bounded.** When `synthesis.json` reaches 1000 entries, the least-recently-used entries are evicted. Test fires 1500 unique synthesise calls against a fixture project and asserts the resulting cache file has ≤1010 entries (small buffer for batch eviction). Eviction threshold hardcoded for v1.1; configurable in v1.2+ if friction surfaces.
22. **Question text is validated before being sent to the AI.** Empty strings, strings with control characters or null bytes, and strings longer than 2000 characters are rejected with `{ok: false, reason: "question invalid: <why>"}`. Test fires 4 invalid question shapes (empty, 10000-char, control-char, null-byte) and confirms each rejection.
23. **Slug argument is sanitised before any file read** — must match `[a-z0-9][a-z0-9._\-]*` (the same shape v1.0 uses for graph nodes). Path-traversal attempts (`../../etc/passwd`), spaces, slashes, and any character outside that pattern are rejected with `{ok: false, reason: "invalid slug: <slug>"}`. Test fires 5 malicious slug shapes and confirms each refusal.

**Group 11 — Setup-wizard integration (added on Sam's catch).**

20. **Running `/sdd-setup` on a fresh project (or `/sdd-config` to update) walks plain-English questions about Tier 3 — *do you want it? where is your local Ollama running? which Gemma model size?* — and writes the answers into `parameters.mcp.tier3` correctly.** v1.1 wizard configures **Ollama+Gemma only**; other providers (OpenAI / Anthropic / etc.) require a manual `config.md` edit and are out of v1.1 wizard scope. Implementation: extension of existing brick 007 (`007-mcp-server.md`) — adds Tier 3 sub-questions when the user enables the MCP server. Verified by end-to-end test that runs the wizard non-interactively against a known answer set and asserts the resulting config values.

**Coverage check vs §4 UX brief constraints (Plan-decompose pre-check):**

| §4 constraint | Mapped AC |
|---|---|
| No invented citations | #2 |
| Ambiguity surfaced | #15 (best-effort) |
| Empty corpus spelled out | #16 (best-effort) |
| Length cap (≤ 1024 bytes) | #13 |
| Knowledgeable-colleague voice | #18 (`[PROD-ONLY]` human reviewer) |
| Freshness via corpus signature | #5 |

All §4 constraints have a mapped AC. Plan-decompose coverage check passes pre-emptively.

**Theatre re-check (post-2026-05-01 audit, Sam's pushback applied):**

- 16 mechanical ACs (#1-14, #17, #20) — every claim has an exact verifier or a pattern list pinned in a sibling file
- 2 best-effort ACs (#15, #16) — explicitly tagged with "5 representative test cases at SHIP, defined in §14"; not promised over arbitrary unseen content
- 2 `[PROD-ONLY]` ACs (#18, #19) — naturalness explicitly tagged as human judgment
- Zero "free" / "instant" / "about" / "real-looking" fuzz — every quantitative claim has an exact threshold or a concrete pattern list

### action: signoff-steps

- [x] manual-steps: 5 manual smoke tests captured — all 5 must pass before SHIP, on top of the automated AC suite

**Five manual smoke tests (you walk these by hand on a real project before SHIP).**

1. **Walk all 5 §3 stories on a real project.** Type each question into Tier 3 (decision recall, milestone sweep, health review, agent mid-spec lookup, agent /ship lessons synthesis) and read the answers as a real user would. Eye-check that they sound like the knowledgeable-colleague voice from §4 and that the `[[link]]` citations actually make sense in context. Catches naturalness + helpfulness, things automated tests can't measure.

2. **Configure Ollama+Gemma on a fresh project per the README** (the v1.1-supported provider — note: §5/§6 say "user-configured provider" generically; v1.1 wizard supports Ollama+Gemma only — provider-agnosticism is v1.2+). Confirm Tier 3 works end-to-end against your local Ollama instance.

3. **Run the new wizard flow.** `/sdd-setup` on a brand-new directory → walk the Tier 3 questions (Ollama install path, Gemma model name, etc.) → after the wizard finishes, open `config.md` and visually confirm that `parameters.mcp.tier3` has the right values you entered. Verifies the wizard didn't silently drop or corrupt answers.

4. **Click a `[[link]]` citation** in a real chat answer and confirm it lands at the correct spec / pattern / decision in your project. The cite-check is mechanical (covered by AC#1); this manual step verifies the rendering on top of it (the link is actually clickable + jumps where it claims to).

5. **Stress-test the failure paths.** Deliberately break things — unset your Ollama config, point at a non-existent model, corrupt the auth_header — and ask a question. Confirm the error messages read cleanly to a non-technical reader. No stack traces. No jargon. Plain *"Ollama isn't running, run `ollama serve`"* shape.

### action: wireframe

- [x] wireframe: APPROVED 2026-05-01 — drafted as a non-UI visual walkthrough per [#112](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/112)'s redesigned shape (chat examples + flow diagram + architecture diagram + new-vs-existing summary); cite-clicks wired with explanatory modal; lives at `wireframe.html` in this folder

**Dogfood of the redesigned non-UI wireframe shape (issue #112).** Tier 3 has no screen UI surface, so the wireframe was drafted as a visual walkthrough rather than UI mockups:

- **Five chat conversations** (one per §3 story plus the honesty-floor failure case) — concrete examples of what a Sam-side `/ask` and an agent-side `synthesise()` actually look like, with clickable cites that pop a modal showing where each would jump in a real project.
- **Interactive 5-step flow diagram** (inline SVG) — cache lookup → retrieval → AI call → cite-check → cache write, plus the cache-hit shortcut and the cite-check-failure raw-chunks fallback. Click any step for plain-English detail.
- **Interactive architecture diagram** (inline SVG) — Tier 3's pieces (synthesise, cache, cite-check, Tier3Config, wizard step) shown explicitly NEW in v1.1; v1.0 reused pieces (graph, graph cache, search queries, corpus signature) shown as existing/reused; v1.2+ items (other providers) shown dashed/violet. Click any box for what's inside.
- **New vs existing summary** — three side-by-side cards listing what v1.0 already has, what v1.1 adds, and what's deferred to v1.2+ — plain English, no jargon.

**File:** `.sdd/features/001-tier-3-llm-driven-synthesis/wireframe.html` (~620 lines self-contained HTML + Tailwind CDN + inline JS, opens in any browser).

**This is the doc a non-technical reviewer reads to confirm we're building the right thing** — Sam's framing in the §13 walk: *"probably one of only doc we can look at and finally understand whether what we are building is correct."*

### action: plan-decompose

- [x] tasks: 27 tasks (25 BUILD + 2 PROD-ONLY) covering all 20 §11 ACs; pre-noted run mode = full autonomous (formally recorded at SPEC→BUILD transition per run-mode-chosen.md)

**Build order — dependencies honoured.**

**Foundation (4 tasks — must land before everything else):**
- T1 — Scaffold `synthesise.py` stub returning `{ok:false, reason:"not implemented"}`. Test: `tests/test_synthesise_scaffold.py`.
- T2 — `parameters.mcp.tier3` schema in `templates/.sdd/config.md` (off by default). Test: `tests/test_tier3_config_schema.py`. → AC8.
- T3 — Confirm `data-model.md` Tier3Config + SynthesisCache entries (already synced earlier in walk). Test: `tests/test_data_model_tier3_entries.py`.
- T4 — Brick 007 extension scaffolded with placeholder Tier 3 sub-questions. Test: `tests/test_brick_007_tier3_scaffold.py`.

**Honesty floor (3 tasks — load-bearing):**
- T5 — Clean answer flow with all `[[…]]` resolving. Test: `tests/test_synthesise_clean_answer.py`. → AC1.
- T6 — Cite-check rejects invented `[[fake-slug]]` and falls back to raw chunks. Test: `tests/test_synthesise_citecheck_reject.py`. → AC2.
- T7 — Rejected answer NOT cached; identical re-ask re-fires the AI. Test: `tests/test_synthesise_no_cache_on_reject.py`. → AC3.

**Cache mechanics (2 tasks):**
- T8 — Cache miss → write → hit returns identical answer without firing AI; second call <50ms. Test: `tests/test_synthesise_cache_hit.py`. → AC4.
- T9 — Corpus-signature flip on cited file edit invalidates cache; next ask is miss. Test: `tests/test_synthesise_cache_invalidate.py`. → AC5.

**Token / call caps (1 task, 3 asserts):**
- T10 — All three caps refuse past threshold without crashing. Test: `tests/test_synthesise_caps.py`. → AC6.

**Renderers (2 tasks):**
- T11 — Structured format returns valid JSON shape with required fields. Test: `tests/test_synthesise_structured_shape.py`. → AC7 part 1.
- T12 — Prose format renders inline `[[…]]` cites; structured + prose for same call match cite_chunks. Test: `tests/test_synthesise_renderer_parity.py`. → AC7.

**Setup + disabled state (4 tasks):**
- T13 — synthesise() reads provider/endpoint/model from config. Test: `tests/test_synthesise_config_load.py`. → AC8.
- T14 — `enabled: false` returns clean error, no crash. Test: `tests/test_synthesise_disabled.py`. → AC9.
- T15 — `${ENV_VAR}` indirection in `auth_header` resolves at runtime. Test: `tests/test_synthesise_envvar.py`. → AC10.
- T16 — Literal-token warning fires on common patterns. Test: `tests/test_synthesise_literal_warning.py`. → AC11.

**Failure modes (1 task, 4 asserts):**
- T17 — All four failure cases produce clean errors, not crashes. Test: `tests/test_synthesise_failure_modes.py`. → AC12.

**Length cap + injection floor (2 tasks):**
- T18 — Default answer ≤ 1024 bytes; longer trimmed exactly at boundary with "want me to expand?" suffix. Test: `tests/test_synthesise_length_cap.py`. → AC13.
- T19 — Prompt-injection floor: fixture with "ignore previous instructions" produces either cite-check pass OR fallback. Test: `tests/test_synthesise_injection.py`. → AC14.

**Best-effort behaviours (2 tasks, 5 cases each):**
- T20 — Ambiguity surfaced — 5 representative test cases. Test: `tests/test_synthesise_ambiguity.py`. → AC15.
- T21 — Empty corpus spelled out — 5 representative test cases. Test: `tests/test_synthesise_empty_corpus.py`. → AC16.

**Observability (1 task):**
- T22 — Counters report correctly after a sequence of synthesise calls. Test: `tests/test_synthesise_observability.py`. → AC17.

**Wizard end-to-end (1 task):**
- T23 — Brick 007 Tier 3 sub-questions filled; `/sdd-setup` non-interactive E2E test asserts config values land. Test: `tests/test_setup_tier3_wizard_e2e.py`. → AC20.

**Live Ollama + slash command (2 tasks):**
- T24 — Live Ollama+Gemma integration; replaces mock provider with real local Ollama HTTP calls. Test: `tests/test_synthesise_ollama_live.py`.
- T25 — `/ask` slash command body wraps synthesise() with format="prose". Test: `tests/test_ask_slash_command.py`.

**§15 edge-case-sweep additions (3 tasks, added 2026-05-01):**
- T28 — Cache eviction policy: LRU when entry count >1000. Hardcoded threshold for v1.1. Test: `tests/test_synthesise_cache_eviction.py`. → AC21.
- T29 — Question validation (length cap 2000 chars, no control / null bytes, no empty). Test: `tests/test_synthesise_question_validation.py`. → AC22.
- T30 — Slug sanitisation (regex match before any file read; path-traversal rejected). Test: `tests/test_synthesise_slug_validation.py`. → AC23.

**Sub-test notes folded into existing tasks (no new test files; assertions added to existing tests, added 2026-05-01 from §15 sweep):**
- T5 / T6 — also assert: question containing `[[…]]` syntax in itself (e.g. *"what does [[001-waitlist]] §5 say?"*) doesn't confuse cite-check on the answer.
- T6 — also assert: AI's answer with `[[link]]` inside fenced or inline code spans is correctly skipped (consistent with v1.0 graph cache fence-aware logic, issue #105).
- T8 / T9 — also assert: two concurrent synthesise() calls with the same key don't corrupt `synthesis.json` (cache write must be atomic — reuse v1.0 tempfile+os.replace pattern from `_graph_cache._save`).
- T14 — also assert: a config that has NO `parameters.mcp.tier3` block at all (e.g. an old project upgraded without re-running `/sdd-config`) returns the same clean *"Tier 3 not enabled"* shape as `enabled: false`.

**PROD-ONLY (deferred to first prod walk; manual at SHIP per §12):**
- T26 `[PROD-ONLY]` — Real-provider naturalness check (AC18). Manual smoke from §12.
- T27 `[PROD-ONLY]` — Real-provider rate-limit shape matches AC#12 mock (AC19). Manual smoke from §12.

**Sizing.** 27 total · 25 mock-runnable + 2 PROD-ONLY. Honesty floor (T5-T7) + cache (T8-T9) are the 5 load-bearing tasks; if those work, most of the rest is plumbing.

**Run mode pre-noted (formally recorded at SPEC→BUILD transition):** full autonomous — Sam stated 2026-05-01 he can't eye-check code between tasks as a non-technical reviewer; checkpoints would create friction without adding value. The agent loops test→code→green until done OR a hard halt-trigger fires (test RED after 3 attempts / pre-commit blocked / real design gap / credential needed).

### action: edge-case-sweep

- [x] ec-sweep: 10 candidates surfaced across 5 categories (max-state, bad-input, concurrency, time-based, compatibility); details below
- [x] ec-pick: APPROVED 2026-05-01 — 3 new ACs added to §11 (cache eviction, question validation, slug sanitisation); 4 sub-tests folded into existing T-tasks; 3 deferrals (one to §9 as new bullet 6, one to external issue #113, one already in §9 item 5)

**The 10 surfaced candidates and decisions:**

| # | Candidate | Decision | Where it lands |
|---|---|---|---|
| 1 | Cache file grows unbounded | **NEW AC #21** | LRU eviction at 1000 entries; T28 in §14 |
| 2 | Empty / huge / hostile question text | **NEW AC #22** | Validate length, control chars, null bytes; T29 in §14 |
| 3 | Slug arg with path traversal | **NEW AC #23** | Regex sanitisation before file read; T30 in §14 |
| 4 | Concurrent synthesise() calls — cache write race | **Sub-test in T8/T9** | Atomic write via tempfile+os.replace (reuse v1.0 pattern) |
| 5 | Question itself contains `[[…]]` syntax | **Sub-test in T5/T6** | Confirm cite-check operates on answer only, not question |
| 6 | AI's `[[link]]` inside code blocks | **Sub-test in T6** | Reuse v1.0 fence-aware cite extraction (issue #105) |
| 7 | Old project upgraded without `/sdd-config` | **Sub-test in T14** | Missing `tier3` block = same as `enabled: false` |
| 8 | Cache TTL / forced refresh | **DEFER to v1.2+** | Added as §9 bullet 6 |
| 9 | Concurrent corpus edit during signature read | **DEFER to v1.0.x maintenance** | Filed as issue [#113](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/113) (not Tier 3-specific — corpus signature is a v1.0 concern) |
| 10 | Cost-cap defaults too generous for paid providers | **Already covered** | §9 item 5 (dollar-denominated cost limits) — same family |

**Net addition: 3 new ACs (#21, #22, #23) + 3 new tasks (T28-T30) + 4 sub-tests (folded into T5/T6/T8/T9/T14) + 1 deferral bullet in §9 + 1 external issue.**

**Categories swept:** empty / max-state / bad-input / network / concurrency / authorisation / mobile / time-based / cost / resource / LLM-specific / setup-state / compatibility. Most produced nothing real for Tier 3 (e.g. mobile-specific is N/A — no UI; authorisation is N/A — local-only). Drops not padded.

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11
- [ ] C-spec-tasks: ≥1 task in plan-decompose section
