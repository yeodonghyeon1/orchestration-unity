---
description: Pull Notion 📘 메인 rows whose last_edited_time exceeds the per-part cursor; refine affected llm_wiki pages.
argument-hint: [--part <key>] [--include-drafts|--only-fixed] [--include-notes] [--dry-run] [--limit N]
---

# /wiki-ingest

Single entry point for Notion → local sync. Log-free (v2): change detection
is driven by `last_edited_time` on each part's 📘 메인 DB.

Invoke the `wiki-ingest` skill:

```
Skill('wiki-ingest')
```

The skill will:

1. Load `sync-state.last_main_seen[part]`.
2. For each part, paginate 📘 메인 DB sorted by `last_edited_time DESC`;
   stop when a row's timestamp ≤ cursor.
3. Filter by `상태` (default: `{review, fixed}`).
4. Fetch each surviving row, mirror to `raw/<part>/main/*.md` with
   frontmatter.
5. Diff old vs new body → log summary.
6. Compute impacted `llm_wiki/**` pages via
   `<!-- source: notion:<row-id> -->` markers.
7. Dispatch refinement sub-agents; main Claude applies outputs via
   Edit/Write.
8. Update `llm_wiki/index.md` and `log.md`.
9. Persist `sync-state` (new `last_main_seen` + row hashes).

## Arguments

- (no args) — all parts, filter `{review, fixed}`.
- `--part <key>` — single part (development/art/design).
- `--include-drafts` — also include `상태: draft`.
- `--only-fixed` — only `상태: fixed`.
- `--include-notes` — also ingest 💡 자료&아이디어 rows using the same
  timestamp cursor (`last_notes_seen`).
- `--dry-run` — stop before writing.
- `--limit N` — per-part pagination page cap (default 10 = 250 rows).

## Forbidden

- Do NOT run without `/init-wiki` + `/notion-bootstrap`.
- Do NOT query a log DB — it does not exist in v2.
- Do NOT run `/notion-push` from this command.
