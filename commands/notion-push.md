---
description: Publish llm_wiki/ changes back to the Notion 메인 DB rows they came from. Always shows a dry-run plan first.
argument-hint: [--all|--files <path>...|--dry-run|--prune-orphans]
---

# /notion-push

Reverse sync — `llm_wiki/` → Notion 메인 DB rows. Use after
`/wiki-sync-code` or manual wiki edits.

Invoke the `notion-push` skill:

```
Skill('notion-push')
```

The skill will:
1. Collect candidate files from git range.
2. Map each `<!-- source: notion:<row-id> -->` block to a Notion row.
3. Detect conflicts (Notion newer than `last_push_commit` state) → abort.
4. Emit a dry-run plan; wait for approval.
5. Push updates; preserve `source: manual` blocks.
6. Record `last_push_commit` in `sync-state.json`.

## Arguments

- (no args) — git range `last_push_commit..HEAD`.
- `--all` — every wiki file with a notion source marker.
- `--files <path>...` — explicit list.
- `--dry-run` — stop after plan.
- `--prune-orphans` — remove orphaned Notion sections.

## Forbidden

- Do NOT push without plan approval.
- Do NOT overwrite `source: manual` blocks.
- Do NOT delete Notion pages or rows.
