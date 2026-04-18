# Changelog

All notable changes to this plugin are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org/).

## [2.0.0] — 2026-04-19

### BREAKING
- **llm-wiki pattern redesign.** Directory names, skill names, and Notion
  structure all changed. No automatic migration script — projects on v1.0
  must re-bootstrap.
- **Plugin is now scriptless.** `scripts/` directory entirely removed.
  All logic previously in Python/bash helpers lives inside `SKILL.md`
  instructions (Bash + Notion MCP + Read/Write). Motivation: keep the
  plugin project-agnostic — no hardcoded paths or project-specific
  schemas.
- **Removed commands**: `/notion-sync`, `/docs-refinement`, `/docs-update`.
  Their function is merged into `/wiki-ingest`.
- **Notion structure**: part pages now contain **two** databases
  (📘 메인, 💡 자료&아이디어) instead of three. The 🗂 로그 DB is gone.
- **Change detection**: no longer driven by a log database. Each part's
  📘 메인 is paginated by `last_edited_time DESC` and stops when reaching
  `sync-state.last_main_seen[part]`.
- Local trees renamed: `notion_docs/` → `raw/`, `develop_docs/` → `llm_wiki/`.
- `raw/_meta/db-map.json` schema v2 (log fields removed).
- `raw/_meta/sync-state.json` schema v3 (`last_log_seen` →
  `last_main_seen` + `last_notes_seen`).

### Added
- `skills/init-wiki/` — seed local `raw/` + `llm_wiki/` skeleton.
- `skills/wiki-ingest/` — log-free Notion → local sync with `상태` filter.
- `skills/wiki-sync-code/` — regenerate `llm_wiki/tech/**` from modified
  `Assets/**/*.cs` sections (`<!-- source: code:<path> -->`).
- `skills/wiki-query/` — wiki-grounded Q&A with citations; optional
  filing into `llm_wiki/explorations/`.
- `skills/wiki-lint/` — orphan/stale-draft/contradiction/broken-link audit.
- `skills/notion-bootstrap/` — creates 3 parts × 2 DBs; log-free schema.
- `skills/notion-push/` — reverse sync (wiki → Notion 메인 row); preserves
  `<!-- source: manual -->` blocks.
- `hooks/hooks.json` + `hooks/on-file-edit.sh` — post-edit suggestions
  (non-invasive; emits `systemMessage` hints, no auto-invocation).
- Commands: `/init-wiki`, `/wiki-ingest`, `/wiki-sync-code`, `/wiki-query`,
  `/wiki-lint`, `/notion-bootstrap`, `/notion-push`.

### Changed
- `skills/unity-orchestration/` — Step 2 context now reads
  `llm_wiki/index.md` + `llm_wiki/log.md` (last 20 lines); Step 10 calls
  `/wiki-sync-code` after verification.
- Plugin description updated to reflect the scriptless llm-wiki pattern.

### Removed
- `scripts/` directory (14 files — `sync-state.py`, `page-map.py`,
  `notion-hash.py`, `bfs-impact.py`, `docs-index.py`, `provenance.py`,
  `code-to-docs.py`, `code-doc-updater.sh`, `init-workspace.sh`,
  `migrate-v02-to-v1.sh`, `update-docs-index.py`, and variants).
- `skills/notion-sync/`, `skills/docs-refinement/`.
- `commands/notion-sync.md`, `commands/docs-refinement.md`,
  `commands/docs-update.md`.

### Rationale
- v1.0's log DB required users to make an explicit log entry every time a
  메인 row changed. In practice, users edit `상태: fixed` and forget the
  log — sync silently ignored the change. v2 closes that gap by using
  `last_edited_time` directly.
- Python scripts forced every project to keep the plugin's helpers in
  sync. Moving logic into SKILL.md keeps the plugin source-free and
  project-agnostic.

## [1.0.0] — 2026-04-18

### BREAKING
- Complete redesign: 10-agent consensus team replaced with Notion-driven Superpowers pipeline.
- `/unity-orchestration` arguments, skill names, and workflow semantics have all changed. Existing v0.2.0 users should run `bash scripts/migrate-v02-to-v1.sh`.
- Removed: `skills/unity-orchestration/agents/*.md`, `voting.md`, `consultation-table.md`, `scripts/tally-votes.sh`, `agents/unity-orchestrator.md`.

