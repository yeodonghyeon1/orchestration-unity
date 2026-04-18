---
description: Regenerate llm_wiki/tech/** sections from modified C# source files. Does not push to Notion.
argument-hint: [--files <path>...] [--glob <pattern>] [--dry-run]
---

# /wiki-sync-code

Keep `llm_wiki/tech/` in sync with `Assets/**/*.cs`. Triggered manually
or suggested by the post-edit hook.

Invoke the `wiki-sync-code` skill:

```
Skill('wiki-sync-code')
```

## Arguments

- (no args) — `git diff --name-only HEAD` + unstaged + untracked.
- `--files <path>...` — explicit list.
- `--glob <pattern>` — glob relative to project root.
- `--dry-run` — stop before writing.

After this command, a `/notion-push --dry-run` is suggested (never
auto-run).
