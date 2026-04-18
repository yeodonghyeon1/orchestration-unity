---
id: skills.unity-orchestration.workflow
title: Unity Orchestration Workflow (v2.0 — llm-wiki chain)
owner: developer
status: stable
updated: 2026-04-19
version: 3
tags: [workflow, reference, v2, llm-wiki]
---

# Workflow Reference (v2.0 — llm-wiki pattern)

## Overview

`/unity-orchestration <task>` runs an eleven-step sequence. Main Claude
drives everything. Sub-agents are spawned only via
`superpowers:subagent-driven-development` for independent parallel work.
There is no voting or consensus — Superpowers discipline skills handle
quality gates.

Key v2 change: **context comes from `docs/llm_wiki/`, not `develop_docs/`**.
The wiki is LLM-maintained; sources of truth live in Notion's 메인 DB
rows and `/wiki-ingest` keeps the wiki current.

## Step 1 — Brainstorming

Invoke `superpowers:brainstorming`. Let it run its full HARD-GATE flow —
context exploration, clarifying questions (one at a time), 2-3
alternative approaches, design sections with user approval, final spec
at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.

On spec approval, brainstorming hands off to step 3 (writing-plans).

## Step 2 — Context loading

Before brainstorming asks clarifying questions, pre-load the wiki:

1. Read `docs/llm_wiki/index.md` in full.
2. Read last 20 lines of `docs/llm_wiki/log.md` (recent activity).
3. Extract task keywords; match against index titles/summaries.
4. Read matched pages and follow their cross-links up to 2 hops (cap
   15 pages).
5. Pass this as initial context to brainstorming.

The wiki, not the raw Notion mirror, is the context source. The raw
layer is only touched indirectly via `/wiki-ingest`.

## Step 3 — Writing plans

`superpowers:writing-plans` produces
`docs/superpowers/plans/YYYY-MM-DD-<slug>.md` with bite-sized tasks
(2-5 min each), TDD steps, and exact file paths. Plan references the
wiki pages loaded in Step 2.

## Step 4 — User approval gate

writing-plans ends by asking the user to review. Do NOT proceed until
approval.

## Step 5 — Git worktree (optional)

For tasks spanning >5 files or >2 hours, invoke
`superpowers:using-git-worktrees` to isolate the branch. For small
tasks, work on a feature branch in the main repo.

## Step 6 — Execution

Choose one:

- **`superpowers:subagent-driven-development`** (recommended for >10
  tasks) — fresh sub-agent per plan task, review between tasks.
- **`superpowers:executing-plans`** (simpler, single-session) — execute
  sequentially with checkpoints.

## Step 7 — TDD inside execution

Each plan task is executed under `superpowers:test-driven-development`:
1. Write failing test.
2. Verify it fails.
3. Minimal implementation.
4. Verify test passes.
5. Refactor (optional).
6. Commit.

**Iron Law**: no production code without a failing test first.

## Step 8 — unity-mcp calls

During implementation, invoke `unity-mcp` for:
- Scene structure changes (`mcp__unity-mcp__scene_*`).
- Prefab creation/editing (`mcp__unity-mcp__prefab_*`).
- Compile / play mode status (`mcp__unity-mcp__project_*`).
- Test runner invocation (`mcp__unity-mcp__test_*`).

C# file edits can be done via Claude Code's Edit/Write tools directly
(faster than MCP roundtrip).

## Step 9 — Verification

`superpowers:verification-before-completion` is **mandatory** before
claiming any task complete. Run actual test commands fresh in the
message, read the output, count failures. No "it should work" language
allowed.

## Step 10 — Wiki code-sync (v2 change)

After verification passes, invoke:

```
Skill('wiki-sync-code')
```

This:
- Finds modified `Assets/**/*.cs` files (git diff).
- Extracts public signatures + XML docs.
- Regenerates `<!-- source: code:<path> -->` sections in
  `docs/llm_wiki/tech/**`.
- Creates `docs/llm_wiki/tech/auto/<slug>.md` for orphaned files.
- Appends `code-sync` entry to `docs/llm_wiki/log.md`.

Commit the wiki changes on the same feature branch as the code.
Optionally run `/notion-push --dry-run` to preview pushing the wiki
updates to the Notion 메인 DB rows.

## Step 11 — Branch finishing

`superpowers:finishing-a-development-branch` presents merge/PR options.
The user decides: merge to main / open PR / keep branch open for more
work / discard.

## Error handling

- **Notion MCP absent**: brainstorming/planning still work; `/wiki-ingest`
  and `/notion-push` unavailable. Warn at Step 2 if wiki is empty.
- **unity-mcp absent**: plan can still be produced; implementation
  paused at Step 6.
- **User rejects plan at Step 4**: return to Step 3 or Step 1 depending
  on feedback scope.
- **Verification fails at Step 9**: return to Step 6 for the failing
  task; do NOT proceed.
- **wiki-sync-code fails at Step 10**: warning only; do not block
  Step 11. File an issue.
