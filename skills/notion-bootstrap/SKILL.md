---
name: notion-bootstrap
description: Use when the user invokes /notion-bootstrap <main-page-url> or asks to create the Notion parts + DB matrix on an empty main page. Creates three parts (개발·아트·디자인 by default), each with two databases (메인·자료&아이디어). Records ids in raw/_meta/db-map.json and seeds sync-state.json. Idempotent within the same main page.
---

# notion-bootstrap

One-time setup of the llm-wiki Notion layout on a user-supplied main
page. Creates 3 part pages × 2 DBs = 6 databases.

**Announce at start:** "I'm using the notion-bootstrap skill to create Notion parts and databases."

## Pre-flight

1. `/init-wiki` has been run — `raw/_meta/db-map.json`,
   `sync-state.json` exist. If missing, abort and suggest running it
   first.
2. User supplied a Notion page URL (first argument). Parse to id.
3. `notion-fetch` the id → confirm it is a **page** (not database) and
   is empty or near-empty. If populated, abort with "main page already
   has content; use /notion-push or clean manually".
4. Notion MCP tools available.
5. `raw/_meta/db-map.json` has `root_page_id: null` OR equal to the
   supplied page id. Otherwise abort.

## Default parts

If the user did not override, use three parts:
- `planning` — "기획 (Planning)" — 📋  (Game design, world, story, level planning)
- `development` — "개발 (Development)" — 🛠  (Unity C# code, systems, build, tests)
- `art` — "아트 (Art)" — 🎨  (Asset production **+** Graphic/UX design — visual direction, UI wireframes, style guides)

To override, pass `--parts key1=label1,key2=label2,...`.

## Algorithm

### Phase 1 — Plan

Present to the user:

```
plan:
  main: <url>
  parts:
    - planning    → "기획 (Planning)"     (📋)
    - development → "개발 (Development)"  (🛠)
    - art         → "아트 (Art)"          (🎨)  [includes Graphic+UX design]
  per part:
    📘 메인 DB, 💡 자료&아이디어 DB
  total to create: 3 pages + 6 databases
  change detection:
    last_edited_time based (no log DB)
    default filter: 상태 ∈ {review, fixed}
```

Wait for approval.

### Phase 2 — Create part pages

Single `notion-create-pages` call with the three parts as children of
the main page. Capture returned ids per part key.

### Phase 3 — Create 📘 메인 DB per part

```json
{
  "parent": {"type": "page_id", "page_id": "<part-page-id>"},
  "title": "📘 메인",
  "schema": "CREATE TABLE (\"Title\" TITLE, \"상태\" SELECT('draft':gray, 'review':yellow, 'fixed':green), \"태그\" MULTI_SELECT(), \"수정일\" LAST_EDITED_TIME)"
}
```

Capture `<data-source-id>` into `db-map.parts.<key>.main`.

### Phase 4 — Create 💡 자료&아이디어 DB per part

```json
{
  "parent": {"type": "page_id", "page_id": "<part-page-id>"},
  "title": "💡 자료&아이디어",
  "schema": "CREATE TABLE (\"Title\" TITLE, \"유형\" SELECT('reference':blue, 'idea':purple, 'note':gray), \"태그\" MULTI_SELECT(), \"출처\" URL)"
}
```

Capture as `db-map.parts.<key>.notes`.

### Phase 5 — Overwrite main page content

Best-effort. If `notion-update-page` with `command: replace_content`
and `allow_deleting_content: true` is not available in the current MCP
build, skip with a warning and tell the user to update the body
manually (it is cosmetic, not load-bearing).

Content template:

```markdown
# <Project name>

llm-wiki 패턴 루트. 팀원(기획·디자인·아트·개발)이 Notion 에서 직접 편집하고, Claude Code 가 `/wiki-ingest` 로 로컬 `llm_wiki/` 에 정제한다.

## 파트

- 개발 (Development) — Unity 코드·시스템
- 아트 (Art) — 에셋 제작물
- 디자인 (Design) — Graphic + UX 설계

## 각 파트의 두 DB

- 📘 **메인** — 확정된 문서. `상태: fixed` 만 wiki 에 반영되는 것이 기본. 필요 시 `--include-drafts`.
- 💡 **자료&아이디어** — 개인 메모·참고·아이디어. wiki 에 자동 반영되지 않는다.

## 변경 감지

- Claude 는 각 메인 DB 를 `수정일` 내림차순으로 훑는다.
- `last_edited_time > sync-state.last_main_seen[part]` 인 row 까지만 가져가고 멈춘다.
- 별도의 로그 DB 나 사용자의 명시적 선언은 필요 없다.
```

### Phase 6 — Persist db-map.json and seed sync-state

Write `raw/_meta/db-map.json`:
```json
{
  "schema_version": 2,
  "root_page_id": "<main-id>",
  "parts": {
    "development": {"page": "<id>", "main": "<ds-id>", "notes": "<ds-id>"},
    "art":         {"page": "<id>", "main": "<ds-id>", "notes": "<ds-id>"},
    "design":      {"page": "<id>", "main": "<ds-id>", "notes": "<ds-id>"}
  }
}
```

Write `raw/_meta/sync-state.json`:
```json
{
  "schema_version": 3,
  "last_sync": null,
  "last_push_commit": null,
  "last_main_seen": {"development": null, "art": null, "design": null},
  "rows": {},
  "orphans": []
}
```

Create per-part folders: `raw/<part>/main/` and `raw/<part>/notes/` via
`mkdir -p`. **No `log.md`** — the log concept is removed.

### Phase 7 — Report

```
notion-bootstrap complete:
  root page: <url>
  parts: development, art, design
  databases: 6 (3 메인, 3 자료&아이디어)
  change detection: last_edited_time + sync-state.last_main_seen
  default ingest filter: 상태 ∈ {review, fixed}
  next:
    1) Notion 의 한 파트 📘 메인 DB 에 row 1건 + 본문 작성 + 상태=fixed.
    2) /wiki-ingest — Claude 가 자동으로 감지·ingest.
```

## Idempotency

- Rerunning with the same main page id and populated `db-map.json`
  aborts with a clean message.
- Different main page id with populated db-map aborts with "bootstrap
  already targets <old id>".

## Forbidden

- Do NOT create a log DB. The log concept is removed in this version.
- Do NOT create any row beyond DB skeletons.
- Do NOT overwrite `db-map.json` when already populated.
- Do NOT run `/wiki-ingest` from within this skill.

## Arguments

- `<main-page-url>` (required) — empty page that becomes the root.
- `--parts key=label[,key=label...]` — override defaults.
- `--dry-run` — stop after Phase 1.
