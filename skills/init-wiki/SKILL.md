---
name: init-wiki
description: Use when the user invokes /init-wiki or asks to initialize the llm-wiki workspace in the current project. Creates docs/{raw,llm_wiki}/ + _meta seed files. Idempotent.
---

# init-wiki

Seed the llm-wiki three-tier workspace under `docs/` in the current
project. Safe to run multiple times — existing files are preserved.

**Layout (v2.4+)**:

```
docs/
├── raw/          ← Notion mirror  (managed by /wiki-ingest)
├── llm_wiki/     ← LLM-maintained knowledge base
└── superpowers/  ← Superpowers plans / specs (created on demand by
                    brainstorming + writing-plans skills)
```

**Announce at start:** "I'm using the init-wiki skill to seed docs/raw/ and docs/llm_wiki/."

## Pre-flight

1. Current working directory is a project root (has any of `package.json`,
   `ProjectSettings/`, `.git/`, or user confirms). Otherwise warn.
2. Notion MCP availability is **not** required (bootstrap comes next via
   `/notion-bootstrap`).

## Execution

Run exactly this Bash at the project root:

```bash
set -eu
root="$(pwd)"

mkdir -p \
  "$root/docs/raw/_meta" \
  "$root/docs/llm_wiki/_meta" \
  "$root/docs/llm_wiki/entities" \
  "$root/docs/llm_wiki/concepts" \
  "$root/docs/llm_wiki/narrative" \
  "$root/docs/llm_wiki/tech" \
  "$root/docs/llm_wiki/explorations" \
  "$root/docs/llm_wiki/images" \
  "$root/docs/superpowers/plans" \
  "$root/docs/superpowers/specs"

# .gitkeep for empty dirs so git preserves them
for d in explorations images; do
  [ -f "$root/docs/llm_wiki/$d/.gitkeep" ] || touch "$root/docs/llm_wiki/$d/.gitkeep"
done
for d in plans specs; do
  [ -f "$root/docs/superpowers/$d/.gitkeep" ] || touch "$root/docs/superpowers/$d/.gitkeep"
done

# sync-state.json — per-part cursor + row hash table
if [ ! -f "$root/docs/raw/_meta/sync-state.json" ]; then
  cat > "$root/docs/raw/_meta/sync-state.json" <<'JSON'
{
  "schema_version": 3,
  "last_sync": null,
  "last_push_commit": null,
  "last_main_seen": {},
  "last_notes_seen": {},
  "rows": {},
  "orphans": []
}
JSON
fi

# db-map.json — filled by /notion-bootstrap
if [ ! -f "$root/docs/raw/_meta/db-map.json" ]; then
  cat > "$root/docs/raw/_meta/db-map.json" <<'JSON'
{
  "schema_version": 2,
  "root_page_id": null,
  "parts": {}
}
JSON
fi

# page-map.json — parts ↔ folder mapping
if [ ! -f "$root/docs/raw/_meta/page-map.json" ]; then
  cat > "$root/docs/raw/_meta/page-map.json" <<'JSON'
{
  "schema_version": 1,
  "mappings": [],
  "auto_slugify": true
}
JSON
fi

# wiki-state.json — refinement provenance
if [ ! -f "$root/docs/llm_wiki/_meta/wiki-state.json" ]; then
  cat > "$root/docs/llm_wiki/_meta/wiki-state.json" <<'JSON'
{
  "schema_version": 1,
  "source_linkage": {},
  "refinement_hashes": {}
}
JSON
fi

# Seed empty index.md / log.md if missing
[ -f "$root/docs/llm_wiki/index.md" ] || cat > "$root/docs/llm_wiki/index.md" <<'MD'
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

## Explorations

_(empty — written by `/wiki-query` when filing an answer)_
MD

[ -f "$root/docs/llm_wiki/log.md" ] || cat > "$root/docs/llm_wiki/log.md" <<'MD'
# Wiki Log

_Chronological, append-only. Each entry starts with `## [YYYY-MM-DD HH:MM]`._
MD

echo "init-wiki complete at $root"
```

## Report

```
init-wiki complete:
  docs/raw/         → seeded (_meta: sync-state.json, db-map.json, page-map.json)
  docs/llm_wiki/    → seeded (index.md, log.md, _meta/wiki-state.json, images/)
  docs/superpowers/ → plans/ and specs/ reserved for superpowers skills
  next:
    1) /notion-bootstrap <main-page-url>  — to create Notion parts + DBs.
    2) /wiki-ingest                       — once a main-row exists.
```

## Forbidden

- Do NOT overwrite existing `_meta/*.json` files.
- Do NOT create project-specific subfolders under `docs/raw/` or
  `docs/llm_wiki/` — those are created by `/notion-bootstrap` or
  refinement.
- Do NOT write outside the project root.
- Do NOT seed `docs/superpowers/plans/` or `/specs/` with sample files —
  they are owned by superpowers `brainstorming` / `writing-plans`.
