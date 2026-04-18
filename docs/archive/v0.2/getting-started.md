---
id: plugin-docs.getting-started
title: Getting Started
owner: developer
status: stable
updated: 2026-04-11
version: 1
tags: [guide]
---

# Getting Started

## Prerequisites

1. **Claude Code** installed and working.
2. **Superpowers plugin** installed (this plugin relies on its
   dispatching-parallel-agents, TDD, and planning skills).
3. **unity-mcp MCP server** configured. Upstream: `CoplayDev/unity-mcp`.
   Clone locally and add the server to your `~/.claude/settings.json`
   (or per-project `.claude/settings.json`) so `unity-mcp` tools are
   available to Claude Code.
4. A **Unity project** with `Assets/` and `ProjectSettings/` at its root.
5. Python 3 and `git-bash` (Windows) or standard bash (mac/Linux).

## Install the plugin

Clone this repository next to your other Claude Code plugins:

```bash
git clone https://github.com/yeodonghyeon1/orchestration-unity.git
```

Add it to your Claude Code plugin configuration (see Claude Code's plugin
docs for the exact location; in short, point the plugin loader at the
repo root). Claude Code will pick up the `.claude-plugin/plugin.json`.

## Run your first orchestrated task

From the root of your Unity project:

```
/unity-orchestration "add an enemy patrol system"
```

The skill will:
1. Scaffold `.orchestration/` and (if missing) `docs/` in your project.
2. Create an Agent Team with 9 members and hand off to the team lead.
3. Run the seven-phase workflow.
4. When done, point you at `docs/tasks/<id>/README.md` for the summary.

## What to watch

- `docs/` grows as the team produces specs, decisions, and task archives.
- `.orchestration/sessions/<id>/transcript.md` is the live transcript —
  open it in another editor pane if you want to follow the negotiation.
- Unity editor should be running with the `unity-mcp` HTTP server active.
  If it is not, developers and designers will pause and the team lead
  will DM you.

## First-run checklist

- [ ] Unity editor is open on the target project.
- [ ] `unity-mcp` health check passes (`curl http://localhost:8090/health`).
- [ ] Git working tree is clean (recommended but not required).
- [ ] You have the task clearly phrased in one sentence.
