---
name: wiki-ingest
description: Use when the user invokes /wiki-ingest or asks to pull Notion changes into the local wiki. Queries each part's 메인 DB for rows whose last_edited_time is after sync-state.last_main_seen[part], paginating newest-first and stopping when it reaches unchanged rows. Mirrors row bodies to docs/raw/<part>/main/*.md, refines affected llm_wiki pages, updates index.md + log.md.
---

# wiki-ingest

Single entry point for Notion → local sync. No log DB; change
detection is driven by 메인 DB's `last_edited_time` against the
per-part cursor stored in `docs/raw/_meta/sync-state.json`.

**Announce at start:** "I'm using the wiki-ingest skill to pull Notion main-row changes into the wiki."

## Pre-flight

1. `docs/raw/_meta/sync-state.json`, `docs/raw/_meta/db-map.json` exist.
   - `db-map.schema_version` must be ≥ 2 (no log field). If it's older,
     abort and suggest re-running `/notion-bootstrap` or manually
     removing the `log` keys.
2. `db-map.json` has at least one part with a `main` data source id.
3. Notion MCP tools available.
4. No uncommitted changes in `docs/raw/` or `docs/llm_wiki/`. If dirty, ask
   whether to stash.
5. **LFS setup check** (warn-only, doesn't abort):
   - `.gitattributes` exists at repo root and contains at least one LFS
     filter for image extensions (`filter=lfs`). If not, print a
     one-liner warning suggesting:
     ```
     echo 'docs/llm_wiki/images/** filter=lfs diff=lfs merge=lfs -text' >> .gitattributes
     echo '*.png filter=lfs diff=lfs merge=lfs -text' >> .gitattributes
     git lfs install
     ```
   - `.git/hooks/pre-commit` exists and enforces the 100 MB cap. If
     absent, offer to install the hook (see "Pre-commit hook" section
     at the end of this file).

## Algorithm

### Phase 1 — Load state

Read `docs/raw/_meta/sync-state.json`:
- `last_main_seen[part]` (ISO-8601 string or null for first-time).

Read `docs/raw/_meta/db-map.json`:
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
4. Write `docs/raw/<part>/main/<slug>.md` with frontmatter:
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

### Phase 3.5 — Download embedded images (before writing body)

Notion image URLs are signed S3 links (`prod-files-secure.s3...`) that
expire in ~1 hour. To preserve them permanently, localize each image
into `docs/llm_wiki/images/<part>/<slug>/` (tracked by git LFS via the
project's `.gitattributes`). Run this before writing the raw file in
step 4 above so links inside `docs/raw/<part>/main/<slug>.md` are already
local paths.

Skip entirely if `--no-images` is passed.

1. **Extract URLs** from the fetched body markdown:
   - `![alt](https?://...)` — standard markdown image
   - `<img src="https?://...">` — inline HTML
   - `<video src="https?://...">` and `[video](https?://...)` — optional,
     gated by `--include-videos` (default: skip videos)
   Preserve discovery order → `urls[]` with 1-based indexes.

2. **Pick target directory**:
   `docs/llm_wiki/images/<part>/<slug>/` — mkdir -p if missing.

3. **For each URL** (`idx`, `url`):
   a. Determine extension: parse URL path for `.png|.jpg|.jpeg|.gif|.webp|.mp4|.mov|.webm`.
      If extension is missing or ambiguous, fall back to `.png`.
   b. Compute filename: `<zero-padded-idx>-<short-hash>.<ext>`
      where `<short-hash>` = first 8 hex chars of sha256(url).
      Example: `03-a1b2c3d4.png`.
   c. Download:
      ```
      curl -sSL --max-time 30 --retry 1 --max-filesize 104857600 -o \
        "docs/llm_wiki/images/<part>/<slug>/<filename>" "<url>"
      ```
      `--max-filesize 104857600` enforces a **100 MB hard cap** during
      download. curl aborts mid-stream and returns exit 63 if the
      response body exceeds it; this prevents a commit that later gets
      rejected by GitHub's 100 MB push limit.
   d. **Post-download size check** (defense in depth for missing
      Content-Length):
      ```
      size=$(wc -c < "docs/llm_wiki/images/<part>/<slug>/<filename>")
      if [ "$size" -gt 104857600 ]; then
        rm "docs/llm_wiki/images/<part>/<slug>/<filename>"
        append to download_failures: {url, reason: "too_large (>100MB)"}
        keep original URL in body
      fi
      ```
   e. **On failure** (HTTP 4xx/5xx, timeout, too_large, curl-63):
      - Log warning with URL snippet + reason.
      - Keep original URL in body (will be broken but traceable).
      - Append `{url, reason}` to `download_failures[]` for final report.

4. **Rewrite URLs** in the body text:
   - `docs/raw/<part>/main/<slug>.md` sees the image at
     `../../llm_wiki/images/<part>/<slug>/<filename>`
     (3 levels up from `docs/raw/<part>/main/` to project root, then into llm_wiki).
   - When sub-agents later refine into `docs/llm_wiki/<category>/*.md`, they
     compute their own relative path (`../images/<part>/<slug>/<filename>`).
   - Preserve the original `alt` text verbatim.

5. **Skip cases**:
   - URL already starts with `../llm_wiki/images/` or `docs/llm_wiki/images/`
     (already localized) — no-op.
   - `data:image/...;base64,...` inline — no-op (not a remote URL).
   - File size > 100MB after download — **deleted and skipped**
     (GitHub rejects files this large on regular git push; LFS alone
     is not sufficient, and even LFS has per-file costs).

6. **After download**, record in sync-state row entry:
   ```json
   "images": [
     {"index": 1, "file": "docs/llm_wiki/images/<part>/<slug>/01-a1b2c3d4.png",
      "origin_host": "prod-files-secure.s3..."}
   ]
   ```

### Phase 4 — Compute diff against prior sync

For each candidate that already existed on disk before this run:
1. Compare old file body (pre-write) with new body at section level
   (H2/H3 headers).
2. Summarize: "added: [...], removed: [...], modified: [...]" in plain
   natural Korean/English matching the row title.
3. Store the summary for the log step (Phase 7).

For new candidates (no prior file), summary = `"new: <title>"`.

### Phase 5 — Determine impacted llm_wiki files

Use Grep on `docs/llm_wiki/**/*.md` for `source: notion:<row-id>` markers.

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
     - `docs/llm_wiki/entities/` if tags include character/location/entity-ish.
     - `docs/llm_wiki/concepts/` if tags include system/mechanic.
     - `docs/llm_wiki/narrative/` if tags include story/lore/timeline.
     - `docs/llm_wiki/tech/` if tags include code/arch/test or part = development.
     - Otherwise default to `docs/llm_wiki/misc/`.
  5. Fill frontmatter fields (`refs[]` from inline `[[wiki-id]]` or
     markdown links to other wiki files).

Main Claude applies outputs via Edit/Write — sub-agents do not touch
the filesystem.

### Phase 7 — Update index.md and log.md

1. Rebuild `docs/llm_wiki/index.md` per category by globbing and reading
   H1 + summary line of each file.
2. Append one entry to `docs/llm_wiki/log.md`:
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

Write to `docs/raw/_meta/sync-state.json`:
- `last_main_seen[part]` = the **newest** `last_edited_time` among
  successfully ingested rows in this run (not the cursor of rows
  filtered out).
- `rows[row_id]` = `{"hash": "<sha256>", "notion_last_edited": "<iso>",
  "path": "docs/raw/<part>/main/<slug>.md"}`.
- `last_sync` = now.

Atomic write: `.json.tmp` then rename.

## Refine rules (for sub-agents)

1. No creative rewriting. Structural reorganization + summarization.
2. Preserve all `<!-- source: manual -->` and `<!-- source: code:* -->`
   blocks verbatim.
3. Produce frontmatter compatible with `docs/llm_wiki/index.md`
   rebuilding.
4. Cross-reference when multiple raw files map to the same concept.

## Forbidden

- Do NOT query a log DB — it does not exist in this version.
- Do NOT mutate Notion from this skill.
- Do NOT write under `docs/raw/<part>/notes/` unless `--include-notes` is
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
- `--no-images` — skip Phase 3.5 image download; keep remote URLs.
- `--include-videos` — also download video blocks (off by default; can
  be very large).
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
  images downloaded: X  (skipped too-large: Y)
  download failures: <list>  (kept original URLs)
  last_main_seen advanced: <list of timestamps>
  next: /wiki-query to inspect, or /notion-push if the wiki was manually edited.
```

## Pre-commit hook (project-local, 100 MB guard)

When the pre-flight detects the hook is missing, propose this install
command (run once per clone):

```bash
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
# Block commit if any staged file exceeds 100 MB — GitHub rejects these
# on regular git push. Large binaries should be LFS-tracked; once LFS
# is active, only tiny pointer files are staged, so this check passes.
set -e
limit=$((100 * 1024 * 1024))
over=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  size=$(wc -c < "$f" 2>/dev/null)
  if [ "${size:-0}" -gt $limit ]; then
    printf 'error: %s is %s bytes (>100MB). Commit blocked.\n' "$f" "$size"
    over=1
  fi
done < <(git diff --cached --name-only --diff-filter=ACM)
if [ "$over" -ne 0 ]; then
  cat <<'MSG'

Options:
  1. Track with git LFS (add pattern to .gitattributes, git lfs track, re-stage).
  2. Remove from staging: git rm --cached <file>
  3. Compress or split the file.
MSG
  exit 1
fi
HOOK
chmod +x .git/hooks/pre-commit
echo "installed .git/hooks/pre-commit (100MB guard)"
```
