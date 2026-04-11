---
id: root
title: Project Documentation
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index]
---

# Project Documentation

This tree is generated and maintained by the `unity-orchestration` plugin's
recorder agents. It is AI-readable first, human-readable second. The format
is documented in
`skills/unity-orchestration/docs-tree-spec.md` (plugin side).

## Top-level areas

- [`_meta/`](_meta/) — glossary, conventions, and the machine-readable
  `index.json`.
- [`game/`](game/README.md) — planner domain: systems, balancing, levels,
  narrative.
- [`design/`](design/README.md) — designer domain: scenes, prefabs, UI, art
  direction.
- [`tech/`](tech/README.md) — developer domain: architecture, modules, API,
  testing. Engine-specific vocabulary lives here.
- [`decisions/`](decisions/) — ADRs. Immutable once `status=stable`.
- [`tasks/`](tasks/) — archived task bundles with consultation transcripts
  and vote records.

## Reading order for AI agents

1. `_meta/index.json` for structure overview.
2. Each folder's `README.md` before diving into its files.
3. `decisions/` for context on past forks in the road.
4. `tasks/<most-recent-id>/README.md` for the latest completed work.
