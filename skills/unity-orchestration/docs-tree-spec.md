---
id: skills.unity-orchestration.docs-tree-spec
title: Recorder Docs Tree Specification
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [docs, reference]
---

# Docs Tree Specification

This is the format recorder-A produces and recorder-B audits. It is
engine-independent; Unity-specific vocabulary is confined to `docs/tech/`.

## Tree layout

```
docs/
├── README.md                        # root index
├── _meta/
│   ├── glossary.md
│   ├── conventions.md
│   └── index.json                   # machine-readable index
├── game/                            # planner domain
│   ├── README.md
│   ├── overview.md
│   ├── systems/                     # one file per system
│   ├── levels/
│   ├── balancing/
│   └── narrative/
├── design/                          # designer domain
│   ├── README.md
│   ├── art-direction.md
│   ├── scenes/
│   ├── prefabs/
│   └── ui/
├── tech/                            # developer domain (Unity-specific ok here)
│   ├── README.md
│   ├── architecture.md
│   ├── modules/
│   ├── api/
│   └── testing.md
├── decisions/                       # ADRs
│   └── YYYY-MM-DD-<slug>.md
├── tasks/                           # archived task bundles
│   └── YYYY-MM-DD-<task-id>/
└── CHANGELOG.md
```

## Required frontmatter

Every `.md` file under `docs/` carries this frontmatter:

```yaml
---
id: game.systems.enemy-patrol        # required; see path-ID rules
title: 적 순찰 시스템                 # required
owner: planner                       # required; planner|designer|developer|recorder
status: draft | review | stable | archived
updated: 2026-04-11                  # required; YYYY-MM-DD
version: 1                           # required; bump on major rewrites
depends_on: [game.overview]          # optional
referenced_by: []                    # auto-populated by index script
tags: [combat, enemy, ai]            # optional
task_origin: 2026-04-11-enemy-patrol # optional
---
```

`structure-check.sh` fails on any missing required field.

## Path-ID system

The path-ID is 1:1 with the file path:

```
docs/game/systems/enemy-patrol.md  ->  game.systems.enemy-patrol
docs/tech/modules/input.md         ->  tech.modules.input
docs/decisions/2026-04-11-ecs.md   ->  decisions.2026-04-11-ecs
```

Rules: drop `docs/`, replace `/` with `.`, drop `.md`, keep hyphens. IDs are the
canonical reference form — `depends_on` uses IDs, not paths.

## _meta/index.json schema

```json
{
  "version": 1,
  "generated_at": "2026-04-11T10:23:00Z",
  "generator": "scripts/update-docs-index.sh",
  "project": { "name": "My Unity Game", "engine": "unity-6000.0.20f1" },
  "tree": {
    "game": {
      "systems": {
        "enemy-patrol": {
          "id": "game.systems.enemy-patrol",
          "title": "적 순찰 시스템",
          "owner": "planner",
          "status": "stable",
          "updated": "2026-04-11",
          "tags": ["combat", "enemy", "ai"],
          "depends_on": ["game.overview"],
          "referenced_by": ["tech.modules.enemy-ai"]
        }
      }
    }
  },
  "by_tag": { "combat": ["game.systems.enemy-patrol"] },
  "by_owner": { "planner": ["game.overview", "game.systems.enemy-patrol"] },
  "dangling_references": [],
  "orphans": []
}
```

`scripts/update-docs-index.sh` regenerates this file by parsing all `.md`
frontmatter. It is recorder-A's responsibility to run it after edits; CI runs
it to detect drift.

## Folder README convention

Every subfolder has a `README.md` that functions as an AI-first landing page:
- Frontmatter with `owner: recorder` and `status`.
- A one-line description per file in the folder.
- Local authoring rules specific to the folder (e.g., "one system per file, >
  800 lines must split").
SKILL.md instructs agents to read folder READMEs before diving into individual
files.

## ADR format

`docs/decisions/YYYY-MM-DD-<slug>.md` with `id: decisions.YYYY-MM-DD-<slug>`
and sections: Context, Decision, Consequences, Alternatives Considered, Votes.
Once `status=stable`, ADR content is frozen; reversing requires a new ADR that
declares `Supersedes decisions.YYYY-MM-DD-<slug>`.

## Task archive format

`docs/tasks/<id>/` contains `README.md` (with frontmatter `id:
tasks.<id>`), `consultation.md`, `votes.md`, `outcome.md`, and optional
`artifacts/`. Only `README.md` carries frontmatter; the other files are
considered internal to the bundle.

## Engine independence

`game/`, `design/`, `decisions/`, `tasks/`, `_meta/` are engine-neutral. Unity
vocabulary (Prefab, ScriptableObject, AssetBundle, etc.) is permitted only in
`tech/`. Success criterion: the same tree, minus `tech/` module names, should
drop into a Godot/Unreal project unchanged.

## Quick reference

- Every `.md` needs frontmatter with `id`, `title`, `owner`, `status`, `updated`, `version`.
- Path-ID rule: strip `docs/`, replace `/` with `.`, drop `.md`.
- Folder READMEs are AI landing pages — read them before individual files.
- Engine-specific vocabulary (Prefab, ScriptableObject, etc.) is confined to `docs/tech/`.
