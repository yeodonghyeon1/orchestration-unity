# v1.0.0 Smoke Test (Manual)

Run on a **fresh Unity project** (or a copy) with a **test Notion workspace**.

## Pre-conditions

- [ ] orchestration-unity v1.0.0 installed
- [ ] Superpowers plugin installed
- [ ] Notion MCP connected
- [ ] unity-mcp MCP connected
- [ ] Test Unity project with `Assets/` + `ProjectSettings/`

## Init

- [ ] Run `bash scripts/init-workspace.sh .`
- [ ] Verify `notion_docs/_meta/sync-state.json` exists
- [ ] Verify `develop_docs/_meta/index.json` will exist after first refinement
- [ ] Verify `notion_docs/_meta/page-map.json` has `mappings: []`

## First sync

- [ ] Create 3 test Notion pages: `개발`, `아트`, `기획`
- [ ] Run `/notion-sync`
- [ ] Confirm folder mapping prompts appear (3 times, one per page)
- [ ] Verify `notion_docs/dev/`, `notion_docs/art/`, `notion_docs/plan/` populated
- [ ] Check frontmatter fields: `notion_page_id`, `content_hash`, `synced_at`

## Idempotent re-sync

- [ ] Run `/notion-sync` again without changes
- [ ] Expected: 0 file diffs, "no changes" summary

## Edit detection

- [ ] Edit one Notion page (add a paragraph)
- [ ] Run `/notion-sync`
- [ ] Expected: only that page's `.md` updated (hash changed)

## Refinement

- [ ] Run `/docs-refinement`
- [ ] Verify `develop_docs/game/` or `develop_docs/design/` populated
- [ ] Verify `source_notion_docs[]` frontmatter set correctly

## Full pipeline

- [ ] Run `/docs-update`
- [ ] Verify new branch `sync/notion-YYYYMMDD-HHMM` created
- [ ] Verify 2 commits: one for notion_docs, one for develop_docs
- [ ] Verify push to origin succeeded (or local branch if offline)
- [ ] Verify `main` is NOT modified

## Game dev workflow

- [ ] Run `/unity-orchestration "add a simple enemy patrol script"`
- [ ] Verify brainstorming runs (HARD-GATE prompts appear)
- [ ] Approve plan at user gate
- [ ] Verify TDD discipline: failing test written first
- [ ] Verify `unity-mcp` calls made for scene/prefab work
- [ ] After completion: verify `develop_docs/tech/unity/` updated with new C# signatures

## Migration

- [ ] On a v0.2.0 sample project, run `bash scripts/migrate-v02-to-v1.sh`
- [ ] Verify `docs/` tree moved to `develop_docs/`
- [ ] Verify `notion_docs/` scaffolded
- [ ] Verify `.orchestration/sessions/` preserved intact

## Pass criteria

All checkboxes above must be checked. File any failures at
<https://github.com/yeodonghyeon/orchestration-unity/issues>.
