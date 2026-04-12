---
id: skills.unity-orchestration.consultation-table
title: Consultation Table (TaskList conventions)
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [tasklist, reference]
---

# Consultation Table

The "consultation table" is the team's shared TaskList (Agent Teams built-in)
plus append-only transcript and vote files. This file documents the
conventions every agent must follow when reading or writing the table.

## TaskList conventions

- Use `TaskCreate` to add candidate sub-tasks during Phase 2 (Distribution).
- Set `owner` to the agent name that will execute the task
  (`planner-a`, `designer-b`, etc.).
- Use `blockedBy` to express dependencies; agents prefer tasks in ID order
  when multiple are unblocked.
- Set `status` transitions strictly:
  `pending` → `in_progress` → `completed`. Never skip states.
- Only one task per agent may be `in_progress` at a time; the TaskList
  constraint enforces serialization of file writes.

## Transcript file

- Path: `.orchestration/sessions/<id>/transcript.md`.
- Append-only. Recorder-A is the sole writer; other agents send content via
  DM to recorder-A or via the team lead.
- Each entry:

  ```markdown
  ## YYYY-MM-DDTHH:MM:SSZ — <agent-name> → <recipient>
  <message body or summary>
  ```

## Proposals directory

- Path: `.orchestration/sessions/<id>/proposals/<role>-<a|b>.md`.
- Each agent writes exactly one proposal during Phase 1.
- See `templates/task-table.template.md` for the required structure.

## Vote files

- Path: `docs/tasks/<id>/votes/plan-round-N.md` and `accept.md`.
- Produced by `scripts/tally-votes.sh` from a directory of per-agent JSON
  vote files under `.orchestration/sessions/<id>/votes/<round>/`.

## Playtest directory

- Path: `.orchestration/sessions/<id>/playtest/`.
- `test-plan.md` — tester's checklist prepared during Phase 4.
- `findings.md` — tester's playtest findings from Phase 5, using the
  severity format defined in `agents/tester.md`.
- Findings are promoted by recorder-A to `docs/tasks/<id>/playtest.md`
  during Phase 7 (Close).

## MCP lock

- Before calling any `unity-mcp` skill, an agent MUST DM team-lead:
  `mcp_lock acquire <task-id>`. It MAY proceed only after receiving
  `mcp_lock granted`. After the call, it MUST DM `mcp_lock release`.
- Team-lead serializes these requests — grants at most one lock at a time.
- Team-lead logs every lock cycle to `.orchestration/sessions/<id>/mcp-log.md`.
