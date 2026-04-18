# orchestration-unity

> **Turn Notion game design into working Unity code, with Superpowers discipline.**
> Human designers write in Notion; Claude Code mirrors, refines, and
> implements via `unity-mcp` — using TDD and verification at every step.

[![version](https://img.shields.io/badge/version-1.0.0-blue)]() [![license](https://img.shields.io/badge/license-MIT-green)]() [![BREAKING](https://img.shields.io/badge/v0.2%E2%86%92v1.0-BREAKING-red)]()

---

## What this is

A Claude Code plugin that orchestrates the full loop from creative idea
to shipped Unity feature:

1. You write game design in **Notion** (three pages: 개발/아트/기획).
2. `/docs-update` pulls it into the repo as two parallel doc trees
   (raw mirror + Claude-refined knowledge base).
3. `/unity-orchestration "<task>"` turns a design request into a
   tested, verified Unity implementation via the Superpowers workflow chain.

You stay in charge of design decisions. Claude handles plumbing,
refinement, and disciplined implementation.

### What makes this different

- **Notion as source of truth** — edit design in Notion; code and docs
  stay in sync automatically.
- **Two-tier docs** — a raw Notion mirror (`notion_docs/`) and a refined,
  cross-referenced knowledge base (`develop_docs/`) that evolves with
  both Notion edits AND code changes.
- **Superpowers discipline** — every code change goes through
  brainstorming, plan approval, TDD, and verification. No vibe-coding.
- **Incremental sync** — only changed Notion pages are re-fetched;
  only affected `develop_docs` are re-refined (timestamp + SHA256 hash
  + BFS impact graph).
- **Living knowledge base** — `develop_docs/tech/unity/` auto-updates
  with class signatures after each feature implementation.

---

## Quickstart

### Prerequisites

| Requirement | Install |
|-------------|---------|
| Claude Code | <https://claude.ai/code> |
| Superpowers plugin | `/plugin marketplace add obra/superpowers-marketplace && /plugin install superpowers@superpowers-marketplace` |
| Notion MCP | Connect via Claude Code settings (claude_ai Notion connector) |
| unity-mcp | <https://github.com/CoplayDev/unity-mcp> — clone and register in `~/.claude/settings.json` |
| A Unity project | with `Assets/` and `ProjectSettings/` at root |
| Python 3.9+ and bash | for scripts |

### Install

```bash
/plugin marketplace add yeodonghyeon1/orchestration-unity
/plugin install unity-orchestration@orchestration-unity
```

Restart Claude Code if prompted, then `cd` into your Unity project.

### First-time setup (3 minutes)

1. **Create three Notion pages** at the top level of your workspace:
   - `개발` (Dev) — tech stack, architecture, APIs
   - `아트` (Art) — concept direction, sprite specs, UI mood
   - `기획` (Plan) — systems, mechanics, balancing, levels

   See [`docs/notion-schema-guide.md`](docs/notion-schema-guide.md) for
   authoring conventions.

2. **Seed the workspace**:
   ```bash
   bash scripts/init-workspace.sh .
   ```
   Creates `notion_docs/_meta/` and `develop_docs/_meta/` with empty
   state files.

3. **First sync**:
   ```
   /notion-sync
   ```
   Prompts you once per new top-level page to confirm the folder slug
   (default: kebab-case of the Notion title, overridable). Saves the
   mapping to `notion_docs/_meta/page-map.json`.

You're now set up. Daily usage: `/docs-update` after Notion edits,
`/unity-orchestration "<task>"` when building features.

---

## Key concepts

| Term | Meaning |
|------|---------|
| **Superpowers** | A Claude Code plugin (dependency) providing workflow skills: brainstorming, writing-plans, executing-plans, TDD, verification-before-completion, finishing-a-development-branch. |
| **MCP** | Model Context Protocol — lets Claude call external tools. This plugin uses Notion MCP (read) and unity-mcp (Unity editor control). |
| **`notion_docs/`** | Raw 1:1 mirror of Notion pages as markdown. Auto-generated. **Never edit by hand** — next sync overwrites. |
| **`develop_docs/`** | Claude's refined, cross-referenced knowledge base. Built from `notion_docs/` via the refinement skill. Can be hand-edited in `manual`-tagged sections. |
| **HARD-GATE** | A Superpowers rule: no code without an approved plan. Enforced by the `brainstorming` skill. |
| **TDD Iron Law** | Superpowers rule: no production code without a failing test first. |
| **Section provenance** | HTML comment markers (`<!-- source: notion:... -->`, `<!-- source: code:... -->`, `<!-- source: manual -->`) that tag each section in `develop_docs` by origin. Refinement only regenerates `notion:*` sections. |
| **Eleven-step chain** | The sequence `/unity-orchestration` runs: brainstorming → context load → plan → approval → (worktree) → execute → TDD → unity-mcp → verify → code-doc-updater → finish-branch. |

---

## Command reference

| Command | Scope | Calls Superpowers? |
|---------|-------|--------------------|
| `/notion-sync` | Notion → `notion_docs/` only (incremental) | No — pure sync |
| `/docs-refinement` | `notion_docs/` → `develop_docs/` only | No — structural transform |
| `/docs-update` | Full pipeline: sync + refine + git branch + auto-push | No |
| `/unity-orchestration "<task>"` | Feature development (brainstorm → plan → TDD → verify → update docs → finish branch) | Yes — full chain |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ HUMAN ZONE                                                           │
│   Notion workspace (개발 / 아트 / 기획 + future pages)                │
│   — authored by game designer / artist / dev team                   │
└────────────────────────┬────────────────────────────────────────────┘
                         │  /notion-sync  (timestamp + SHA256 hash)
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│ CLAUDE-OWNED MIRROR                                                  │
│   notion_docs/                                                      │
│   ├── _meta/ (sync-state.json, page-map.json, index.json)          │
│   ├── dev/   ← from Notion "개발"                                    │
│   ├── art/   ← from Notion "아트"                                    │
│   └── plan/  ← from Notion "기획"                                    │
│   Frontmatter: notion_page_id, content_hash, synced_at              │
└────────────────────────┬────────────────────────────────────────────┘
                         │  /docs-refinement  (BFS impact graph)
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│ LIVING KNOWLEDGE BASE  (Claude + user collaborate)                   │
│   develop_docs/                                                     │
│   ├── game/        — engine-agnostic logic                          │
│   ├── design/      — UX, art direction                              │
│   ├── tech/unity/  — C# class signatures (auto-updated)             │
│   ├── decisions/   — ADRs                                           │
│   └── tasks/       — Superpowers plan summaries                     │
│   Section provenance: notion:* | code:* | manual                    │
└────────────────────────┬────────────────────────────────────────────┘
                         │  /docs-update auto-push to sync branch
                         │  /unity-orchestration "<task>"  (11 steps)
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│ UNITY PROJECT                                                        │
│   Assets/ Scripts/ Scenes/ Prefabs/                                 │
│   — implemented via unity-mcp + TDD                                 │
│   — develop_docs/tech/unity/ auto-updated after verification        │
└─────────────────────────────────────────────────────────────────────┘
```

Full technical spec: [`docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md`](docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md).

---

## Workflows

### Syncing design changes (weekly or as needed)

```
/docs-update
```

Runs sync + refinement, creates a branch `sync/notion-YYYYMMDD-HHMM`,
commits both trees separately, pushes to origin. You review via PR
and merge to main. `main` is never written directly.

**What you see:**
```
synced: 3 pages (0 new, 1 updated, 2 unchanged, 0 orphaned)
affected develop_docs: game.systems.combat
sync branch: sync/notion-20260418-0900
commits: 2 (notion_docs, develop_docs)
pushed: yes
next: open PR and merge
```

### Building a feature

```
/unity-orchestration "add an enemy patrol system"
```

Starts the 11-step Superpowers chain. Expect:
1. **Brainstorming** — Claude clarifies scope, proposes 2-3 approaches.
2. **Plan review gate** — you approve the written plan file before any
   code runs.
3. **TDD execution** — every task has a failing test written first.
4. **unity-mcp calls** — scene/prefab edits happen through the Unity
   editor.
5. **Verification** — fresh test runs before completion claims.
6. **Docs auto-update** — new class signatures appear in
   `develop_docs/tech/unity/`.
7. **Branch finishing** — merge/PR options presented.

Interrupt at plan approval, verification, or branch finishing as needed.

---

## Documentation

| File | What it covers |
|------|----------------|
| [`docs/architecture.md`](docs/architecture.md) | Architecture overview |
| [`docs/notion-schema-guide.md`](docs/notion-schema-guide.md) | How to author Notion pages so refinement works well |
| [`docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md`](docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md) | Full technical design spec |
| [`docs/superpowers/plans/`](docs/superpowers/plans/) | Per-slice implementation plans used to build v1.0 |
| [`docs/archive/v0.2/`](docs/archive/v0.2/) | Historical v0.2.0 docs (10-agent consensus era) |
| [`CHANGELOG.md`](CHANGELOG.md) | Versioned change history |

---

## Migrating from v0.2.0

v1.0 is a **breaking change** from v0.2.0. The 10-agent consensus team,
voting protocol, playtest phase, and pair review are all removed.

### One-command migration

From your existing v0.2.0 Unity project root:

```bash
bash scripts/migrate-v02-to-v1.sh
```

This:
- Moves your existing `docs/` tree into `develop_docs/`.
- Scaffolds `notion_docs/_meta/` with empty state.
- Preserves `.orchestration/sessions/` for historical reference.

Flags:
- `--yes` — skip interactive confirmations (for CI).
- `--dry-run` — print what would be done, make no changes.

### After migration

1. Review `develop_docs/` — the old v0.2 docs-tree is now there.
2. Set up Notion (see Quickstart above).
3. Run `/notion-sync` to confirm page mappings.

Your v0.2 session artifacts under `.orchestration/sessions/` are untouched
— safe to delete when you're confident you don't need them.

---

## Troubleshooting

### `/notion-sync` says "Notion MCP not available"
The `claude_ai_Notion` MCP connector isn't configured. Check Claude Code
settings — connect the Notion workspace.

### `/unity-orchestration` pauses at brainstorming
This is the HARD-GATE from Superpowers. You must answer the clarifying
questions and approve the design before it writes code. It's intentional.

### Tests pass locally but I see mode `100644` on scripts in git
On Windows git-bash, `chmod +x` doesn't always set the git executable
bit. Fix:
```bash
git update-index --chmod=+x scripts/<script>.sh
```

### `develop_docs` file was rewritten — I lost my manual edits
Check that your edits were inside `<!-- source: manual -->` markers.
Sections without markers OR with `<!-- source: notion:* -->` markers
are regenerated by refinement.

### A Notion page rename broke my cross-references
Notion page IDs are stable across renames. If refs broke, the page
was deleted and re-created (new ID). Fix: update `source_notion_docs:`
in the affected `develop_docs` files to the new ID.

---

## Contributing

Bug reports, PRs, and discussion welcome:
<https://github.com/yeodonghyeon1/orchestration-unity/issues>

Before submitting a PR:
1. Run the full test suite:
   ```bash
   bash tests/structure-check.sh
   for t in tests/sync-engine-tests/*.sh tests/integration/*.sh; do bash "$t"; done
   ```
2. Add unit tests for new scripts (follow the existing TDD style).
3. Update `CHANGELOG.md` under `[Unreleased]`.
4. Commit messages follow conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.

---

## License

MIT — see [`LICENSE`](LICENSE).

---

**Status:** v1.0.0 (2026-04-18) — first Notion-driven Superpowers release. See [`CHANGELOG.md`](CHANGELOG.md) for the full change list.
