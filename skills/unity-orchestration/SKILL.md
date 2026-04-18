---
name: unity-orchestration
description: Use when user invokes /unity-orchestration <task> or asks to develop a Unity game feature. Orchestrates the full Superpowers chain (brainstorming → writing-plans → executing-plans → TDD → verification → finishing-branch) using llm_wiki/ as the authoritative context source, and unity-mcp as the implementation layer. Triggers /wiki-sync-code after verification.
---

# unity-orchestration

Drive a Unity game-development task through the Superpowers discipline
chain. Reads context from `llm_wiki/` (LLM-maintained wiki), produces a
plan under `docs/superpowers/plans/`, executes via TDD + unity-mcp,
updates `llm_wiki/tech/**` via `/wiki-sync-code`, and hands off via
`superpowers:finishing-a-development-branch`.

**Announce at start:** "I'm using the unity-orchestration skill to drive this task through Superpowers."

## Pre-flight

1. `llm_wiki/index.md` and `llm_wiki/log.md` exist (run `/init-wiki`
   and at least one `/wiki-ingest` first). Warn if empty.
2. `unity-mcp` MCP tools available (`mcp__unity-mcp__*` or equivalent).
   If absent, warn — brainstorming and planning can still proceed but
   execution cannot touch the Unity editor.
3. Current directory is a Unity project (contains `Assets/` +
   `ProjectSettings/`) OR the user explicitly runs a dry-run non-Unity
   task.
4. `git status` is clean OR the user has opted in to continue anyway.

## Eleven-step internal flow

See `workflow.md` for details. Summary:

```
1.  superpowers:brainstorming         — clarify requirements with user
2.  Load relevant llm_wiki context    — index.md + recent log.md + linked pages
3.  superpowers:writing-plans         — produce docs/superpowers/plans/YYYY-MM-DD-<slug>.md
4.  [User approval gate]              — plan must be approved before implementation
5.  superpowers:using-git-worktrees   — optional (recommended for big tasks)
6.  superpowers:executing-plans OR superpowers:subagent-driven-development
7.   └─ superpowers:test-driven-development  (per task)
8.   └─ unity-mcp calls                      (scene / prefab / C# edits)
9.  superpowers:verification-before-completion
10. /wiki-sync-code                   — update llm_wiki/tech/** from modified C# files
11. superpowers:finishing-a-development-branch
```

## Loading context (Step 2 detail)

Given `<task>` argument:

1. Read `llm_wiki/index.md` in full. Extract `(category, id, title,
   summary)` per page.
2. Read the last 20 lines of `llm_wiki/log.md` to see recent activity.
3. Tokenize the task description, extract keywords. Match against the
   index titles/summaries → `candidate_pages`.
4. Read each candidate page. Follow cross-links (up to 2 hops, bounded
   at 15 total pages).
5. If no matches, prompt user: "No related wiki pages found. Proceed
   with brainstorming from scratch?"

Pass the collected wiki content into the brainstorming skill as
initial context — before it starts asking clarifying questions.

## Step 10 detail — /wiki-sync-code

After verification passes, invoke the `wiki-sync-code` skill:

```
Skill('wiki-sync-code')
```

It will:
- Find modified `Assets/**/*.cs` files.
- Regenerate the `<!-- source: code:<path> -->` blocks in
  `llm_wiki/tech/**`.
- Append a `code-sync` entry to `llm_wiki/log.md`.
- Suggest `/notion-push --dry-run` (main Claude decides whether to run
  it — default: suggest, don't auto-run).

Commit `llm_wiki/` changes on the same feature branch as the code.

## Art separation (strict)

llm_wiki is a **concept / reference catalog**, not a runtime asset store.

- When a task needs art, **read llm_wiki for intent and style direction**
  (concept sketches, color palettes, mood, animation timing references).
- **Production art assets must live under `Assets/` in the Unity project**
  (sprites, animations, prefabs, VFX). These are tracked by git LFS.
- Do NOT treat images under `llm_wiki/assets/**` as production — they are
  downloaded Notion concept images, referenced for discussion only.
- Do NOT auto-upload `Assets/` binaries to Notion. Notion is the concept
  space; git is the production SSOT for art.
- If production art is missing for a task, **request it from the artist**
  (create a Notion 💡 자료&아이디어 row or request Assets commit). Do NOT
  improvise binary assets.

## Forbidden

- Do NOT skip brainstorming, even for small tasks (HARD-GATE).
- Do NOT execute code without a passing failing test first (TDD Iron
  Law).
- Do NOT mark task complete without `verification-before-completion`.
- Do NOT touch `raw/` directly — that's sync-owned.
- Do NOT touch `llm_wiki/*.md` directly except via `/wiki-sync-code`
  (for tech pages) — wiki mutations belong to `/wiki-ingest`.
- Do NOT bypass the user approval gate at Step 4.
- Do NOT run `/wiki-sync-code` before verification passes.
- Do NOT reference `llm_wiki/assets/**` images from Unity code or
  manifests. Production art paths are under `Assets/Art/**`.

## Output on completion

```
task: <task>
plan: docs/superpowers/plans/YYYY-MM-DD-<slug>.md
files changed: N code, M test
wiki updated: [list]  (via /wiki-sync-code)
verification: passed
next: /notion-push --dry-run if these tech changes should reach Notion, then superpowers:finishing-a-development-branch.
```
