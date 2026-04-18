---
name: wiki-lint
description: Use when the user invokes /wiki-lint or asks for a wiki health check. Reports orphans, stale drafts, contradictions, broken cross-links, and data gaps. Suggestions only — makes no edits unless the user explicitly approves each class of fix.
---

# wiki-lint

Periodic health check. Emits a prioritized report; does not modify files
by default.

**Announce at start:** "I'm using the wiki-lint skill to audit the wiki."

## Pre-flight

1. `docs/llm_wiki/index.md` exists.
2. `docs/raw/_meta/sync-state.json` exists (needed for staleness checks).

## Checks

### 1. Orphan pages
Pages with no inbound link (no other wiki file references them). Use
Grep across `docs/llm_wiki/**/*.md` for each page's id. Zero matches outside
itself → orphan.

### 2. Missing index entries
Files under `docs/llm_wiki/<category>/*.md` that are **not** listed in
`docs/llm_wiki/index.md`. Suggest index refresh.

Scan these categories (whichever exist in the project):
`entities/`, `concepts/`, `narrative/`, `tech/`, `plans/`, `specs/`,
`explorations/`. `images/` is asset storage — do NOT index it.

### 3. Stale drafts
Raw main rows with `status: draft` whose `notion_last_edited` is older
than 14 days. List with row title and days-since-edit.

### 4. Contradictions
Pairs of wiki pages whose claims conflict on the same entity. Heuristic:
two pages citing the same entity name with different values for the same
attribute sentence. Use a sub-agent (optional) to semantically compare
candidate pairs gathered by simple name-overlap.

### 5. Broken cross-links
`[[<id>]]` or markdown links `../foo/bar.md` that resolve to non-existent
files. Grep + file-existence check.

### 6. Provenance drift
`<!-- source: notion:<row-id> -->` blocks whose `row-id` is not in
`sync-state.rows[]`. These came from rows that have since disappeared.

### 7. Unclaimed rows
Raw main rows that have no `<!-- source: notion:<row-id> -->` block
anywhere in the wiki. They were ingested but never incorporated.

### 8. Empty categories
`docs/llm_wiki/<category>/` directories with zero files. Likely an
index-category mismatch.

## Report format

```
wiki-lint report  (YYYY-MM-DD HH:MM)
=====================================

[HIGH]   N contradictions
  - page-a.md vs page-b.md: "에인's age" (20 vs 17)
  - ...

[MED]    N orphan pages
  - docs/llm_wiki/concepts/legacy-thing.md

[MED]    N stale drafts (> 14d)
  - row: <row-id> "던전 레이아웃" (18 days)

[LOW]    N broken links
  - docs/llm_wiki/entities/eyn.md → [[old-ref]]  (target missing)

[LOW]    N unclaimed raw rows
  - row: <row-id> "NPC 대사 표"

[INFO]   N empty categories
  - docs/llm_wiki/concepts/ (0 files)

Suggested actions:
  1. Fix HIGH contradictions — ask author to clarify.
  2. Run /wiki-ingest to bring stale drafts into wiki (if they have log entries).
  3. Archive orphans to docs/llm_wiki/archive/ if truly unused.
  4. Rerun /wiki-lint after changes.
```

## Auto-fix (opt-in)

Only if user passes `--fix`:
- Refresh missing index entries (safe).
- Delete `<!-- source: notion:<row-id> -->` blocks whose row vanished
  AND the page has other provenance.
- Nothing else is auto-fixed; all other issues require human review.

## Forbidden

- Do NOT delete pages automatically.
- Do NOT resolve contradictions silently — always surface them.
- Do NOT call Notion MCP (lint is purely local).
- Do NOT modify `docs/raw/**`.

## Arguments

- (no args) — full report.
- `--check <id>` — run only the named check (orphans, drafts, links, …).
- `--fix` — apply safe auto-fixes (see above) with a summary diff.
