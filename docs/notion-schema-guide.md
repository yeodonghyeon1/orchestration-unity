---
id: plugin-docs.notion-schema-guide
title: Notion Schema Guide
owner: user-content
status: stable
updated: 2026-04-18
version: 1.0.0
tags: [guide, notion, content-authoring]
---

# Notion Schema Guide (v1.0)

This guide describes how to structure the Notion workspace so that `orchestration-unity` v1.0 can sync it cleanly into `notion_docs/` and refine it into `develop_docs/`. Written for the **human content author** (game designer, artist, developer) working inside Notion.

## 1. Workspace Root: Three Starter Pages

Create these three top-level pages inside a single Notion workspace (or teamspace). Titles can be Korean or English — the plugin stores a title→folder mapping.

```
[Your workspace root]
├── 개발 (Dev)        → synced to notion_docs/dev/
├── 아트 (Art)        → synced to notion_docs/art/
└── 기획 (Plan)       → synced to notion_docs/plan/
```

You may add more top-level pages later (e.g., `레벨`, `캐릭터`, `사운드`). When the plugin detects a new top-level page, it will prompt you to confirm the folder slug, then append it to `notion_docs/_meta/page-map.json`.

## 2. What Goes in Each Page

### 2.1 개발 (Dev)

Technical direction, stack choices, API designs, and development-facing decisions.

Good sub-pages:
- "Tech Stack" — Unity version, URP/HDRP, C# language version
- "Architecture Overview" — high-level module layout
- "MCP / Plugin Inventory" — external dependencies
- "API Surface" — public entry points for each system

Avoid:
- Full code listings (that belongs in the repo, not Notion)
- Implementation details that will be generated from C# later (the plugin extracts class/method docs from code into `develop_docs/tech/unity/`)

### 2.2 아트 (Art)

Visual direction, asset specifications, and creative intent.

Good sub-pages:
- "Concept Direction" — mood board, reference images, vibes
- "Sprite Sheet Spec" — dimensions, pivot rules, palette
- "UI Mood Board" — typographic choices, color language
- "Animation Style" — ease curves, frame rates, timing principles

Avoid:
- Hosting source art files (Notion attachments are not mirrored — put files in repo or cloud storage)
- Pixel-exact specifications that change frequently (capture in code or ScriptableObjects instead)

### 2.3 기획 (Plan)

Game systems, mechanics, balancing, acceptance criteria, level design.

Good sub-pages:
- "Combat System" — mechanics, damage formula, state machines
- "Level Progression" — difficulty curves, unlocks
- "Economy" — currencies, costs, balancing
- "Narrative Beats" — story structure if applicable

Avoid:
- One giant "Everything" page (split by system — each becomes a separate file)
- Stream-of-consciousness dumps (structure with H2/H3; the refinement engine uses them)

## 3. Authoring Principles

### 3.1 One Topic Per Page

Each Notion page becomes one `notion_docs/*.md` file. If a page covers multiple unrelated topics, they will be mixed in one file — harder for refinement to split. **Prefer many small pages to few large ones.**

### 3.2 Use H2/H3 Structure

The refinement engine recognizes H2 headings as section boundaries. Write:

```
# Combat System               ← page title (H1, implicit)

## Overview                   ← H2: section 1
...

## Damage Formula             ← H2: section 2
...

### Variables                 ← H3: subsection
...
```

Avoid flat walls of text with no headings — the refinement engine can still handle them, but cross-referencing becomes coarser.

### 3.3 Cross-Reference Other Pages with @Mentions

Notion's `@` mention to link pages becomes a `refs[]` entry in the synced `notion_docs/` frontmatter. Use mentions when one system depends on another:

> The Combat System uses values from @Economy to calculate item durability costs.

The refinement engine picks up the link and creates a `refs: [id: plan.economy, rel: uses]` entry in the corresponding `develop_docs` file.

### 3.4 Mark Decisions Explicitly

Use a callout block (💡 or 🎯) labeled "Decision:" for locked-in choices. The refinement engine promotes these to `develop_docs/decisions/` as ADRs.

```
🎯 Decision: Damage is dealt in integer values only, not floats.
   Rationale: avoids rounding accumulation and keeps UI clean.
   Date: 2026-04-18
```

### 3.5 Flag Open Questions with a Tag

Use `#question` or `❓ Open:` lines for unresolved items. The refinement engine collects them into a per-page open-questions section and an aggregated `develop_docs/_meta/open-questions.md` index.

## 4. What NOT to Do

| ❌ Don't | Why |
|---------|-----|
| Edit files in `notion_docs/` directly | Next sync overwrites them — edit in Notion instead |
| Expect edits in `develop_docs/` to flow back to Notion | Sync is one-way (Notion → docs) |
| Delete a page then re-create with same title | Creates a new `notion_page_id`; cross-refs break. Rename instead. |
| Create circular `@mentions` (A ↔ B ↔ A) | Sync detects and warns but BFS may behave unexpectedly |
| Use deeply nested toggle blocks for main content | Refinement may flatten toggles; important content should live at page level |

## 5. Example Structure

A minimally usable starting structure:

```
🎮 My Game Workspace
│
├── 📂 개발 (Dev)
│   ├── Tech Stack
│   ├── Architecture Overview
│   └── MCP Inventory
│
├── 📂 아트 (Art)
│   ├── Concept Direction
│   ├── Sprite Sheet Spec
│   └── UI Mood Board
│
└── 📂 기획 (Plan)
    ├── Combat System
    │   ├── Damage Formula
    │   └── Enemy AI States
    ├── Economy
    └── Level Progression
        ├── Act I
        └── Act II
```

After the first `/docs-update`, this becomes:

```
project-root/notion_docs/
├── _meta/{sync-state.json, index.json, page-map.json}
├── dev/
│   ├── tech-stack.md
│   ├── architecture-overview.md
│   └── mcp-inventory.md
├── art/
│   ├── concept-direction.md
│   ├── sprite-sheet-spec.md
│   └── ui-mood-board.md
└── plan/
    ├── combat-system.md
    ├── combat-system/
    │   ├── damage-formula.md
    │   └── enemy-ai-states.md
    ├── economy.md
    └── level-progression.md
        ├── act-i.md
        └── act-ii.md
```

## 6. See Also

- Plugin architecture: `architecture-v1.md`
- Full technical spec: `superpowers/specs/2026-04-18-orchestration-unity-v1-design.md`
- Docs tree format: `skills/unity-orchestration/docs-tree-spec.md`
