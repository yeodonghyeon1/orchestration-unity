---
description: One-time Notion setup. Creates three part pages (development/art/design) each with two databases (📘 메인, 💡 자료&아이디어) under a user-supplied empty main page.
argument-hint: <main-page-url> [--parts key=label,...] [--dry-run]
---

# /notion-bootstrap

Create the llm-wiki v2 Notion layout. Run once per project after
`/init-wiki`.

Invoke the `notion-bootstrap` skill:

```
Skill('notion-bootstrap')
```

The skill will:
1. Confirm the main page is empty and the user approves the plan.
2. Create three part pages (개발·아트·디자인 by default).
3. Per part: create 📘 메인 DB and 💡 자료&아이디어 DB (6 DBs total).
4. Overwrite the main page body with a v2 structure doc (best-effort;
   skips if MCP validation blocks).
5. Persist `raw/_meta/db-map.json` (schema v2) and seed
   `sync-state.json` (schema v3) with `last_main_seen[part] = null`.

**No log DB.** Change detection in `/wiki-ingest` uses
`last_edited_time` on each 📘 메인 DB.

## Arguments

- `<main-page-url>` (required) — the Notion page to turn into the root.
- `--parts key=label[,key=label...]` — override default parts.
- `--dry-run` — stop after plan, nothing created.

## Forbidden

- Do NOT run without `/init-wiki` first.
- Do NOT target a page that already has content.
- Do NOT create a 로그 DB — v2 design.
