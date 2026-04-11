---
id: tech
title: Technical Domain
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index, tech]
---

# Technical Domain (developer territory)

This area is owned by developer agents. It is the ONLY place where
Unity-specific vocabulary (Prefab, ScriptableObject, AssetBundle, URP,
HDRP, etc.) is permitted in documentation.

## Subfolders

- `architecture.md` — top-level system architecture.
- `modules/` — one file per code module.
- `api/` — public APIs of modules (classes, components, interfaces).
- `testing.md` — test strategy and conventions.

## Authoring rules

- Every module file must declare `depends_on` on the module(s) it imports.
- Public API changes must bump the file `version`.
- Link outward to `game/` or `design/` specs that drove the
  implementation via `depends_on`.
