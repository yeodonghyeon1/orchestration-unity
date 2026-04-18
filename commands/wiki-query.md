---
description: Answer a question from llm_wiki with citations. Optionally file the answer into docs/llm_wiki/explorations/.
argument-hint: <question> [--file|--no-file] [--max-pages N]
---

# /wiki-query

Question answering grounded strictly in `docs/llm_wiki/`. Not a general
knowledge answerer — if the wiki is silent, the skill says so.

Invoke the `wiki-query` skill:

```
Skill('wiki-query')
```

## Arguments

- `<question>` — free-text question.
- `--file` — auto-file the answer without asking.
- `--no-file` — suppress the filing prompt.
- `--max-pages N` — cap on pages read (default 15).
