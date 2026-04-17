---
id: specs.orchestration-unity-v1
title: "orchestration-unity v1.0 — Notion-driven Superpowers Pipeline (Design Spec)"
status: draft
date: 2026-04-18
owner: yeodonghyeon1
version: 1.0.0-draft
tags: [spec, orchestration-unity, superpowers, notion-mcp, unity-mcp]
supersedes: 2026-04-11-unity-orchestration-design.md
---

# orchestration-unity v1.0 — Design Spec

## 1. Summary

Complete redesign of `orchestration-unity` from a 10-agent consensus team (v0.2.0) to a **Notion-driven Superpowers pipeline**. The new plugin uses:

- **Notion** — human creative surface (Art / 기획 / 개발)
- **Git (feature branch)** — verified snapshot
- **Two-tier project docs** — `notion_docs/` (raw mirror) + `develop_docs/` (Claude-refined tree)
- **Superpowers workflow** — brainstorming → writing-plans → TDD → verification
- **Unity MCP** — implementation layer (scenes, prefabs, C#, test runner)

The 10-agent consensus mechanism, voting system, pair-review pattern, and playtest phase from v0.2.0 are fully deprecated.

## 2. Motivation

v0.2.0 post-mortem identified 12 gaps between unity-orchestration and Superpowers conventions. The most critical:

1. No TDD enforcement (production code without failing test)
2. No brainstorming gate before planning
3. No formal plan artifact (TaskList used instead of plan file)
4. No verification-before-completion discipline
5. No integration with systematic-debugging or code-review skills

Rather than patch these gaps on top of the consensus team, v1.0 **adopts Superpowers' own workflow as the spine** and refocuses the plugin on what it uniquely provides: Notion-to-docs-to-Unity data flow orchestration.

## 3. Goals / Non-Goals

### Goals
- G1: Single source of truth for game design lives in Notion
- G2: Incremental sync (change only what changed) to minimize token cost
- G3: Two-tier docs with explicit cross-references (like code imports)
- G4: Full Superpowers discipline (TDD, verification, plan-before-code)
- G5: Unity MCP used uniformly for implementation, testing, debugging
- G6: Auto-push to sync branch; human always controls merge
- G7: `develop_docs/` evolves as a **living knowledge base** — updated by Notion sync, by code changes during development, and by user manual edits (Section 17)

### Non-Goals
- NG1: Supporting non-Unity engines (Godot/Unreal out of scope for v1)
- NG2: Multi-user concurrent syncing
- NG3: Bidirectional sync (git → Notion write-back); Notion is read-only for Claude
- NG4: Real-time sync triggered by Notion webhooks (user-initiated only)
- NG5: Backward compatibility with v0.2.0 slash commands (breaking change declared)

## 4. Architecture

### 4.1 Five-Stage Pipeline

```
[Stage 1] Human writes Notion pages (Art / 기획 / 개발)
              │
              ▼ (1) /docs-update OR /notion-sync
[Stage 2] notion_docs/ — raw mirror (1:1 page-to-file)
              │
              ▼ (2) /docs-update OR /docs-refinement
[Stage 3] develop_docs/ — Claude-refined, modular, cross-referenced tree
              │
              ▼ (3) auto-commit to sync branch, push
[Stage 4] git branch sync/notion-YYYYMMDD-HHMM — human merges manually
              │
              ▼ (4) /unity-orchestration <task>
[Stage 5] Superpowers workflow → Unity MCP implementation
```

### 4.2 Component Topology

| Layer | System | Role |
|-------|--------|------|
| Human | Notion | Creative authoring (Art, Plan, Dev) |
| Read | Notion MCP | Fetch pages, detect timestamps |
| Mirror | `notion_docs/` | Exact Notion reflection, frontmatter-tagged |
| Refine | Sub-agents | Transform mirror into semantic dev docs |
| Author | `develop_docs/` | Working knowledge for game development |
| Orchestrate | `orchestration-unity` v1.0 | Pipeline glue |
| Discipline | Superpowers skills | brainstorming, TDD, verification, etc. |
| Implement | Unity MCP | Scene, prefab, C#, test runner |

### 4.3 Plugin Identity

- Plugin name: `orchestration-unity` (unchanged)
- Skill name: `unity-orchestration` (unchanged)
- Version: `v1.0.0` (breaking change from `v0.2.0`)

## 5. Components: Delete / Keep / Add

### 5.1 Delete (v0.2.0 artifacts removed)

- `skills/unity-orchestration/agents/*.md` (all 10 role prompts)
- `skills/unity-orchestration/voting.md`
- `skills/unity-orchestration/consultation-table.md`
- `scripts/tally-votes.sh`
- `agents/unity-orchestrator.md` (bootstrap agent)
- Voting/phase language in workflow.md

### 5.2 Keep (reused with extensions)

- `skills/unity-orchestration/docs-tree-spec.md` — frontmatter, path-ID, `_meta/index.json`
- `scripts/init-workspace.sh` — extended to seed both trees
- `scripts/update-docs-index.py` — extended for two trees; `_self` bug fix included
- `templates/docs-tree/` — frontmatter templates
- Plugin scaffold: `.claude-plugin/plugin.json`, LICENSE, README, CHANGELOG

### 5.3 Add (new in v1.0)

```
orchestration-unity/
├── skills/
│   ├── unity-orchestration/
│   │   ├── SKILL.md                  # rewritten: pipeline orchestrator
│   │   ├── workflow.md               # rewritten: 5-stage pipeline
│   │   └── docs-tree-spec.md         # extended
│   ├── notion-sync/                  # NEW
│   │   ├── SKILL.md
│   │   ├── change-detection.md
│   │   └── templates/
│   └── docs-refinement/              # NEW
│       ├── SKILL.md
│       └── cross-ref-rules.md
├── commands/
│   ├── unity-orchestration.md        # rewritten
│   ├── notion-sync.md                # NEW
│   ├── docs-refinement.md            # NEW
│   └── docs-update.md                # NEW (meta: sync + refine + push)
├── scripts/
│   ├── init-workspace.sh             # extended
│   ├── update-docs-index.py          # extended + bug fix
│   └── notion-hash.py                # NEW
└── tests/
    ├── structure-check.sh
    ├── sync-engine-tests/            # NEW
    └── fixture/                      # NEW
```

## 6. Sync Engine

### 6.1 Two-Layer State Storage

**Layer A — per-file frontmatter (self-contained)** lives in each `notion_docs/*.md`:

```yaml
---
id: plan.combat-system
notion_page_id: "a1b2c3d4-..."
notion_last_edited: "2026-04-18T09:12:33Z"
content_hash: "sha256:7f3a9b..."
synced_at: "2026-04-18T09:15:02Z"
---
```

**Layer B — central catalog** at `notion_docs/_meta/sync-state.json`:

```json
{
  "schema_version": 1,
  "last_sync": "2026-04-18T09:15:02Z",
  "pages": {
    "a1b2c3d4-...": {
      "path": "plan/combat-system.md",
      "hash": "sha256:7f3a9b...",
      "notion_last_edited": "2026-04-18T09:12:33Z"
    }
  },
  "orphans": []
}
```

Layer B is authoritative on conflict. It is the only place deletion can be detected globally.

### 6.2 Four-Step Change Detection Pipeline

**Step 1 — Timestamp Pre-Filter** (API reduction):
Fetch page list via `notion-search`; compare `last_edited_time` against Layer B. Only newer pages continue.

**Step 2 — Content Hash Verification** (false-positive elimination):
Fetch full content via `notion-fetch` for candidates. Normalize (trim whitespace, canonical newlines, sort blocks). Compute SHA256. Compare against Layer A. Only real content changes continue.

**Step 3 — Impact Graph BFS** (scope determination):
Scan all `develop_docs/*.md` frontmatter for `source_notion_docs[]`. Build reverse index. For each real change, BFS outward to find affected `develop_docs` files. Break cycles on first revisit with warning.

**Step 4 — Parallel Dispatch** (token distribution):
Dispatch real changes to sub-agents for `notion_docs` update. Dispatch affected `develop_docs` files to sub-agents for refinement. Each sub-agent gets one file in context. On completion, atomically update Layer A and Layer B.

### 6.3 Deletion Handling

Automatic — no safety flag. If a page exists in Layer B but is absent from current Notion fetch:
1. Move entry to `orphans[]` in sync-state.json
2. Delete corresponding `notion_docs/*.md`
3. For affected `develop_docs` files (via reverse index), mark `status: deprecated` and remove from `source_notion_docs[]`
4. Commit deletions on a separate commit for git diff visibility

The sync branch + human-merge workflow is the safety net — accidental deletions are recoverable before merge.

### 6.4 Initial Seed (First Run)

No special flag. When `sync-state.json` is absent:
- All pages treated as new → full fetch
- `develop_docs/` generated from scratch
- Log page count and expected token estimate
- Proceeds automatically

### 6.5 Idempotency

- Hash normalization is deterministic (whitespace, block order canonicalized)
- Sub-agent refinement prompts forbid creative rewrites (structural transformation only)
- State file updates are atomic (write temp + rename)

## 7. Docs Schema

### 7.1 Tree Organization

```
project-root/
├── notion_docs/
│   ├── _meta/
│   │   ├── sync-state.json
│   │   └── index.json
│   ├── art/
│   ├── plan/
│   └── dev/
└── develop_docs/
    ├── _meta/
    │   └── index.json
    ├── game/         # engine-agnostic logic
    ├── design/       # UX, art direction
    ├── tech/         # Unity-specific
    ├── decisions/    # ADRs
    └── tasks/        # Superpowers plan summaries
```

### 7.2 notion_docs frontmatter

```yaml
---
id: plan.combat-system
notion_page_id: "a1b2c3d4-..."
title: "전투 시스템 설계"
notion_last_edited: "2026-04-18T09:12:33Z"
content_hash: "sha256:..."
synced_at: "2026-04-18T09:15:02Z"
source_url: "https://notion.so/..."
notion_parent: plan
children: [plan.combat-system.damage-formula]
---
```

`notion_docs/` files are **auto-generated — manual edits are forbidden and will be overwritten on next sync**. Enforced by documentation; runtime warning emitted if modification detected (hash mismatch with none of Notion's pages).

### 7.3 develop_docs frontmatter

```yaml
---
id: game.systems.combat
title: "Combat System"
status: draft | stable | deprecated

source_notion_docs:
  - plan.combat-system
  - plan.combat-system.damage-formula
  - art.concept-direction#combat-visuals

refs:
  - id: game.entities.player
    rel: uses
  - id: tech.unity.scripting-patterns
    rel: implements

owner: claude
last_refined: "2026-04-18T10:22:11Z"
refinement_hash: "sha256:..."
---
```

### 7.4 Path-ID Convention

- Folder separator `/` → `.`
- Extension `.md` stripped
- File names in `kebab-case`; path-ID preserves them
- Section anchors via `#`: `plan.combat-system#damage-formula`

### 7.5 Cross-Reference Relationship Types

| rel | Semantics | Propagation |
|-----|-----------|-------------|
| `uses` | A consumes B's API or data | B changes → A re-refinement |
| `extends` | A specializes B | B signature changes → A re-refinement |
| `contradicts` | A and B conflict (known issue) | No propagation; surface warning |
| `supersedes` | A replaces B (B deprecated) | Reverse only; B changes ignored |

### 7.6 `_meta/index.json` Schema (v2)

```json
{
  "schema_version": 2,
  "tree": {
    "game.systems.combat": {
      "_self": {
        "path": "game/systems/combat.md",
        "title": "Combat System",
        "status": "stable"
      },
      "children": ["game.systems.combat.damage"]
    }
  },
  "reverse_index": {
    "plan.combat-system": ["game.systems.combat"]
  }
}
```

The `_self` key fixes the v0.2.0 known bug where parent fields and child keys intermingled. `reverse_index` is the BFS engine in Step 3 of the sync pipeline.

## 8. Slash Commands

| Command | Scope | Calls Superpowers? |
|---------|-------|--------------------|
| `/notion-sync` | Notion → `notion_docs/` only | No |
| `/docs-refinement` | `notion_docs/` → `develop_docs/` only | No |
| `/docs-update` | Full: sync + refine + branch + commit + push | No |
| `/unity-orchestration <task>` | Game dev workflow | Yes (full chain) |

### 8.1 `/unity-orchestration` Internal Flow

```
1.  superpowers:brainstorming         (HARD-GATE: no code without design)
2.  Load relevant develop_docs files
3.  superpowers:writing-plans         (output: docs/superpowers/plans/YYYY-MM-DD-<slug>.md)
4.  [User approval gate]
5.  superpowers:using-git-worktrees   (optional; recommended for big tasks)
6.  superpowers:executing-plans  OR  superpowers:subagent-driven-development
7.    └─ superpowers:test-driven-development  (per task)
8.    └─ unity-mcp calls                      (scene, prefab, C#)
9.  superpowers:verification-before-completion
10. **NEW in v1.0**: update develop_docs with code-derived sections (see Section 17.4)
11. superpowers:finishing-a-development-branch
```

## 9. Git Strategy

- Branch name: `sync/notion-YYYYMMDD-HHMM` (one branch per `/docs-update` run)
- Two commits per run:
  - Commit 1: `notion_docs/` changes
  - Commit 2: `develop_docs/` changes
- Auto-push to `origin`
- **Never** push to `main` directly; human always merges via PR
- If push fails: keep local branch, notify user for manual push

## 10. Error Handling

| Error | Response |
|-------|----------|
| Notion MCP timeout | Abort sync; preserve prior state; no commit |
| Hash calc failure on one page | Skip page; log; continue with others |
| BFS cycle detected | Break on first revisit; log warning |
| Sub-agent dispatch failure | Retry once; then skip and report |
| Git push failure | Keep local branch; notify user |
| Schema version mismatch | Log migration need; run migrator; bump version |
| `develop_docs` manual edit detected (mid-refinement) | Stop, ask user: overwrite / skip / abort |

## 11. Testing Strategy

### 11.1 Unit
- `scripts/notion-hash.py` — hash normalization determinism
- `scripts/update-docs-index.py` — tree + reverse_index generation
- Path-ID parser — round-trip: folder/file → id → folder/file
- BFS traversal — cycle handling, max depth, reverse direction

### 11.2 Integration
- Mock Notion MCP responses in `tests/fixture/`
- End-to-end: fixture → `notion_docs/` generation
- Diff scenarios: add page, edit page, delete page, rename page, restructure hierarchy

### 11.3 Manual Scenarios
- Real `/docs-update` against an actual Notion workspace
- Checklist under `tests/manual-scenarios.md`

### 11.4 TDD Discipline
All new code written test-first per Superpowers convention. CI (future) runs unit + integration.

## 12. Migration from v0.2.0

1. On first `v1.0.0` install, detect existing `docs/` tree (v0.2.0 style)
2. Offer auto-migration: `docs/` → `develop_docs/`
3. Preserve `.orchestration/sessions/` (informational, unused)
4. Remove v0.2.0-only artifacts (voting, consultation, 10 role prompts)
5. `CHANGELOG.md` entry clearly labeled `BREAKING`

### 12.1 Compatibility Matrix

| Component | v0.2.0 | v1.0.0 |
|-----------|--------|--------|
| Consensus team | ✓ | ✗ removed |
| Voting | ✓ | ✗ removed |
| Playtest agent | ✓ | ✗ (use `/unity-orchestration` + manual test) |
| docs-tree-spec | ✓ | ✓ extended |
| `.orchestration/sessions/` | ✓ active | preserved but unused |
| Slash command `/unity-orchestration` | task string | structured workflow |

## 13. Open Questions (to resolve in writing-plans)

- ~~Q1~~: **RESOLVED 2026-04-18** — Notion workspace starts with 3 top-level pages (`개발` / `아트` / `기획`). Additional top-level pages are expected later. See Section 16 for schema details and modular-expansion principles.
- Q2: Refinement sub-agent prompt template — what constitutes "structural transformation" vs "creative rewrite"? Needs examples.
- Q3: Handling Notion toggle/synced-block content — include as nested or flatten?
- Q4: `develop_docs` manual edits by user — how to reconcile on next refinement? Merge strategy?
- Q5: Token budget alerts — threshold for `/docs-update` warning user before proceeding?

## 14. Acceptance Criteria for v1.0.0 Release

- [ ] `/notion-sync` produces correct `notion_docs/` from a test workspace
- [ ] `/docs-refinement` produces cross-referenced `develop_docs/` from `notion_docs/`
- [ ] Hash-based change detection skips unchanged pages (verified with fixture)
- [ ] BFS reverse-index correctly identifies affected develop_docs on mock change
- [ ] `/docs-update` commits to branch and pushes to origin
- [ ] `/unity-orchestration` invokes Superpowers chain (brainstorming through finishing-branch)
- [ ] v0.2.0 → v1.0.0 migration tested on sample project
- [ ] CHANGELOG.md entry with BREAKING label
- [ ] README updated with new workflow diagram
- [ ] Structure-check tests pass
- [ ] Unit tests cover hash, path-ID, BFS, index generation

## 15. References

- v0.2.0 source: `~/.claude/plugins/cache/orchestration-unity/unity-orchestration/0.2.0/`
- Superpowers skills: `~/.claude/plugins/cache/superpowers-marketplace/superpowers/5.0.7/skills/`
- Notion MCP tools (installed): `mcp__claude_ai_Notion__*` (14 tools)
- Unity MCP: <https://github.com/CoplayDev/unity-mcp>

## 16. Notion Workspace Structure & Modular Expansion

### 16.1 Initial Structure (v1.0 release baseline)

Three top-level pages under a single root workspace:

```
[Game Dev workspace root]
├── 개발 (Dev)        → notion_docs/dev/
├── 아트 (Art)        → notion_docs/art/
└── 기획 (Plan)       → notion_docs/plan/
```

Each top-level page may have arbitrary child pages (sub-pages, databases, nested pages). Children are mirrored as sub-files/sub-folders under the corresponding top-level folder.

### 16.2 Korean → Folder Name Mapping

Notion page titles can be any language (Korean in practice). Folder names in `notion_docs/` are **ASCII kebab-case** for git compatibility and path-ID stability.

| Notion title | `notion_docs/` folder | Path-ID root |
|--------------|---------------------|--------------|
| 개발 | `dev/` | `dev` |
| 아트 | `art/` | `art` |
| 기획 | `plan/` | `plan` |

The mapping is stored in a dedicated config file `notion_docs/_meta/page-map.json`:

```json
{
  "schema_version": 1,
  "mappings": [
    { "notion_page_id": "uuid-...", "notion_title": "개발", "folder": "dev" },
    { "notion_page_id": "uuid-...", "notion_title": "아트", "folder": "art" },
    { "notion_page_id": "uuid-...", "notion_title": "기획", "folder": "plan" }
  ],
  "auto_slugify": true
}
```

On first sync, the user confirms (or edits) the mapping interactively. Subsequent syncs use the saved mapping.

### 16.3 Modular Expansion Principles

The design must accommodate future top-level pages without code changes.

**Principle M1 — Domain-Agnostic Code**
The `notion-sync` and `docs-refinement` skills MUST NOT hardcode the strings `art`, `plan`, or `dev`. All folder resolution goes through `page-map.json`.

**Principle M2 — Additive Mapping**
When a new top-level Notion page is detected on sync:
1. Sync engine prompts: "New top-level page '레벨' detected. Create folder?"
2. User confirms name (default: kebab-slug of title)
3. `page-map.json` appended, new folder created, content synced

**Principle M3 — Path-ID Stability Under Rename**
If a Notion page is renamed, the path-ID (based on folder slug) MUST NOT change. Only the `notion_title` field in `page-map.json` updates. This prevents all cross-references from breaking on rename.

**Principle M4 — `develop_docs/` Category Independence**
`develop_docs/` top-level folders (`game/`, `design/`, `tech/`, `decisions/`, `tasks/`) are **independent of Notion structure**. Multiple Notion pages can feed into one `develop_docs/game/systems/combat.md` file (via `source_notion_docs[]`), and one Notion page can feed multiple `develop_docs` files.

**Principle M5 — No Assumed Hierarchy Depth**
Notion sub-pages can nest arbitrarily deep. The sync engine recursively mirrors, no hardcoded depth limit.

### 16.4 Future Pages (user plans)

User has noted additional pages will be added. Examples (speculative, to be confirmed):
- `레벨` (Levels) — per-level design docs
- `캐릭터` (Characters) — NPC and player specs
- `사운드` (Sound) — SFX/BGM specifications

These will be added to `page-map.json` on first detection; no code change required if Principles M1-M5 are enforced.

### 16.5 Reserved Folder Names

The following `notion_docs/` folder names are reserved and MUST NOT be assigned to Notion pages:
- `_meta/` — sync engine state
- Any name starting with `_` — reserved prefix

## 17. `develop_docs` as a Living Knowledge Base

### 17.1 Dual-Origin (actually Tri-Origin) Content

Unlike `notion_docs/` which is a strict 1:1 Notion mirror, `develop_docs/` is a **living technical knowledge base** that accumulates content from three sources:

| Source | Origin | Update trigger |
|--------|--------|----------------|
| `notion` | Refined from `notion_docs/` during `/docs-refinement` | Notion page change |
| `code` | Derived from Unity C# code, scenes, prefabs | `/unity-orchestration` during build/refactor |
| `manual` | Authored directly by user in editor | User save |

A single file may be `hybrid` — multiple sources within one document.

### 17.2 Section-Level Provenance via HTML Comment Markers

Each content section within a `develop_docs` file carries a provenance marker:

```markdown
<!-- source: notion:plan.combat-system -->
## Combat Mechanics

(Content refined from Notion)
<!-- /source -->

<!-- source: code:Assets/Scripts/Combat/CombatSystem.cs -->
## Implementation

### Classes
- `CombatSystem` (sealed) — main controller
- `DamageFormula` (static) — calculation utilities

### Public API
- `StartCombat(Entity, Entity) : CombatResult`
<!-- /source -->

<!-- source: manual -->
## Design Notes

(User-authored reflections; preserved across all automated updates)
<!-- /source -->
```

Rationale for HTML comments over frontmatter-only tracking: comments are **inline**, survive file splitting/merging, and are visible when the file is read by other tools (including other sub-agents).

### 17.3 Refinement Preservation Rule

When `/docs-refinement` runs:

1. Parse existing `develop_docs` file → identify provenance-marked sections
2. **Only regenerate sections with `source: notion:*`** — all other sections are preserved verbatim
3. New sections from Notion appear with `source: notion:<id>` markers
4. Removed Notion sources → replaced with `<!-- source: notion:<id> DEPRECATED -->` deprecation notice, NOT deleted silently

This rule is the contract that lets users/Claude safely edit `develop_docs` between sync runs.

### 17.4 Code-Derived Updates (during `/unity-orchestration`)

When Claude writes or refactors C# during `/unity-orchestration`:

1. After `superpowers:verification-before-completion` passes (Step 9 in Section 8.1)
2. **Step 10 (new)** scans touched files and updates relevant `develop_docs/tech/unity/**/*.md`:
   - Class signatures, public methods, serialized fields
   - Scene/prefab structural changes (via `unity-mcp` introspection)
   - Assembly references and dependencies
3. Each updated section is wrapped in `<!-- source: code:<path> -->` markers
4. Updates are committed on the **same feature branch** as the code (not the `sync/notion-*` branch)

### 17.5 Frontmatter Extension

Append to `develop_docs/*.md` frontmatter:

```yaml
section_sources:
  "Combat Mechanics": notion:plan.combat-system
  "Implementation": code:Assets/Scripts/Combat/CombatSystem.cs
  "Design Notes": manual

code_references:
  - path: Assets/Scripts/Combat/CombatSystem.cs
    kind: class
    symbol: CombatSystem
  - path: Assets/Scripts/Combat/DamageFormula.cs
    kind: static-utility
    symbol: DamageFormula
```

`section_sources` is a frontmatter-level summary; the HTML comment markers in body text are the authoritative source.

### 17.6 Conflict Resolution

| Case | Resolution |
|------|-----------|
| Notion section heading renamed (H2 changed) | Header updated; provenance marker preserved; content regenerated |
| Code class renamed | `code_references` updated; section regenerated during `/unity-orchestration` |
| User edits a `source: notion:*` section directly | `/docs-refinement` warns and asks: overwrite / preserve / abort |
| User edits a `source: manual` section | No conflict — fully user-owned |
| Section has no provenance marker (legacy/migrated) | Treated as `manual` — preserved by default, warning logged |

### 17.7 Impact on Sync Engine

Section 6.2's 4-step change detection is **unchanged for `/docs-update`** — it still only touches `source: notion:*` sections.

But `/unity-orchestration` now has an additional post-step (Step 10 in Section 8.1): **code-derived update**. This is scoped to `develop_docs/tech/**` by default; other trees remain refinement-only.

### 17.8 Hash Scoping (Idempotency Under Dual-Origin)

To keep `/docs-refinement` idempotent despite dual-origin content, `refinement_hash` in frontmatter is calculated **only over `source: notion:*` sections**. Code-derived and manual sections are excluded. This guarantees:
- Running `/docs-refinement` twice yields same diff on notion-sourced sections
- Code updates during `/unity-orchestration` do not trigger spurious refinement
