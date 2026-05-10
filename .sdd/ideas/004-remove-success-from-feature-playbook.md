# Idea: Remove §2 Success from the feature playbook (lean on §11 only)

**Captured:** 2026-05-08
**Status:** captured

## What's the idea?

Drop the `success` action (currently §2 Success) from the feature playbook. The framework already has §11 Acceptance Criteria, which is the AI-verifiable success layer — the place where every claim must declare its `{verify-by: T-NNN}` annotation or be soft-tagged. §2 Success duplicates that purpose less rigorously: it asks for "metrics" (volume / speed / quality / engagement) that are usually market-level and unverifiable mechanically, ending up either as theatre or as soft-annotated cruft.

The change touches roughly 8-10 places in the framework:
- `.sdd/playbooks/feature.md` — drop `success` from action list
- `.sdd/actions/success.md` — retire
- `.sdd/scripts/start.sh` (or scaffold logic) — stop emitting §2 block
- `.sdd/CLAUDE.md` — drop §2 references
- The "unskippable" list in `/next.md` — drop §2 (currently mandatory)
- `docs/` walkthrough HTML — drop §2 step
- Framework regression tests — drop §2-presence assertions
- Already-shipped specs (001-007) — frozen, kept as historical record
- Numbering decision: leave §2 as a gap (§1 then §3) OR renumber (§3 → §2, §4 → §3, etc.)

## What problem might it solve?

Two real problems Sam observed mid-feature-008 (and previously in pipelogic):

1. **§2 produces theatre or anti-theatre cruft.** When the metric isn't AI-verifiable (which it usually isn't for market-shaped questions), the writer either fakes a number that can't be checked, or annotates it `{best-effort: Sam at SHIP}` to placate the lint. Neither outcome is useful. SDD's whole point is "everything specced is verifiable" — §2 violates that by design.
2. **§2 burns user attention on the wrong question.** Spec-driven dev users want to tell the AI "this is what success looks like and you can check it yourself." That's §11. §2 distracts users with a market-shaped framing that doesn't translate to executable validation.

## Why might it matter?

It removes a noise question from every new feature spec — a UX win for Sam and every future SDD user. It tightens the framework's consistency with its own anti-theatre doctrine (Foundation 3). It lowers the cost of writing a spec without lowering rigor, because §11 was already doing the load-bearing work. And it's small — ~30-60 atomic SDD steps total to land cleanly, not a big-bang refactor.

The longer it sits unfixed, the more spec.md files are written with §2 sections that someone will later need to migrate or grandfather.

## Confidence

Pretty sure. Sam discovered this live during feature 008 SPEC walkthrough (2026-05-08) — the §2 question pulled for unverifiable metrics that contradict SDD's own anti-theatre rules. Same pattern observed previously in pipelogic. The fix is small in scope and reversible. The only open question is the renumber-vs-gap decision, which is a design choice for the actual feature spec, not a confidence issue.

## Related features

- `features/008-build-the-sdd-on-pi-extension-package` — concern surfaced live during this feature's §2 walkthrough; idea 004 will be promoted to its own feature after 008 ships
- `features/003-anti-theatre-lint` (shipped) — establishes the doctrine that idea 004 makes more consistent
- Sibling ideas captured in this session:
  - `001-multi-platform-pi-adapter`
  - `002-parallel-wave-execution`
  - `003-specialized-subagents`

## Notes for promotion

- This should /start as a feature AFTER 008 ships, not before — Sam picked path (Y) in the discussion: feature 008 continues with bridge-to-§11 in §2, framework cleanup happens in its own focused cycle.
- Likely needs a milestone bump (v1.5?) since it's a breaking-ish change to the spec format. Existing shipped specs stay valid (frozen historical record); only new specs scaffolded after the change drop §2.
- Renumber-vs-gap is the single design call worth thinking about up front. Renumber is cleaner long-term but more refactor work; gap leaves §1 then §3 forever, which is mildly ugly but preserves backwards-compat for any tooling that hardcodes section numbers.
