---
description: Seed the llm-wiki three-tier workspace (raw/, llm_wiki/, _meta) in the current project. Idempotent.
argument-hint: (no arguments)
---

# /init-wiki

Seed the llm-wiki workspace. Creates `raw/`, `llm_wiki/`, their `_meta/`
subdirectories, and empty skeleton JSONs. Safe to re-run — existing
files are preserved.

Invoke the `init-wiki` skill:

```
Skill('init-wiki')
```

Run once per project. Follow with `/notion-bootstrap <main-page-url>`
to create the Notion side.