### Added
- Two-tier docs: `notion_docs/` (raw Notion mirror) + `develop_docs/` (refined, cross-referenced).
- `/notion-sync`, `/docs-refinement`, `/docs-update` slash commands.
- `scripts/notion-hash.py` — deterministic SHA256 of Notion content.
- `scripts/page-map.py` — Notion page → folder mapping.
- `scripts/sync-state.py` — `_meta/sync-state.json` management.
- `scripts/docs-index.py` — `_meta/index.json` with tree + reverse_index (fixes v0.2 `_self` bug).
- `scripts/bfs-impact.py` — reverse-index BFS traversal.
- `scripts/provenance.py` — HTML-comment section-level source markers.
- `scripts/code-to-docs.py` — C# public surface → markdown.
- `scripts/code-doc-updater.sh` — post-implementation develop_docs updater.
- `scripts/migrate-v02-to-v1.sh` — migrate existing v0.2.0 projects.
- `skills/notion-sync/` — 4-step change detection.
- `skills/docs-refinement/` — BFS-based incremental refinement.
- Rewritten `skills/unity-orchestration/` — 11-step Superpowers chain orchestrator.
- Section-level provenance (`notion:*` / `code:*` / `manual`) for Living Knowledge Base.
- Integration tests: notion-sync, docs-refinement, preservation, unity-orchestration flow, migration.
- Docs: `architecture.md` (v1 promoted), `notion-schema-guide.md`, full spec at `docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md`.

### Changed
- `scripts/update-docs-index.py` → forwarding shim to `docs-index.py`.
- `scripts/init-workspace.sh` now seeds `notion_docs/` and `develop_docs/` dual trees.
- v0.2.0 docs archived under `docs/archive/v0.2/`.

### Preserved
- `.orchestration/sessions/` content from v0.2.0 sessions (unused in v1.0 but not deleted).
- `docs/superpowers/specs/2026-04-11-unity-orchestration-design.md` (v0.2.0 design spec).

## [0.2.0] — 2026-04-13

### Added
- Tester agent (`tester`) — solo agent that play-tests implemented features
  via `unity-mcp`, inventing scenarios on the fly and reporting bugs from a
  gamer perspective with severity levels (critical/major/minor/nit).
- Phase 5 (Playtest) inserted between Execution and Accept Vote; workflow
  is now eight phases instead of seven.
- Testability input: tester raises testability concerns during Phase 1 and
  Plan Vote so all agents consider them during their work.
- Critical playtest findings gate Phase 6 — must be hotfixed before accept
  vote proceeds.
- Playtest findings are promoted to `docs/tasks/<id>/playtest.md` during
  Close phase.

### Changed
- Team size: 9 → 10 agents (added 1 tester, no pair).
- Vote threshold: 5/9 → 6/10 for both Plan Vote and Accept Vote.
- Planner acceptance criteria must be observable in-game for tester
  verification.
- Designer scenes must consider playability and testability.
- Developers implement debug shortcuts (`#if UNITY_EDITOR`) when tester
  requests them.
- Phase numbering shifted: Accept Vote is now Phase 6, Close is Phase 7.

## [0.1.1] — 2026-04-13

### Fixed
- Recorder agent infinite loading caused by retry loops on missing files,
  ambiguous skill-relative paths, excessive first-turn workload, and
  SendMessage deadlocks.
- Added anti-deadlock rules: skip-on-failure, never-block-on-reply, and
  2-tool-call timeout for first-turn checklist steps.
- Team lead now injects task/session_path directly into spawn prompts and
  spawns all 8 agents in parallel.
- Phase 1 timeout: agents must submit proposals in first turn or submit
  partial proposals instead of looping.

## [0.1.0] — 2026-04-11

### Added
- Plugin scaffold (`.claude-plugin/plugin.json`, LICENSE, README, CHANGELOG).
- `unity-orchestration` skill entry point (`SKILL.md`) and four reference
  docs (`workflow.md`, `voting.md`, `consultation-table.md`, `docs-tree-spec.md`).
- Five role prompts (`team-lead`, `planner`, `designer`, `developer`, `recorder`).
- Slash command `/unity-orchestration` and bootstrap agent
  `unity-orchestrator`.
- Templates: proposal, vote, ADR, frontmatter, and a seed docs-tree.
- Scripts: `init-workspace.sh`, `tally-votes.sh`, `update-docs-index.py`.
- Plugin-level docs: getting-started, architecture, troubleshooting.
- Test suite: `tests/structure-check.sh` + three script unit tests + manual
  scenarios.
- Full design spec and implementation plan under `docs/superpowers/`.

### Known limitations
- No automatic session resume (manual in v1).
- No multi-session parallelism.
- Unity-only (no Godot/Unreal support).
- Scenario tests are a manual checklist, not CI-automated.
- `update-docs-index.py` tree schema mixes parent entry fields with child
  branches when a parent doc (e.g. `game`) has children (e.g.
  `game.systems.combat`). Functionally correct — back-links still
  resolve — but consumers iterating a tree node see entry fields and
  child keys intermingled. Planned cleanup for v0.2.0 via a `_self`
  sentinel key.
