---
id: design
title: Visual & UX Design Domain
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index, design]
---

# Visual & UX Design Domain (designer territory)

This area is owned by designer agents. It describes what the game LOOKS
and FEELS like, and what the player sees.

## Subfolders

- `art-direction.md` — tone, color, reference boards.
- `scenes/` — per-scene layout specs.
- `prefabs/` — prefab structures and composition rules.
- `ui/` — UI wireframes and flow diagrams.

## Authoring rules

- Scene specs are engine-neutral where possible: describe intent, not
  Unity hierarchy.
- Prefab specs may mention Unity-specific concepts only when necessary,
  but prefer to link to `tech/` for implementation detail.
- Every scene file must declare `depends_on` on the levels it supports.
