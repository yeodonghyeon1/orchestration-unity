---
id: skills.unity-orchestration.workflow
title: Unity Orchestration Workflow (v1.0 — Superpowers chain)
owner: developer
status: stable
updated: 2026-04-18
version: 2
tags: [workflow, reference, v1]
---

# Workflow Reference (v1.0)

## Overview

`/unity-orchestration <task>` runs an eleven-step sequence. Main Claude
drives everything. Sub-agents are spawned only via
`superpowers:subagent-driven-development` for independent parallel work.
There is no voting, no pair review, no consensus team — the Superpowers
discipline skills handle all quality gates.

## Step 1 — Brainstorming

Invoke `superpowers:brainstorming`. Let it run its full HARD-GATE flow —
context exploration, clarifying questions (one at a time), 2-3 alternative
approaches, design sections with user approval, final spec at
`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.

On user approval of the spec, the brainstorming skill will automatically
hand off to step 3 (writing-plans). Steps 1 → 2 → 3 are chained by
brainstorming itself.

## Step 2 — Context loading

Between brainstorming's context exploration and its clarifying questions,
the skill expects relevant project files. For a Unity task, we pre-load:

1. `develop_docs/_meta/index.json` — read tree + reverse_index
2. Match task keywords against `title` fields — load matching `develop_docs/*.md`
3. Match file paths against any `code_references[].path` in loaded docs — skim the C# source

Brainstorming uses this as initial context before asking the user.

## Step 3 — Writing plans

`superpowers:writing-plans` produces
`docs/superpowers/plans/YYYY-MM-DD-<slug>.md` with bite-sized tasks (2-5
min each), TDD steps, and exact file paths. Plan references the develop_docs
files loaded in Step 2.

## Step 4 — User approval gate

writing-plans ends by asking the user to review the written plan. Do NOT
proceed until approval.

## Step 5 — Git worktree (optional)

For tasks spanning >5 files or >2 hours, invoke
`superpowers:using-git-worktrees` to isolate the branch. For small tasks,
work on a feature branch in the main repo.

## Step 6 — Execution

Choose one:

- **`superpowers:subagent-driven-development`** (recommended for >10 tasks)
  — fresh sub-agent per plan task, review between tasks
- **`superpowers:executing-plans`** (simpler, single-session) — execute
  sequentially with checkpoints

## Step 7 — TDD inside execution

Each plan task is executed under `superpowers:test-driven-development`:
1. Write failing test
2. Verify it fails
3. Minimal implementation
4. Verify test passes
5. Refactor (optional)
6. Commit

The "Iron Law" applies: NO production code without a failing test first.

## Step 8 — unity-mcp calls

During implementation, invoke `unity-mcp` for:
- Scene structure changes (`mcp__unity-mcp__scene_*`)
- Prefab creation/editing (`mcp__unity-mcp__prefab_*`)
- Compile / play mode status (`mcp__unity-mcp__project_*`)
- Test runner invocation (`mcp__unity-mcp__test_*`)

C# file edits can be done via Claude Code's Edit/Write tools directly (faster than MCP roundtrip).

## Step 9 — Verification

`superpowers:verification-before-completion` is MANDATORY before claiming
any task complete. Run the actual test commands fresh in this message,
read the output, count failures. No "it should work" language allowed.

## Step 10 — Code-derived develop_docs update (v1.0 NEW)

After verification passes, run:

```bash
bash scripts/code-doc-updater.sh <task-touched-files>
```

This scans modified C# files, runs `scripts/code-to-docs.py` on each,
and uses `scripts/provenance.py` to replace or append the
`code:<path>` sections in the matching `develop_docs/tech/unity/**/*.md`
files. See spec Section 17.4.

Commit the develop_docs changes on the same feature branch as the code (NOT the sync branch).

## Step 11 — Branch finishing

`superpowers:finishing-a-development-branch` presents merge/PR options. The
user decides: merge to main / open PR / keep branch open for more work / discard.

## Error handling

- **Notion MCP absent**: brainstorming and planning still work; step 8 warns and stops.
- **unity-mcp absent**: plan can still be produced, implementation paused at Step 6.
- **User rejects plan at Step 4**: go back to Step 3 or Step 1 depending on feedback scope.
- **Verification fails at Step 9**: go back to Step 6 for the failing task; do NOT proceed.
- **code-doc-updater.sh fails at Step 10**: warning only; do not block Step 11. File an issue.
