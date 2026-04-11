---
id: plugin-docs.architecture
title: Architecture Overview
owner: developer
status: stable
updated: 2026-04-11
version: 1
tags: [architecture]
---

# Architecture Overview

This document is a short introduction; the full design lives in
`docs/superpowers/specs/2026-04-11-unity-orchestration-design.md`.

## Components

- **Skill** (`skills/unity-orchestration/SKILL.md`) — entry point Claude
  Code loads when `/unity-orchestration` is invoked.
- **Reference docs** — `workflow.md`, `voting.md`,
  `consultation-table.md`, `docs-tree-spec.md` in the skill directory.
- **Role prompts** — five files in `skills/unity-orchestration/agents/`,
  injected when spawning agents.
- **Templates** — proposal, vote, ADR, frontmatter, and the seed
  docs-tree used by `init-workspace.sh`.
- **Scripts** — `init-workspace.sh`, `tally-votes.sh`, and
  `update-docs-index.py`.
- **Slash command** — `commands/unity-orchestration.md` wraps the skill.

## Runtime model

- Uses Claude Code **Agent Teams** (`TeamCreate`/`SendMessage`) for nine
  concurrently-living agents.
- Single Unity project workspace (no worktrees — Unity locks files).
- `unity-mcp` is a single shared dependency; the team lead serializes
  access with an explicit lock protocol.

## Documentation output

The recorder agents produce an AI-readable `docs/` tree in the user's
Unity project. Format is documented in `docs-tree-spec.md` and is
engine-independent outside of `docs/tech/`.

## Testing layers

- **L1 — structure check** (`tests/structure-check.sh`)
- **L2 — script unit tests** (`tests/scripts/*.test.sh`)
- **L3 — dry-run scenarios** (`tests/scenarios/README.md`, manual in v1)
