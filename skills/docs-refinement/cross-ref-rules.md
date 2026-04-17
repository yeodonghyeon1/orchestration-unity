---
id: skills.docs-refinement.cross-ref-rules
title: Cross-Reference Rules for develop_docs
owner: developer
status: stable
updated: 2026-04-18
version: 1
tags: [docs, refinement, cross-refs]
---

# Cross-Reference Rules

## refs[] relationship types

| rel | Meaning | BFS propagation |
|-----|---------|-----------------|
| `uses` | A consumes B's API or data | B changes → A re-refine |
| `extends` | A specializes B | B changes → A re-refine |
| `contradicts` | A and B conflict | No propagation; warning only |
| `supersedes` | A replaces B (B deprecated) | Reverse only |

## Detection

- `@mention` in Notion → `refs: [{id: <mentioned-page-id>, rel: uses}]` (default rel: uses)
- Explicit "extends X" or "based on X" in body → rel: extends
- Explicit "conflicts with X" → rel: contradicts
- Explicit "replaces X" or "deprecates X" → rel: supersedes

## source_notion_docs semantics

Every refined section must declare its source(s). Format:

```yaml
source_notion_docs:
  - plan.combat-system              # whole page
  - plan.combat-system#damage       # specific section by anchor
```

## Hash scoping (from spec Section 17.8)

`refinement_hash` is computed only over `source: notion:*` sections to keep
refinement idempotent under dual-origin content. Code-derived and
manual sections are excluded.
