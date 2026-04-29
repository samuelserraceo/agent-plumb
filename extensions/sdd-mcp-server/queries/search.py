"""search — opt-in semantic search over `.sdd/` (stub today).

Today this query is intentionally a stub: it reads the project's
`.sdd/config.md` for a `parameters.mcp.semantic_search` block and, if
absent or `enabled: false`, returns a config-shape error so the user
knows what to add. If `enabled: true`, the real implementation would
embed the query, retrieve top-k markdown blocks, and return them — but
that path requires an external provider (Anthropic / OpenAI / local
Gemma / etc.) and per CLAUDE.md "External dependencies must be explicit
customisation blocks", we ship the schema and defer the network call.

The shape returned even on disabled is friendly enough that a caller
can render it directly: `error` + `config_shape` + `available_files`.
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict


_CONFIG_SHAPE = {
    "parameters": {
        "mcp": {
            "semantic_search": {
                "enabled": True,
                "provider": "<openai|anthropic|local-gemma|ollama|...>",
                "endpoint": "<https://... or http://localhost:port>",
                "model": "<embedding model name>",
                "top_k": 5,
            }
        }
    }
}


def _read_config_yaml(project_root: str) -> Dict[str, Any]:
    """Pull the YAML frontmatter from .sdd/config.md.

    config.md uses `---\n<yaml>\n---\n<prose>`. We parse the front matter
    only — the prose is human guidance, not config.
    """
    cfg_path = os.path.join(project_root, ".sdd", "config.md")
    if not os.path.isfile(cfg_path):
        return {}
    try:
        with open(cfg_path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return {}
    fm = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not fm:
        return {}
    try:
        import yaml  # PyYAML — already a framework dep
    except ImportError:
        return {}
    try:
        loaded = yaml.safe_load(fm.group(1)) or {}
        return loaded if isinstance(loaded, dict) else {}
    except Exception:
        return {}


def search(project_root: str, args: Dict[str, Any]) -> Dict[str, Any]:
    query = (args or {}).get("query")
    if not query:
        return {"error": "missing arg 'query'"}

    cfg = _read_config_yaml(project_root)
    sem = (((cfg.get("parameters") or {}).get("mcp") or {}).get("semantic_search") or {})
    enabled = bool(sem.get("enabled"))

    if not enabled:
        return {
            "error": "semantic search not configured — set parameters.mcp.semantic_search in .sdd/config.md",
            "config_shape": _CONFIG_SHAPE,
            "query": query,
        }

    # If enabled, today we still don't make the network call — we return
    # a "configured but not implemented" message that includes the
    # provider/model the user opted into so they can verify the shape.
    return {
        "error": "semantic search is configured but the implementation is deferred — "
                 "the provider call ships in a follow-up commit",
        "configured": {
            "provider": sem.get("provider"),
            "endpoint": sem.get("endpoint"),
            "model": sem.get("model"),
            "top_k": sem.get("top_k", 5),
        },
        "query": query,
    }
