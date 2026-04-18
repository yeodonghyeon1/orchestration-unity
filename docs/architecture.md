---
id: plugin-docs.architecture
title: Architecture Overview
owner: developer
status: stable
updated: 2026-04-18
version: 1.0.0
tags: [architecture, v1]
---

# Architecture Overview (v1.0)

This document describes the **v1.0 redesign**. For the currently-shipped v0.2.0 (10-agent consensus), see `architecture.md`. Full design rationale lives in `docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md`.

## What Changed from v0.2.0

v0.2.0 was a **10-agent consensus team** with voting, pair review, and playtest. v1.0 abandons that model entirely in favor of a **Notion-driven Superpowers pipeline**.

| Dimension | v0.2.0 | v1.0 |
|-----------|--------|------|
| Source of truth | Slash command argument | Notion workspace |
| Team | 10 agents (voting, pairs, tester) | Main Claude + ad-hoc sub-agents |
| Plan artifact | `TaskList` | `docs/superpowers/plans/*.md` (file-based) |
| Discipline | Pair review + voting | Superpowers skills (TDD, verification, etc.) |
| Docs pipeline | Recorder agents | Deterministic sync engine |
| Slash commands | 1 (`/unity-orchestration`) | 4 (sync, refine, update, orchestrate) |

## Pipeline (Five Stages)

```
[1] Human writes Notion (개발 / 아트 / 기획)
        │
        ▼ /notion-sync
[2] notion_docs/           ← raw 1:1 mirror
        │
        ▼ /docs-refinement
[3] develop_docs/          ← Claude-refined, cross-referenced
        │
        ▼ auto-commit + push to sync branch
[4] Git branch sync/notion-YYYYMMDD-HHMM  (human merges)
        │
        ▼ /unity-orchestration <task>
[5] Superpowers workflow + Unity MCP implementation
```

`/docs-update` runs stages 1-4 in one shot.

## Components

### Skills

| Skill | Purpose | Invokes Superpowers? |
|-------|---------|----------------------|
| `unity-orchestration` | Main workflow entry (Stage 5) | Yes: brainstorming → writing-plans → executing-plans → TDD → verification |
| `notion-sync` | Stage 1 → Stage 2 | No (pure sync) |
| `docs-refinement` | Stage 2 → Stage 3 | No (deterministic refinement) |

### Slash Commands

| Command | Scope |
|---------|-------|
| `/notion-sync` | Stage 1 → 2 only |
| `/docs-refinement` | Stage 2 → 3 only |
| `/docs-update` | Stages 1 → 4 (full sync + push) |
| `/unity-orchestration <task>` | Stage 5 (game dev workflow) |

### Scripts

- `init-workspace.sh` — seeds `notion_docs/` and `develop_docs/` on first run
- `update-docs-index.py` — regenerates `_meta/index.json` (tree + reverse_index); fixes v0.2.0 `_self` bug
- `notion-hash.py` — deterministic content hashing for change detection

### State Storage (Two Layers)

**Layer A** — per-file frontmatter (self-contained):
```yaml
notion_page_id: "uuid"
notion_last_edited: "ISO8601"
content_hash: "sha256:..."
```

**Layer B** — central catalog at `notion_docs/_meta/sync-state.json` (authoritative on conflict; required for deletion detection).

## Runtime Model

- **Single-process** — `main` Claude drives the pipeline. Sub-agents are spawned only when dispatching to refine multiple files in parallel (via `superpowers:subagent-driven-development`).
- **No team coordination** — no `TeamCreate`, no `SendMessage`, no MCP lock protocol. Unity MCP is still serialized because Unity itself locks files, but serialization happens at the call site, not a global lock service.
- **Idempotent** — running `/docs-update` twice with no Notion changes produces zero git diff.

## Docs Schema

Two parallel trees at project root:

```
project-root/
├── notion_docs/
│   ├── _meta/{sync-state.json, index.json, page-map.json}
│   ├── dev/        (from "개발" page)
│   ├── art/        (from "아트" page)
│   └── plan/       (from "기획" page)
└── develop_docs/
    ├── _meta/index.json
    ├── game/       (engine-agnostic logic)
    ├── design/     (UX, art direction)
    ├── tech/       (Unity-specific)
    ├── decisions/  (ADRs)
    └── tasks/      (Superpowers plan summaries)
```

Key frontmatter fields:
- `id` — path-ID (folder separator `.` instead of `/`)
- `source_notion_docs[]` — reverse link back to Notion sources (drives impact graph)
- `refs[]` — cross-references with relationship types (`uses` / `extends` / `contradicts` / `supersedes`)

See full schema in the spec Section 7.

## Change Detection (Incremental Sync)

Four-step pipeline, designed to minimize tokens and API calls:

```
Step 1: Timestamp pre-filter    → skip pages with unchanged last_edited
Step 2: Content hash verify     → skip pages with no real content change
Step 3: Impact graph BFS        → find affected develop_docs via reverse index
Step 4: Parallel dispatch       → sub-agents refine only affected files
```

## Modular Expansion

The sync/refinement code is **domain-agnostic**: no hardcoded folder names like `art` or `plan`. All mappings come from `_meta/page-map.json`. Adding a new Notion top-level page (e.g., `레벨`) triggers a prompt asking the user to confirm the folder slug; the rest is automatic.

See spec Section 16 for the full expansion principles (M1-M5).

## Testing Layers

- **L1 — structure check** (`tests/structure-check.sh`) — plugin scaffold integrity
- **L2 — script unit tests** (`tests/sync-engine-tests/*.test.sh`) — hash, path-ID, BFS, index generation
- **L3 — integration** (`tests/fixture/`) — mock Notion MCP responses, end-to-end sync
- **L4 — manual scenarios** (`tests/manual-scenarios.md`) — real Notion workspace tests

TDD is required (per `superpowers:test-driven-development`) for all new code.

## Dependencies

- **Claude Code** (host)
- **Superpowers plugin** — workflow skills
- **Notion MCP** (`claude_ai_Notion` or equivalent) — Stage 1 read access
- **unity-mcp** MCP server — Stage 5 implementation
- **A Unity project** — Stage 5 target
- **Python 3** and **bash** — scripts

## Migration

v0.2.0 → v1.0 is a **breaking change**. Migration guidance:
1. Existing `docs/` tree from v0.2.0 can be mapped to `develop_docs/`
2. `.orchestration/sessions/` artifacts are preserved but unused
3. 10-agent prompts and voting scripts are deleted
4. CHANGELOG.md marks the release as `BREAKING`

See spec Section 12 for details.
