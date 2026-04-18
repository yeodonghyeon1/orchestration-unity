---
name: docs-refinement
description: Use when the user invokes /docs-refinement or asks to transform notion_docs/ into develop_docs/. Reads notion_docs, runs BFS impact graph, dispatches sub-agents to refine affected develop_docs files.
---

# docs-refinement

Transform `notion_docs/` (raw Notion mirror) into `develop_docs/` (refined,
cross-referenced, modular dev tree). Only files whose source Notion pages
changed get regenerated — tracked via `_meta/index.json` reverse_index.

**Announce at start:** "I'm using the docs-refinement skill to rebuild develop_docs/ from notion_docs/."

## Pre-flight

1. `notion_docs/_meta/sync-state.json` exists and has at least one entry.
2. `develop_docs/` directory exists (init-workspace.sh seeds it).

## Three-phase algorithm

### Phase 1: Index
Run `python3 scripts/docs-index.py develop_docs` to produce the current
`develop_docs/_meta/index.json` (tree + reverse_index).

### Phase 2: Impact
Determine the set of changed `notion_docs` ids from the most recent
`/notion-sync` run. (Passed as argument or inferred from git diff of
`notion_docs/`.) Run `python3 scripts/bfs-impact.py` with these ids.
Output: affected `develop_docs` ids.

### Phase 3: Refine (parallel dispatch)
For each affected id:
1. Resolve its file path from the index.
2. Load the source `notion_docs` files via `source_notion_docs[]`.
3. Dispatch a sub-agent with the prompt from `cross-ref-rules.md` and the
   source content.
4. Sub-agent produces the refined file content.
5. Main writes the file atomically.

After all files are written, re-run `docs-index.py` to refresh the index.

## Refinement rules

The sub-agent transforming notion content into develop_docs must follow:
1. Preserve structure (H2/H3 hierarchy)
2. No creative rewrite — structural reorganization and summarization only
3. Fill frontmatter per template (`templates/develop-doc-frontmatter.md`)
4. Populate `refs[]` by detecting @mentions and cross-page references
5. Compute `refinement_hash` = SHA256 of concatenated `source_notion_docs` hashes

See `cross-ref-rules.md` for detailed cross-reference semantics.

## Section preservation (Living Knowledge Base)

As of v1.0 Slice C, `develop_docs/` files may contain sections from
non-Notion sources (code, manual). These are marked with HTML provenance
comments:

- `<!-- source: notion:<id> -->` — refined from notion_docs
- `<!-- source: code:<path> -->` — derived from C# code (updated by /unity-orchestration)
- `<!-- source: manual -->` — user-authored, preserved across all updates

**Critical rule:** When refining, ONLY regenerate sections with
`source: notion:*`. Preserve `code:*` and `manual` sections verbatim.

### Algorithm update

For each affected develop_docs file:

1. `sources="$(python3 scripts/provenance.py sources path/to/file.md)"`
2. For each `source` matching `notion:*`:
   - Load the referenced notion_doc
   - Dispatch sub-agent to produce new section content
   - `python3 scripts/provenance.py replace path/to/file.md "$source" new-content.md`
3. Do NOT touch `code:*` or `manual` sections.

### Orphaned sections

If a `notion:*` source is no longer in `source_notion_docs[]`:
- Replace body with: `> DEPRECATED: source page removed from Notion (was: <id>)`
- Keep the marker so future runs don't re-create it.

### User-edited notion sections (conflict case)

If the file has been manually edited inside a `notion:*` section (detected
via `refinement_hash` mismatch for notion-only content):
- Pause and ask user: `[o]verwrite, [p]reserve (treat as manual), [a]bort`
- On "preserve", change marker to `source: manual`
- On "abort", skip this file and log

## Forbidden actions

- Do NOT call Notion MCP directly — only read from `notion_docs/`
- Do NOT write to `notion_docs/` — it's sync-engine-owned
- Do NOT modify `_meta/sync-state.json` — that's notion-sync's responsibility
- Do NOT refine files that are not in the affected list (YAGNI — those are unchanged)
