---
description: Audit docs/llm_wiki/ for orphans, stale drafts, contradictions, broken links, and provenance drift. Report-only by default.
argument-hint: [--check <id>] [--fix]
---

# /wiki-lint

Periodic wiki health check. Emits a prioritized report (HIGH/MED/LOW).
Does not modify files unless the user passes `--fix` (safe auto-fixes
only).

Invoke the `wiki-lint` skill:

```
Skill('wiki-lint')
```

## Arguments

- (no args) — full report.
- `--check <id>` — single check (orphans, drafts, links, contradictions, provenance, unclaimed, empty-categories).
- `--fix` — apply safe auto-fixes only.
