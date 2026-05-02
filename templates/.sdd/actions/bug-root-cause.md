---
type: action
slug: bug-root-cause
tag: AGENT-LED
title: "§3 Root cause"
short_label: "Root cause"
steps:
  - { id: cause, action: "investigate the repro, propose a one-line root cause in plain English, get user confirmation", field: "§3.cause" }
used_by: [bug]
references: [bug-problem, bug-repro]
touches: []
trust: framework
budget:
  max_minutes: 30
  max_tokens: 5000
  max_commits: 1
requires_user_approval: false
---

Find why the bug happens and write it as one plain-English sentence the user can validate.

**Investigation is YOUR job.** Read the relevant code, trace the repro through it, find where reality diverges from expectation. Don't ask the user to debug — they reported a symptom; you find the cause.

**The output is 1-3 sentences max**, not a detailed analysis. One sentence is best when it fits; up to three is fine if the cause needs both the technical mechanism AND the user-visible consequence in plain English. Future-you reads §3 to remember "what was wrong"; the fix in §4 captures "what we did about it." Examples:

- *"`session.user_id` was set to `null` for users who signed up via magic-link because the auth callback didn't await the user-creation Promise before redirecting."*
- *"The Resend webhook handler treated `bounced` events as `delivered` because the event-type switch was missing the `bounced` case (default: 'delivered')."*
- *"`citext` collation was missing on the `email` column, so case-only-different signups (`Sam@x.com` vs `sam@x.com`) were treated as different users."*

**Plain-English first, technical signal second.** If the user is non-technical, lead with what's wrong in their language. The technical detail can follow in parens. *"Confirmation emails go to spam because we didn't add the SPF record (DNS setting that proves the email comes from us)."*

**Halt-on-uncertainty.** If you've investigated and you're not confident in the cause, say so. Don't guess. Three legitimate paths:
1. **More logging** — propose a one-commit branch that adds instrumentation, ships, waits for the bug to recur.
2. **Reproduce locally** — propose steps to get a local repro before guessing.
3. **Revert** — if the bug came from a recent change, revert that change and re-investigate.

**On confirmation.** The user replies with a one-line ack ("yes, that's the cause" / "no, the cause is X"). Update §3 with the agreed wording. This step does NOT use `requires_user_approval: true` — the *fix* is the load-bearing decision (locked in §4); root cause is a working hypothesis.

**Output:** replace the `- [ ] cause: …` step row under `### action: bug-root-cause` with `- [x] cause: <the 1-3 sentences>` (or a one-line summary with the full cause prose under the action heading if the sentences are long).

**What it looks like:**

Why is it happening — under the hood?

Example: *"The signup endpoint checks email with a regex BEFORE database connection. The 503 came from a separate retry-loop bug: when the regex throws on weird input, we accidentally retry forever and timeout. Fix is to wrap the regex check in try/catch and return a clean 400 on bad input."* I describe the cause in plain English, then propose the fix.

**End the turn with:** *"Reply `confirmed` if that's the right cause, or correct it. Then `/next` to draft the fix in §4."*
