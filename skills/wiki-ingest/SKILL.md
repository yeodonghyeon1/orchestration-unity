---
name: wiki-ingest
description: Use when the user invokes /wiki-ingest or asks to pull Notion changes into the local wiki. Queries each part's 메인 DB for rows whose last_edited_time is after sync-state.last_main_seen[part], paginating newest-first and stopping when it reaches unchanged rows. Mirrors row bodies to raw/<part>/main/*.md, refines affected llm_wiki pages, updates index.md + log.md.
---

# wiki-ingest

Single entry point for Notion → local sync. No log DB; change
detection is driven by 메인 DB's `last_edited_time` against the
per-part cursor stored in `raw/_meta/sync-state.json`.

**Announce at start:** "I'm using the wiki-ingest skill to pull Notion main-row changes into the wiki."

## Pre-flight

1. `raw/_meta/sync-state.json`, `raw/_meta/db-map.json` exist.
   - `db-map.schema_version` must be ≥ 2 (no log field). If it's older,
     abort and suggest re-running `/notion-bootstrap` or manually
     removing the `log` keys.
2. `db-map.json` has at least one part with a `main` data source id.
3. Notion MCP tools available.
4. No uncommitted changes in `raw/` or `llm_wiki/`. If dirty, ask
   whether to stash.

## Algorithm

### Phase 1 — Load state

Read `raw/_meta/sync-state.json`:
- `last_main_seen[part]` (ISO-8601 string or null for first-time).

Read `raw/_meta/db-map.json`:
- For each part: `main` (data source id), `notes` (data source id),
  `page` (part page id).

### Phase 2 — Paginate each part's 메인 DB

For each part in `db-map.parts` (respecting `--part <key>` if given):

1. Call `notion-search` with `data_source_url = collection://<main-ds>`
   and `sort: {"timestamp": "last_edited_time", "direction": "descending"}`.
   Use `page_size: 25`.
2. For each returned row, compare `last_edited_time` against
   `last_main_seen[part]`:
   - If strictly **greater** → add to `candidates[part][]`.
   - If **less than or equal** → stop paginating; rows older than or
     equal to the cursor cannot have been changed.
3. If the current page was fully "greater", request `next_cursor` and
   repeat. Hard cap: 10 pages (250 rows) per part per run to avoid
   runaway on first-time sync. Warn if hit.
4. After collection, **apply status filter**:
   - Default: keep rows where `상태 ∈ {review, fixed}`.
   - With `--include-drafts`: keep all rows.
   - With `--only-fixed`: keep rows where `상태 = fixed`.
   - Rows dropped by filter are reported but not ingested.

### Phase 3 — Fetch each candidate row body

For each surviving candidate:
1. `notion-fetch` the row.
2. Extract `{title, 상태, 태그, last_edited_time, body_markdown, url}`.
3. Compute slug = kebab-case of title. Append `-<short-id>` if slug
   collides within the part.
4. Write `raw/<part>/main/<slug>.md` with frontmatter:
   ```yaml
   ---
   id: raw.<part>.<slug>
   notion_row_id: "<row-id>"
   title: "<title>"
   status: "<draft|review|fixed>"
   tags: [<tags>]
   notion_last_edited: "<iso8601>"
   synced_at: "<now iso8601>"
   source_url: "<url>"
   ---
   ```
   Followed by the row body in Markdown.
5. Compute sha256 of the normalized body; stage for
   `sync-state.rows[row_id]`.

### Phase 4 — Compute diff against prior sync

For each candidate that already existed on disk before this run:
1. Compare old file body (pre-write) with new body at section level
   (H2/H3 headers).
2. Summarize: "added: [...], removed: [...], modified: [...]" in plain
   natural Korean/English matching the row title.
3. Store the summary for the log step (Phase 7).

For new candidates (no prior file), summary = `"new: <title>"`.

### Phase 5 — Determine impacted llm_wiki files

Use Grep on `llm_wiki/**/*.md` for `source: notion:<row-id>` markers.

