---
id: game
title: Game Design Domain
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index, game]
---

# Game Design Domain (planner territory)

This area is owned by planner agents. It describes what the game IS, not
how it is built.

## Subfolders

- `overview.md` — top-level game concept, target audience, core loop.
- `systems/` — one file per game system (combat, inventory, progression…).
- `levels/` — level and stage specs.
- `balancing/` — numeric tables and rationale.
- `narrative/` — story, characters, dialog.

## Authoring rules

- One system = one file. Split when > 800 lines.
- Every system file must declare `depends_on: [game.overview]` at minimum.
- Do NOT reference Unity-specific constructs; use engine-neutral language.
