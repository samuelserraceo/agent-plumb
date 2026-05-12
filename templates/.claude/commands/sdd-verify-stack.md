---
description: "Verify the tools recorded in .sdd/config.md actually exist + are reachable. Closes #165."
---

Run `bash .sdd/scripts/verify-stack.sh` from the project root.

Output is one line per check, shape:

```
[verify-stack] <check>: <ok|warn|fail> — <message>
```

Checks (each gracefully skips if its precondition isn't set):

1. **CodeRabbit App** — when `parameters.review.bot: coderabbit`, probes `gh api repos/<repo>/installation`. Fail surfaces the marketplace install URL.
2. **Ollama endpoint** — when `parameters.mcp.tier3.enabled: true` AND provider is `ollama-chat`/`ollama-native`, HEAD-probes the endpoint with a 2-second timeout.
3. **CI workflows** — counts `.yml`/`.yaml` files in `.github/workflows/`.
4. **Branch protection** — `gh api repos/<repo>/branches/main/protection` non-error = protected.

Exit code: `0` if no FAIL (warnings allowed); `1` if any FAIL.

JSON mode for tooling: `bash .sdd/scripts/verify-stack.sh --json` emits one JSON object per line.

When run as the last step of `/sdd-setup`, fails surface real gaps before the user assumes the setup is complete (closes #165's failure-mode "user said 'I'll use CodeRabbit' but never installed the App; agent assumes CR is reviewing every PR and waits silently for reviews that never come").
