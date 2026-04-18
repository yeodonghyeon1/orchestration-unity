---
name: init-wiki
description: Use when the user invokes /init-wiki or asks to initialize the llm-wiki workspace in the current project. Creates raw/ + llm_wiki/ + _meta seed files. Idempotent.
---

# init-wiki

Seed the llm-wiki three-tier workspace in the current project. Safe to run
multiple times — existing files are preserved.

**Announce at start:** "I'm using the init-wiki skill to seed raw/ and llm_wiki/."

## Pre-flight

1. Current working directory is a project root (has any of `package.json`,
   `ProjectSettings/`, `.git/`, or user confirms). Otherwise warn.
2. Notion MCP availability is **not** required for this skill (bootstrap
   comes next via `/notion-bootstrap`).

## Execution

Run exactly this Bash (via the Bash tool) at the project root:

```bash
set -eu
root="$(pwd)"

mkdir -p \
  "$root/raw/_meta" \
  "$root/llm_wiki/_meta" \
  "$root/llm_wiki/entities" \
  "$root/llm_wiki/concepts" \
  "$root/llm_wiki/narrative" \
  "$root/llm_wiki/tech"

# sync-state.json — per-part log cursor + row hash table
if [ ! -f "$root/raw/_meta/sync-state.json" ]; then
  cat > "$root/raw/_meta/sync-state.json" <<'JSON'
{
  "schema_version": 2,
  "last_sync": null,
  "last_push_commit": null,
  "last_log_seen": {},
  "rows": {},
  "orphans": []
}
JSON
fi

# db-map.json — filled by /notion-bootstrap
if [ ! -f "$root/raw/_meta/db-map.json" ]; then
  cat > "$root/raw/_meta/db-map.json" <<'JSON'
{
  "schema_version": 1,
  "root_page_id": null,
  "parts": {}
}
JSON
fi

# page-map.json — parts ↔ folder mapping
if [ ! -f "$root/raw/_meta/page-map.json" ]; then
  cat > "$root/raw/_meta/page-map.json" <<'JSON'
{
  "schema_version": 1,
  "mappings": [],
  "auto_slugify": true
}
JSON
fi

# wiki-state.json — refinement provenance
if [ ! -f "$root/llm_wiki/_meta/wiki-state.json" ]; then
  cat > "$root/llm_wiki/_meta/wiki-state.json" <<'JSON'
{
  "schema_version": 1,
  "source_linkage": {},
  "refinement_hashes": {}
}
JSON
fi

# Seed empty index.md / log.md if missing
[ -f "$root/llm_wiki/index.md" ] || cat > "$root/llm_wiki/index.md" <<'MD'
# Wiki Index

_This file is maintained by the LLM. Do not edit by hand._

## Entities

_(empty)_

## Concepts

_(empty)_

## Narrative

_(empty)_

## Tech

_(empty)_
MD

[ -f "$root/llm_wiki/log.md" ] || cat > "$root/llm_wiki/log.md" <<'MD'
# Wiki Log

_Chronological, append-only. Each entry starts with `## [YYYY-MM-DD HH:MM]`._
MD

echo "init-wiki complete at $root"
```

## Report

Emit to the user:

```
init-wiki complete:
  raw/        → seeded (_meta: sync-state.json, db-map.json, page-map.json)
  llm_wiki/   → seeded (index.md, log.md, _meta/wiki-state.json)
  next:
    1) /notion-bootstrap <main-page-url>  — to create Notion parts + DBs.
    2) /wiki-ingest                       — once a log entry is posted.
```

## Forbidden

- Do NOT overwrite existing `_meta/*.json` files.
- Do NOT create project-specific subfolders (parts like `development/art/design`
  are created by `/notion-bootstrap` based on user input or defaults).
- Do NOT write outside the project root.
