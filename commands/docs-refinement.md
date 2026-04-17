---
description: Refine notion_docs/ into develop_docs/ via BFS impact graph
argument-hint: (optional) comma-separated notion_docs ids to force-refine
---

# /docs-refinement

Transform `notion_docs/` into `develop_docs/` using the docs-refinement skill.

Invoke via:

```
Skill('docs-refinement')
```

If the user passes arguments (notion_docs ids), treat them as forced seeds
for BFS (useful for partial refresh).

The skill will:
1. Run `scripts/docs-index.py` to refresh the index
2. Determine changed ids (from git diff of `notion_docs/` since last refinement)
3. Run `scripts/bfs-impact.py` to find affected develop_docs
4. Dispatch sub-agents to refine each affected file
5. Re-run `docs-index.py` to update the index

Does NOT commit or push — that's `/docs-update`'s job.
