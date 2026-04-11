---
id: _meta.conventions
title: Documentation Conventions
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [conventions]
---

# Documentation Conventions

Rules every doc in this tree must follow.

## Frontmatter

Every `.md` file MUST have YAML frontmatter with: `id`, `title`, `owner`,
`status`, `updated`, `version`. Optional: `depends_on`, `referenced_by`,
`tags`, `task_origin`.

## Path-ID mapping

- Strip `docs/` prefix.
- Replace `/` with `.`.
- Drop the `.md` extension.

Example: `docs/game/systems/combat.md` → id `game.systems.combat`.

## File size

- Target: 200–400 lines per file.
- Hard limit: 800 lines. If a file exceeds this, split it into a folder
  of smaller files plus an index `README.md`.

## Links

- Between docs in this tree: use relative paths.
- To external URLs: use Markdown links with descriptive text.

## Status values

- `draft` — being written.
- `review` — waiting for peer/recorder-B approval.
- `stable` — approved, safe to reference.
- `archived` — obsolete but preserved for history. Do not delete.

## Engine independence

`game/`, `design/`, `decisions/`, `tasks/`, `_meta/` must remain
engine-agnostic. Unity-specific vocabulary is confined to `tech/`.
