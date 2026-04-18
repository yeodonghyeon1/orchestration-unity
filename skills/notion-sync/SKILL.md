---
name: notion-sync
description: Use when the user invokes /notion-sync or asks to mirror Notion workspace into notion_docs/. Fetches pages via Notion MCP, runs incremental change detection, writes notion_docs/*.md with frontmatter.
---

# notion-sync

Mirror the configured Notion workspace's top-level pages (and their sub-pages)
into `notion_docs/` as markdown files with sync metadata in YAML frontmatter.

**Announce at start:** "I'm using the notion-sync skill to sync Notion → notion_docs/."

## Pre-flight checks

1. `notion_docs/_meta/sync-state.json` and `notion_docs/_meta/page-map.json` exist — if not, run `scripts/init-workspace.sh .` first.
2. Notion MCP tools available (`mcp__claude_ai_Notion__notion-search`, `mcp__claude_ai_Notion__notion-fetch`). If missing, stop and tell user.

## Four-step pipeline

See `change-detection.md` for the detailed algorithm. Summary:

1. **Timestamp pre-filter** — fetch Notion page list, compare `last_edited_time` vs sync-state.json.
2. **Hash verify** — fetch candidate page content, normalize, SHA256, compare vs frontmatter.
3. **Deletion detection** — Notion page ids not in current list → move to orphans.
4. **Write** — generate `notion_docs/*.md` with frontmatter for real changes; update sync-state atomically.

## Handling new top-level pages

When a top-level Notion page ID is NOT in page-map.json:
1. Propose a folder name: slugified title via `python3 scripts/page-map.py slugify <title>`.
2. Ask the user to confirm or override.
3. Add mapping: `python3 scripts/page-map.py add notion_docs/_meta/page-map.json <page_id> <title> <folder>`.
4. Continue sync.

## Forbidden actions

- Do NOT edit `notion_docs/*.md` files with hand-written content. All writes go through the sync engine.
- Do NOT delete pages from `page-map.json` when they still exist in Notion.
- Do NOT skip `sync-state.json` updates — they are the persistence layer.

## Output

After sync, emit a short summary to the user:

```
synced: N pages (M new, K updated, 0 unchanged, 0 orphaned)
sync-state: notion_docs/_meta/sync-state.json
```
