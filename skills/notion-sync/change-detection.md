---
id: skills.notion-sync.change-detection
title: Notion Sync — Four-Step Change Detection
owner: developer
status: stable
updated: 2026-04-18
version: 1
tags: [sync, algorithm, reference]
---

# Change Detection Algorithm

## Step 1: Timestamp pre-filter

Call `mcp__claude_ai_Notion__notion-search` scoped to the workspace root. For
each returned page, read `notion_last_edited` and compare against
`sync-state.json → pages[page_id].notion_last_edited`.

- If Notion is newer → add to `candidates[]`.
- If equal or older → skip (no API cost beyond search).

## Step 2: Hash verify

For each candidate, call `mcp__claude_ai_Notion__notion-fetch` to get full
content. Pipe the JSON to `scripts/notion-hash.py` to compute a canonical
SHA256. Compare against the stored hash.

- If different → add to `real_changes[]`.
- If same → update only `notion_last_edited` in sync-state (content unchanged).

## Step 3: Deletion detection

Diff the set of page IDs returned by `notion-search` against
`sync-state.json → pages.keys()`. IDs present in state but missing from
Notion → orphans. Move each to `orphans[]` via
`sync-state.py move-to-orphans`.

Also delete the corresponding `notion_docs/*.md` file. Log loudly.

## Step 4: Write

For each `real_changes` entry:
1. Resolve target path from page-map.json + sub-page hierarchy
   (e.g., `plan/combat-system/damage-formula.md`).
2. Generate frontmatter using the template.
3. Write markdown body (Notion block-to-markdown conversion — minimal for v1:
   headings, paragraphs, lists, bold/italic, links).
4. Call `sync-state.py upsert` to record the hash.

All file writes are atomic (temp file + rename). No partial state on crash.
