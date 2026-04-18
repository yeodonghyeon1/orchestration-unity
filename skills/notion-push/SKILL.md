---
name: notion-push
description: Use when the user invokes /notion-push or asks to publish docs/llm_wiki/ changes back to the Notion 메인 DB rows they came from. Reverse sync — develop_docs → Notion. Preserves user-authored (source:manual) blocks. Requires the user to approve a dry-run plan before any write.
---

# notion-push

Push refined wiki content back to the Notion main DB rows that sourced
it. Target is always a row in a part's 메인 DB, never an arbitrary page.

**Announce at start:** "I'm using the notion-push skill to publish wiki changes to Notion."

## When to use vs /wiki-ingest

- `/wiki-ingest` — Notion 메인 → local wiki (forward).
- `/notion-push` — local wiki → Notion 메인 (reverse). Run after
  `/wiki-sync-code` or manual wiki edits.

## Pre-flight

1. `docs/raw/_meta/sync-state.json`, `docs/raw/_meta/db-map.json` present with
   `root_page_id` set. Abort otherwise.
2. Notion MCP tools available.
3. `docs/raw/` has no uncommitted local edits (raw is sync-owned). Abort if
   dirty.
4. Every candidate wiki file has either a `<!-- source: notion:<row-id> -->`
   block or frontmatter `source_notion_rows: [<id>, ...]`. Files with
   neither are skipped loudly.

## Algorithm

### Phase 1 — Collect candidates

1. Default: `git diff --name-only <last_push_commit>..HEAD -- docs/llm_wiki/`.
   If `last_push_commit` is null (first push), use `HEAD~5..HEAD` and
   warn.
2. `--all` uses every `docs/llm_wiki/**/*.md` that has a notion source marker.
3. `--files <path>...` uses the explicit list.

### Phase 2 — Map each section to a target row

For every candidate file:
1. Read frontmatter (optional `source_notion_rows`).
2. Grep for `<!-- source: notion:<row-id> -->` markers within the file.
3. For each row-id collected, look up `sync-state.rows[<row-id>]`:
   - If missing → abort for this section with "row unknown; run /wiki-ingest".
4. Build a per-row payload: the markdown between the opening and closing
   source markers for that row-id.

Group by target row so multiple wiki files contributing to the same row
are bundled.

### Phase 3 — Conflict detection

For every target row:
1. `notion-fetch` the row.
2. Compare Notion `last_edited_time` with
   `sync-state.rows[<row-id>].notion_last_edited`.
3. Strictly later → **conflict** for this row.

If any conflict exists, **abort the whole run** and report:
```
Conflicts detected. Notion has newer edits for:
  - <row-id> "<title>" (Notion: <ts> vs local: <ts>)
  ...
Resolve by running /wiki-ingest first, then re-try /notion-push.
```

### Phase 4 — Dry-run plan

Emit:
```
notion-push plan:
  commit range: <range>
  candidates: N files → M rows
  per row:
    - <part> / 메인 / "<title>"  (<id>)
      sections to replace: [<marker-ids>]
      source files: [<paths>]
  preserved blocks: source: manual — not touched
  conflict check: OK
Reply y to execute, n to abort.
```

Wait for approval. With `--dry-run` the skill exits here.

### Phase 5 — Push per row

For each target row:
1. `notion-fetch` the row again (fresh copy) — guard against TOCTOU.
2. Identify existing sections in the Notion body:
   - Keep `source: manual` blocks verbatim.
   - Rewrite `source: notion:<id>` blocks whose `<id>` matches the
     current row id's section marker in the wiki payload.
   - Append new sections from the wiki that don't exist yet, with a
     `source: notion:<id>` marker (new).
3. Call `notion-update-page` with:
   - `command: update_content` and precise `content_updates[]` pairs
     when the transformation fits search-and-replace.
   - Fall back to `command: replace_content` with
     `allow_deleting_content: false` only if update_content cannot
     express the change. In that case include `<page url="...">` tags
     for any child pages under the row.
4. On success, update `sync-state.rows[<row-id>]`:
   - `hash` = sha256 of new Notion body (post-fetch).
   - `notion_last_edited` = new `last_edited_time`.

If any row fails, continue with the rest but remember the failure list.

### Phase 6 — Record and report

1. Write `docs/raw/_meta/sync-state.json` atomically with:
   - Updated rows.
   - `last_push_commit = <current HEAD>`.
   - `last_push = now`.
2. Report:
```
notion-push complete:
  rows updated: N
  sections rewritten: M
  sections created: K
  preserved manual blocks: P
  failed: [<list>]  (if any)
  commit recorded: <sha>
  next: /wiki-ingest should now report zero changes (round-trip clean).
```

## Orphaned Notion sections

If a row's Notion body has `<!-- source: notion:<id> -->` blocks whose
`<id>` is not produced by any wiki file in this push:

- Default: **keep** (Notion block preserved).
- With `--prune-orphans`: **remove** those blocks.

Always list orphans in the dry-run plan regardless of flag.

## Forbidden

- Do NOT push without the user approving the dry-run.
- Do NOT overwrite `source: manual` blocks.
- Do NOT delete Notion pages or rows.
- Do NOT modify `docs/raw/**` — that's `/wiki-ingest`'s territory.
- Do NOT run `/wiki-ingest` from within this skill.

## Arguments

- (no args) — git range `last_push_commit..HEAD`.
- `--all` — every wiki file with a notion source marker.
- `--files <path>...` — explicit list.
- `--dry-run` — stop after Phase 4.
- `--prune-orphans` — remove orphaned Notion sections during push.
