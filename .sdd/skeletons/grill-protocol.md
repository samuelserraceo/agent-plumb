# Grill protocol — interrogate the user's answer before recording it

> **Purpose.** USER-LED actions ask a question, the user answers, and the answer goes into spec.md. That's the easy path — and it's how the framework misses things. The user thinks they're being clear; the agent thinks the answer is concrete; nobody surfaces the vague term, the hidden assumption, the under-specified trade-off until it bites in BUILD or PROD. Closes [#173](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/173) (grill protocol) + [#174](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/174) (plain-English grill questions).

## When to grill

Fire AFTER the user's answer, BEFORE writing to spec.md. **Cap at 3 grill questions max per answer** — beyond that, the user feels interrogated, not helped.

Grill if the answer contains any of these markers:

1. **Vague qualitative terms** — *"intuitive"*, *"fast"*, *"secure"*, *"scalable"*, *"easy"*, *"clean"*, *"good UX"*, *"works well"*, *"feels right"*. None of these are testable. Push for the concrete shape.
2. **Hidden assumptions** — *"all tables"* (views? matviews? schema-qualified?), *"click a card"* (left/right/double/keyboard?), *"users sign up"* (new visitor? returning? OAuth?), *"export the data"* (which fields? format? size cap?).
3. **Under-specification** — answer doesn't pin down *what would falsify it*. *"It should be obvious"* — to whom, on what device, in how many seconds?
4. **Implicit trade-offs** — answer asks for two things that conflict. *"Fast AND comprehensive"* — which wins when they collide? *"Simple AND configurable"* — same.
5. **Compound answers** — answer bundles 2+ questions you can't tell apart. *"Users see the dashboard and edit it inline"* — that's two features; ask which is in-scope for this work-item.

## When NOT to grill

**Skip the grill on clean answers** — interrogating a concrete pick wastes the user's time and trains them to dread `/next`. Skip if:

- The answer is a name, number, or picked-from-list value: *"Sam"*, *"5"*, *"option B"*, *"Postgres"*.
- The answer is a direct quote of a §1-§3 prose chunk that's already approved.
- The action's prompt was binary go/no-go and the user said yes/no.
- The answer is a well-known concrete URL / library / service name with no scope ambiguity (*"Resend"*, *"Cloudflare Turnstile"*, *"Vercel"*).

If you grilled and the user answers identically, **don't re-grill** — record the answer and move on. The grill is a check, not a loop.

## Format (plain English, no jargon — closes #174)

Every grill question MUST:

- **Translate every technical term on first use** — per CLAUDE.md *"Non-technical user lens"*. Yes, even ones the agent thinks are common (*"TTL"*, *"cache"*, *"relation"*, *"matview"*, *"webhook"*, *"JOIN"*, *"polling"*).
- **Give a concrete example or analogy for each option offered.** Abstract patterns paralyze non-technical users. *Cache → screenshot. View → saved spreadsheet formula. Webhook → notification ping. TTL → "checks for new email every minute".*
- **Strip code fragments from question prose.** SQL, function signatures, file paths, type signatures. If a code shape is essential, put it in a fenced block; the question itself stays plain English.
- **End with "or describe in your own words"** — gives the user permission to answer outside the offered options.

## Five grill question types (use 1-3 per answer, not all five)

### 1. Restate to catch misinterpretation

> **You said: *"<their words>"*. I read this as: *<your one-line plain-English interpretation>*. Did I get that right?**

Always offered first when the user's answer has 2+ plausible readings. This sits inside CLAUDE.md's halt-on-ambiguity doctrine — the grill makes it mechanical for USER-LED actions specifically.

### 2. Interrogate vague terms

> **You said *"<vague term>"*. Concretely — to whom? Measured how? Compared to what?**

Examples (plain English):

- *"You said the page should be 'fast'. On a slow phone over 4G, what's slow enough to feel broken — 3 seconds? 5? 10?"*
- *"You said 'secure'. Against what? Someone guessing the URL? Someone who got hold of one user's password? A scripted attack?"*
- *"You said 'intuitive'. Imagine your mum opens this for the first time. What's the first thing she should be able to do without asking?"*

### 3. Surface hidden assumptions

> **You said *"<answer>"*. Two questions hide inside that: <question A> / <question B>. Which way do you want it?**

Examples:

- *"You said 'every signup gets a confirmation email'. Two questions hide inside that: do existing users who re-signup get a new email, or just new addresses? And does an invalid email address count as a signup or get rejected before the email step?"*
- *"You said 'show all tables'. In your database there are also things called 'views' (saved queries that look like tables) and 'materialised views' (cached saved queries). Want those too, or just real tables?"*

### 4. Push on under-specification

> **If we shipped this exact wording and it didn't work, what would the failure look like?**

Or, equivalently:

> **What would have to be true for this to be wrong?**

This forces a falsification anchor. *"It should be obvious"* doesn't survive this question — the user has to name the failure mode, which usually surfaces the real spec.

### 5. Force trade-off recognition

> **You want X AND Y. When they conflict, which wins?**

Examples:

- *"You said 'fast AND comprehensive'. If we have to pick — would you rather show 80% of the data in 1 second, or 100% in 5 seconds? Or describe in your own words how to balance them."*
- *"You want 'simple AND configurable'. When in doubt, do we lean simple (one obvious way) or configurable (a setting for everything)?"*

## What good looks like

✅ **Good grill (3 questions, plain English, surfaces real spec):**

> User said: *"the page should be fast on mobile."*
>
> 1. **Restate.** I read this as: *the first interactive moment on a mid-range phone shouldn't make Sam wait long enough to think it's broken.* Right?
> 2. **Interrogate vague.** Concretely — what's "long enough to think it's broken" for you? 1 second feels instant; 3 seconds feels slow but workable; 5+ seconds feels broken. Pick a number, or describe what it should feel like.
> 3. **Trade-off.** If hitting that number means we ship without animations, is that OK? Or is the animation worth a slower load?

❌ **Bad grill (jargon, abstract, paralysing):**

> 1. Define your TTI target (Time To Interactive) in milliseconds.
> 2. What's your acceptable LCP regression vs the baseline?
> 3. Will you accept Core Web Vitals degradation for visual richness?

The bad version reads like a Lighthouse audit. The good version reads like a colleague helping you make a real decision.

## Compatibility with existing doctrine

- **Halt-on-ambiguity (CLAUDE.md):** the grill makes halt-on-ambiguity mechanical for USER-LED actions. The behavioural cue still fires across all turns; this skeleton is the formalisation for spec capture specifically.
- **Adversarial review** (`templates/.sdd/actions/adversarial-review.md`): fires later, against the AGENT's draft. The grill protocol fires earlier, against the USER's input. Both are needed — different surfaces, different failure modes.
- **Multi-choice with free-form escape** (CLAUDE.md): grill questions inherit the "or describe in your own words" tail. Don't drop it.

## Mechanical enforcement

The lint at `templates/.sdd/scripts/lint-action-prose.sh` asserts every USER-LED + AGENT-LED-with-approval action references this skeleton. Removing the reference fails the lint at commit time. The protocol's prose quality (plain English, concrete examples) is reviewed by the user at PR-merge time — not by the lint, which would become heuristic theatre per Foundation 3.