- Matches → add to `impacted[]`.
- No match → flag as **unclaimed**; a new wiki page will be created in
  Phase 6.

### Phase 6 — Refine (parallel sub-agents)

Dispatch via `superpowers:dispatching-parallel-agents` (cap 5
concurrent). Each sub-agent:
- Input: one wiki file (or target path for new) + associated raw main
  file(s).
- Instructions:
  1. Preserve H2/H3 hierarchy already in the wiki file.
  2. Only rewrite sections between `<!-- source: notion:<id> -->` and
     the matching `<!-- /source: notion:<id> -->` markers.
  3. Never touch `<!-- source: manual -->` or
     `<!-- source: code:* -->` blocks.
  4. For unclaimed rows, place new pages under:
     - `llm_wiki/entities/` if tags include character/location/entity-ish.
     - `llm_wiki/concepts/` if tags include system/mechanic.
     - `llm_wiki/narrative/` if tags include story/lore/timeline.
     - `llm_wiki/tech/` if tags include code/arch/test or part = development.
     - Otherwise default to `llm_wiki/misc/`.
  5. Fill frontmatter fields (`refs[]` from inline `[[wiki-id]]` or
     markdown links to other wiki files).

Main Claude applies outputs via Edit/Write — sub-agents do not touch
the filesystem.

### Phase 7 — Update index.md and log.md

1. Rebuild `llm_wiki/index.md` per category by globbing and reading
   H1 + summary line of each file.
2. Append one entry to `llm_wiki/log.md`:
   ```
   ## [YYYY-MM-DD HH:MM] ingest | N rows, M wiki files refined
   - parts: <list>
   - per-row summaries:
     - <part>/<slug>: <diff summary from Phase 4>
   - unclaimed → new pages: <list>
   - refined: <list>
   - filter: 상태 ∈ {review, fixed}  (or --include-drafts, --only-fixed)
   ```

### Phase 8 — Persist state

Write to `raw/_meta/sync-state.json`:
- `last_main_seen[part]` = the **newest** `last_edited_time` among
  successfully ingested rows in this run (not the cursor of rows
  filtered out).
- `rows[row_id]` = `{"hash": "<sha256>", "notion_last_edited": "<iso>",
  "path": "raw/<part>/main/<slug>.md"}`.
- `last_sync` = now.

Atomic write: `.json.tmp` then rename.

## Refine rules (for sub-agents)

1. No creative rewriting. Structural reorganization + summarization.
2. Preserve all `<!-- source: manual -->` and `<!-- source: code:* -->`
   blocks verbatim.
3. Produce frontmatter compatible with `llm_wiki/index.md`
   rebuilding.
4. Cross-reference when multiple raw files map to the same concept.

## Forbidden

- Do NOT query a log DB — it does not exist in this version.
- Do NOT mutate Notion from this skill.
- Do NOT write under `raw/<part>/notes/` unless `--include-notes` is
  passed (then treat as additional candidates but do not refine by
  default).
- Do NOT update `last_main_seen` before Phase 6 succeeds for the
  corresponding part.
- Sub-agents do NOT touch the filesystem directly.

## Arguments

- (no args) — all parts, default filter.
- `--part <key>` — single part.
- `--include-drafts` — include rows with `상태: draft`.
- `--only-fixed` — only rows with `상태: fixed`.
- `--include-notes` — also ingest 자료&아이디어 DB (uses the same
  last_edited_time algorithm against `last_notes_seen`).
- `--dry-run` — stop after Phase 5; emit the plan without writing.
- `--limit N` — per-part pagination cap (default 10 pages).

## Report

```
wiki-ingest complete:
  parts processed: <list>
  candidates found: N  (passed filter: M, dropped: K)
  rows ingested: M
  wiki files refined: L
  unclaimed → new pages: <list>
  per-row diff summaries: <list>
  last_main_seen advanced: <list of timestamps>
  next: /wiki-query to inspect, or /notion-push if the wiki was manually edited.
```
