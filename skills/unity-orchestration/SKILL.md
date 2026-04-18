---
name: unity-orchestration
description: Use when user invokes /unity-orchestration <task> or asks to develop a Unity game feature. Orchestrates the full Superpowers chain (brainstorming → writing-plans → executing-plans → TDD → verification → finishing-branch) with develop_docs as context and unity-mcp as the implementation layer.
---

# unity-orchestration

Drive a Unity game-development task through the Superpowers discipline chain.
Reads context from `develop_docs/`, produces a plan under
`docs/superpowers/plans/`, executes via TDD + unity-mcp, updates
`develop_docs/tech/unity/**` with code-derived content, and hands off via
`superpowers:finishing-a-development-branch`.

**Announce at start:** "I'm using the unity-orchestration skill to drive this task through Superpowers."

## Pre-flight

1. `develop_docs/_meta/index.json` exists (i.e., Slice B ran).
2. `unity-mcp` MCP tools available (`mcp__unity-mcp__*` or equivalent). If
   absent, warn user — brainstorming and planning can still proceed but
   execution cannot touch the Unity editor.
3. Current directory is a Unity project (contains `Assets/` + `ProjectSettings/`)
   OR user explicitly runs a dry-run non-Unity task.
4. `git status` is clean OR the user has opted in to continue anyway.

## Eleven-step internal flow

See `workflow.md` for details. Summary:

```
1. superpowers:brainstorming         — clarify requirements with user
2. Load relevant develop_docs        — grep by refs[] / title
3. superpowers:writing-plans         — produce docs/superpowers/plans/YYYY-MM-DD-<slug>.md
4. [User approval gate]              — plan must be approved before implementation
5. superpowers:using-git-worktrees   — optional (recommended for big tasks)
6. superpowers:executing-plans OR superpowers:subagent-driven-development
7.   └─ superpowers:test-driven-development  (per task)
8.   └─ unity-mcp calls                      (scene / prefab / C# edits)
9. superpowers:verification-before-completion
10. scripts/code-doc-updater.sh      — update develop_docs/tech/unity/** with new class/method signatures (Slice C provenance)
11. superpowers:finishing-a-development-branch
```

## Loading context (Step 2 detail)

Given `<task>` argument:
1. Tokenize task description, extract keywords (combat, enemy, UI, etc.)
2. Query `develop_docs/_meta/index.json` for relevant path-IDs
3. Load only the matched files into the brainstorming sub-agent (not the whole tree)
4. If no matches, prompt user: "No related develop_docs found. Proceed with brainstorming from scratch?"

## Forbidden actions

- Do NOT skip the brainstorming step, even for small tasks — Golden Principle #9 (HARD-GATE)
- Do NOT execute code without a passing failing-test first (Superpowers TDD Iron Law)
- Do NOT mark task complete without `verification-before-completion` confirmation
- Do NOT touch `notion_docs/` — it's sync-owned
- Do NOT bypass the user approval gate at Step 4
- Do NOT run `code-doc-updater.sh` before `verification-before-completion` passes

## Output on completion

Summary to user:
```
task: <task>
plan: docs/superpowers/plans/YYYY-MM-DD-<slug>.md
files changed: N code, M test
develop_docs updated: [list]
verification: passed
next: superpowers:finishing-a-development-branch will propose merge/PR options
```
