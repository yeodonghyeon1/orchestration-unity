# Changelog

All notable changes to this plugin are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org/).

## [Unreleased]

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
