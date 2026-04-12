---
name: unity-orchestration
description: Use when the user invokes /unity-orchestration or asks to run a Unity task through a 10-agent consensus team. Bootstraps the team and hands off to the team lead.
---

# unity-orchestration

Run a Unity game development task through a 10-agent consensus team
(1 team lead + 2 planners + 2 designers + 2 developers + 2 recorders +
1 tester). Every big task runs through eight phases: Boot → Exploration →
Distribution → Plan Vote → Execution → Playtest → Accept Vote → Close.

## When to use

- User invokes `/unity-orchestration "<task>"`.
- User asks for "multi-agent Unity development", "orchestrated Unity work",
  or similar.

## Pre-flight checks

Before spawning anything, verify:

1. Current working directory is a Unity project (has `Assets/` and
   `ProjectSettings/`), OR the user explicitly confirmed a non-Unity
   directory for dry-run.
2. `unity-mcp` MCP server is configured (check `.claude/settings.json` or
   the user's global `~/.claude/settings.json`). If missing, tell the user
   how to install it and stop.
3. No existing `.orchestration/sessions/*/state.json` with
   `status=in_progress`. If one exists, ask the user to resume or archive it.

## Bootstrap procedure

1. **Scaffold workspace**
   - Run `scripts/init-workspace.sh <project-root>`. This creates
     `.orchestration/sessions/<timestamp>-<slug>/` and seeds `docs/` from
     `templates/docs-tree/` if `docs/` does not already exist.
2. **Create the team**
   - Call `TeamCreate` with name `unity-orch-<timestamp>` and description
     `Unity orchestration for: <task>`.
3. **Spawn team lead first**
   - Call `Agent` tool with `subagent_type: general-purpose`,
     `name: team-lead`, `team_name: unity-orch-<timestamp>`, and the prompt
     from `agents/team-lead.md` with the task and session path injected.
4. **Let team lead spawn the other nine**
   - The team lead's prompt instructs it to spawn planner-a/b, designer-a/b,
     dev-a/b, recorder-a/b, and tester, using the corresponding role prompts.
5. **Return to the user**
   - Emit a short status message: team id, session path, and the link to
     `docs/tasks/<id>/README.md` (which will exist after Phase 6).

## Reference docs in this skill

- `workflow.md` — the seven-phase task lifecycle in full detail.
- `voting.md` — vote message schema, tally rules, deadlock handling.
- `consultation-table.md` — how to use `TaskCreate`/`TaskUpdate` as the
  consultation table, plus transcript conventions.
- `docs-tree-spec.md` — frontmatter schema, path-ID rules, `_meta/index.json`
  schema, folder-README convention.
- `agents/*.md` — role prompts injected when spawning each agent.
- `templates/*` — copyable templates for proposals, votes, ADRs, and the
  initial docs tree.

## Forbidden actions

- Do NOT modify `Assets/` directly from this skill. All scene/code changes
  must go through an agent (designer or developer) via `unity-mcp` or via
  the shared workspace with proper MCP-lock coordination.
- Do NOT spawn agents with `subagent_type: Explore` or `Plan` — those are
  read-only and cannot perform file edits. Use `general-purpose`.
- Do NOT skip `init-workspace.sh`; even dry-runs must create
  `.orchestration/sessions/...`.
