---
description: Incrementally sync the Notion workspace into notion_docs/
argument-hint: (no arguments — syncs all mapped pages)
---

# /notion-sync

Fetch and mirror the Notion workspace into `notion_docs/` using the
notion-sync skill.

Invoke the `notion-sync` skill via the Skill tool:

```
Skill('notion-sync')
```

The skill will:
1. Verify pre-flight (sync-state.json + page-map.json present; Notion MCP available)
2. Run the four-step change detection pipeline
3. Write `notion_docs/*.md` files for real changes
4. Update `notion_docs/_meta/sync-state.json`
5. Report a summary to the user

Do NOT run `/docs-refinement` or `/docs-update` as part of this command — this
is sync only. Use `/docs-update` for the full pipeline.
