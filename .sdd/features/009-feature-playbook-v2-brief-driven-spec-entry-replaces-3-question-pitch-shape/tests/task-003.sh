#!/usr/bin/env bash
# T03: prose-contract — brief-intake.md NAMES the 6 pre-fill targets
# (§1, §3, §6, §7, §8, §10) plus the 2 standard-ceremony exclusions
# (§11 ACs + §14 plan-decompose).
#
# AC3 is the runtime claim "after brief-summarise, sections in spec.md show
# pre-filled prose drawn from the brief". That claim is BEHAVIOURAL — it
# requires an LLM agent to read brief-intake.md and follow its instructions
# against a real brief. This framework (markdown + bash) has no automated
# way to run an LLM action against a fixture, so the BEHAVIOURAL half of
# AC3 is verified manually at §12 sign-off (when Sam first walks F010+
# through the new flow with a real brief). T03 verifies only the PROSE
# CONTRACT — that the action prose tells the agent the right things.
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
ACTION="$ROOT/templates/.sdd/actions/brief-intake.md"
[ -f "$ACTION" ] || { echo "FAIL: $ACTION missing"; exit 1; }
# Each pre-fill target section must be named explicitly in the prose
for section in "§1 problem" "§3 user-stories" "§6 data-contract" "§7 flows" "§8 dependencies" "§10 non-functional"; do
  grep -q "$section" "$ACTION" || { echo "FAIL: '$section' pre-fill target missing in prose"; exit 1; }
done
# Standard-ceremony exclusions
grep -q "§11 ACs" "$ACTION" || { echo "FAIL: §11 placeholder note missing"; exit 1; }
grep -qE '§14.*placeholder' "$ACTION" || { echo "FAIL: §14 placeholder note missing (need the full 'placeholder' phrase, not just the §14 token)"; exit 1; }
echo "PASS: T03 — brief-intake names all 6 pre-fill targets + 2 standard-ceremony exclusions"
