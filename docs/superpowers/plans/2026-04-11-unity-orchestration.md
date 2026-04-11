# Unity Orchestration Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Superpowers-compatible Claude Code plugin `unity-orchestration` that runs Unity game development tasks as a 9-agent consensus team with plan/accept voting, cross-role peer review, and AI-readable documentation output.

**Architecture:** Single plugin with one skill (`unity-orchestration`), one slash command (`/unity-orchestration`), five role prompts (team-lead, planner, designer, developer, recorder), three helper scripts (init-workspace, tally-votes, update-docs-index), and a seed docs-tree template. Runtime uses Claude Code Agent Teams (`TeamCreate`/`SendMessage`) with a single Unity project workspace. See `docs/superpowers/specs/2026-04-11-unity-orchestration-design.md` for full rationale.

**Tech Stack:**
- Claude Code plugin format (`.claude-plugin/plugin.json`, `skills/`, `commands/`, `agents/`)
- Bash for `init-workspace.sh` and `tally-votes.sh`
- Python 3 for `update-docs-index.py` (needs YAML frontmatter parsing) — the design spec sketched `.sh` for all three; this plan locks in Python for the index script because YAML parsing in bash is fragile
- Markdown + YAML frontmatter for all docs/prompts
- JSON for `plugin.json`, vote payloads, and `_meta/index.json`
- Plain `bash` test runners (no framework); fixtures live in `tests/fixtures/`

**Pre-existing state (already created during brainstorming):**
- `D:\orchestration-unity\.gitignore`
- `D:\orchestration-unity\docs\superpowers\specs\2026-04-11-unity-orchestration-design.md`
- `D:\orchestration-unity\docs\superpowers\plans\2026-04-11-unity-orchestration.md` (this file)
- git repo initialized on branch `main`, one commit `b039f92`

**Working directory for all tasks:** `D:\orchestration-unity` (use forward slashes in bash: `/d/orchestration-unity`).

**Windows/git-bash note:** Use `chmod +x` to mark scripts executable. If `core.fileMode` is false, also run `git update-index --chmod=+x <script>` before committing so the executable bit is tracked.

---

## File Structure (target)

```
orchestration-unity/
├── .claude-plugin/
│   └── plugin.json
├── .gitignore                                  (exists)
├── LICENSE                                     (Task 1)
├── README.md                                   (Task 1)
├── CHANGELOG.md                                (Task 1)
├── skills/
│   └── unity-orchestration/
│       ├── SKILL.md                            (Task 3)
│       ├── workflow.md                         (Task 3)
│       ├── voting.md                           (Task 3)
│       ├── consultation-table.md               (Task 3)
│       ├── docs-tree-spec.md                   (Task 3)
│       ├── agents/
│       │   ├── team-lead.md                    (Task 4)
│       │   ├── planner.md                      (Task 4)
│       │   ├── designer.md                     (Task 4)
│       │   ├── developer.md                    (Task 4)
│       │   └── recorder.md                     (Task 4)
│       ├── templates/
│       │   ├── task-table.template.md          (Task 6)
│       │   ├── vote-message.template.json      (Task 6)
│       │   ├── adr.template.md                 (Task 6)
│       │   ├── doc-frontmatter.template.yaml   (Task 6)
│       │   └── docs-tree/                      (Task 6)
│       │       ├── README.md
│       │       ├── _meta/{glossary,conventions}.md + index.json
│       │       ├── {game,design,tech}/README.md
│       │       ├── {decisions,tasks}/.gitkeep
│       │       └── CHANGELOG.md
│       └── scripts/
│           ├── init-workspace.sh               (Task 7)
│           ├── tally-votes.sh                  (Task 8)
│           └── update-docs-index.py            (Task 9)
├── commands/
│   └── unity-orchestration.md                  (Task 5)
├── agents/
│   └── unity-orchestrator.md                   (Task 5)
├── docs/
│   ├── getting-started.md                      (Task 10)
│   ├── architecture.md                         (Task 10)
│   ├── troubleshooting.md                      (Task 10)
│   └── superpowers/
│       ├── specs/2026-04-11-unity-orchestration-design.md   (exists)
│       └── plans/2026-04-11-unity-orchestration.md          (this file)
└── tests/
    ├── structure-check.sh                      (Task 2, extended in Task 11)
    ├── scripts/
    │   ├── init-workspace.test.sh              (Task 7)
    │   ├── tally-votes.test.sh                 (Task 8)
    │   └── update-docs-index.test.sh           (Task 9)
    ├── fixtures/                               (populated by tasks 7-9)
    └── scenarios/
        └── README.md                           (Task 11)
```

---

## Task 1: Plugin scaffold + root files

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `LICENSE`
- Create: `README.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1.1: Write `.claude-plugin/plugin.json`**

```bash
mkdir -p /d/orchestration-unity/.claude-plugin
```

File content:

```json
{
  "name": "unity-orchestration",
  "description": "9-agent consensus team for Unity game development: plan/accept voting, peer review, AI-readable docs tree.",
  "version": "0.1.0",
  "author": {
    "name": "yeodonghyeon1",
    "email": "ydh744@naver.com"
  },
  "license": "MIT",
  "keywords": [
    "unity",
    "orchestration",
    "agent-teams",
    "game-dev",
    "consensus",
    "docs-as-code"
  ]
}
```

- [ ] **Step 1.2: Write `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026 yeodonghyeon1

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 1.3: Write `README.md`**

```markdown
# orchestration-unity

A Claude Code plugin that runs Unity game development tasks as a 9-agent consensus team.

- **Skill name:** `unity-orchestration`
- **Slash command:** `/unity-orchestration "<task description>"`
- **Depends on:** Superpowers plugin, `unity-mcp` MCP server (upstream: `CoplayDev/unity-mcp`)

## What it does

For any non-trivial Unity task you throw at it, the plugin spins up a 9-agent team (1 team lead, 2 planners, 2 designers, 2 developers, 2 recorders) that:

1. Explores the codebase from each role's perspective in parallel.
2. Debates a task distribution and votes on it (≥5/9 to pass).
3. Executes sub-tasks with role-pair peer review.
4. Cross-reviews each other's output and votes again (≥5/9 to accept).
5. Promotes curated session artifacts into a general, AI-readable `docs/` tree.

## Docs

- [Getting started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Full design spec](docs/superpowers/specs/2026-04-11-unity-orchestration-design.md)

## License

MIT
```

- [ ] **Step 1.4: Write `CHANGELOG.md`**

```markdown
# Changelog

All notable changes to this plugin are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org/).

## [Unreleased]

### Added
- Initial design spec (`docs/superpowers/specs/2026-04-11-unity-orchestration-design.md`).
- Initial implementation plan (`docs/superpowers/plans/2026-04-11-unity-orchestration.md`).
```

- [ ] **Step 1.5: Verify all four files exist and `plugin.json` is valid**

Run:
```bash
cd /d/orchestration-unity
ls .claude-plugin/plugin.json LICENSE README.md CHANGELOG.md
python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))" && echo "json ok"
```
Expected: all four paths listed, followed by `json ok`.

- [ ] **Step 1.6: Commit**

```bash
git add .claude-plugin/plugin.json LICENSE README.md CHANGELOG.md
git commit -m "chore: scaffold plugin metadata and root files"
```

---

## Task 2: Minimal `tests/structure-check.sh`

Before writing more content files, set up the structure checker that later tasks will use as their gate. This task's own test is "run the script, confirm it passes against the current state and fails against a known-bad state".

**Files:**
- Create: `tests/structure-check.sh`

- [ ] **Step 2.1: Write the script**

```bash
mkdir -p /d/orchestration-unity/tests
```

File `tests/structure-check.sh`:

```bash
#!/usr/bin/env bash
# tests/structure-check.sh
# Validates plugin structure. Exits 0 on success, 1 on failure.
# Usage: ./tests/structure-check.sh [plugin-root]
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ERRORS=0

err() { echo "FAIL: $1" >&2; ERRORS=$((ERRORS + 1)); }
ok()  { echo "OK:   $1"; }

# --- plugin.json --------------------------------------------------------
if [[ ! -f "$ROOT/.claude-plugin/plugin.json" ]]; then
  err ".claude-plugin/plugin.json missing"
else
  if ! python3 -c "
import json, sys
d = json.load(open('$ROOT/.claude-plugin/plugin.json'))
for k in ('name','description','version'):
    if k not in d: sys.exit('missing key: ' + k)
" 2>/dev/null; then
    err ".claude-plugin/plugin.json invalid or missing required keys (name/description/version)"
  else
    ok ".claude-plugin/plugin.json"
  fi
fi

# --- root files ---------------------------------------------------------
for f in README.md LICENSE CHANGELOG.md .gitignore; do
  if [[ -f "$ROOT/$f" ]]; then
    ok "$f"
  else
    err "$f missing"
  fi
done

# --- report -------------------------------------------------------------
if [[ $ERRORS -gt 0 ]]; then
  echo
  echo "structure-check: $ERRORS error(s)" >&2
  exit 1
fi
echo
echo "structure-check: passed"
```

- [ ] **Step 2.2: Make executable and verify it passes on current state**

```bash
cd /d/orchestration-unity
chmod +x tests/structure-check.sh
bash tests/structure-check.sh
```
Expected: ends with `structure-check: passed`, exit 0.

- [ ] **Step 2.3: Verify it fails on a deliberately broken state**

Temporarily rename `plugin.json` and re-run:
```bash
mv .claude-plugin/plugin.json .claude-plugin/plugin.json.bak
bash tests/structure-check.sh; echo "exit=$?"
mv .claude-plugin/plugin.json.bak .claude-plugin/plugin.json
```
Expected: `FAIL: .claude-plugin/plugin.json missing` printed, script exits 1, then restore succeeds.

- [ ] **Step 2.4: Track executable bit in git (Windows safety)**

```bash
git update-index --chmod=+x tests/structure-check.sh 2>/dev/null || true
git add tests/structure-check.sh
git commit -m "test: add minimal structure-check.sh (plugin.json + root files)"
```

---

## Task 3: SKILL.md entry point + reference docs

**Files:**
- Create: `skills/unity-orchestration/SKILL.md`
- Create: `skills/unity-orchestration/workflow.md`
- Create: `skills/unity-orchestration/voting.md`
- Create: `skills/unity-orchestration/consultation-table.md`
- Create: `skills/unity-orchestration/docs-tree-spec.md`

- [ ] **Step 3.1: Create directories**

```bash
mkdir -p /d/orchestration-unity/skills/unity-orchestration
```

- [ ] **Step 3.2: Write `SKILL.md`**

This is the entry point the Skill tool loads when `/unity-orchestration` is invoked. It must be self-contained enough to bootstrap the team lead.

File `skills/unity-orchestration/SKILL.md`:

```markdown
---
name: unity-orchestration
description: Use when the user invokes /unity-orchestration or asks to run a Unity task through a 9-agent consensus team. Bootstraps the team and hands off to the team lead.
---

# unity-orchestration

Run a Unity game development task through a 9-agent consensus team
(1 team lead + 2 planners + 2 designers + 2 developers + 2 recorders).
Every big task runs through seven phases: Boot → Exploration → Distribution →
Plan Vote → Execution → Accept Vote → Close.

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
4. **Let team lead spawn the other eight**
   - The team lead's prompt instructs it to spawn planner-a/b, designer-a/b,
     dev-a/b, recorder-a/b, using the corresponding role prompts.
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
```

- [ ] **Step 3.3: Write `workflow.md`**

File `skills/unity-orchestration/workflow.md`:

```markdown
---
id: skills.unity-orchestration.workflow
title: Unity Orchestration Workflow (seven phases)
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [workflow, reference]
---

# Workflow Reference

This file is the authoritative reference for the seven-phase task lifecycle.
The design rationale lives in the spec
(`docs/superpowers/specs/2026-04-11-unity-orchestration-design.md`, §3).
Copy §3 of that spec as the body of this document, replacing the top-level
`## 3. Workflow (Task Lifecycle)` header with `## Phases` and adapting
sub-headers to two-hash levels. Keep every numbered step verbatim — this is
the runtime procedure agents follow, not a summary.

Sections required in this file:

- `## Overview` — one paragraph on the seven phases.
- `## Phase 0 — Boot`
- `## Phase 1 — Exploration`
- `## Phase 2 — Distribution`
- `## Phase 3 — Plan Vote`
- `## Phase 4 — Execution`
- `## Phase 5 — Accept Vote`
- `## Phase 6 — Close`
- `## Team lead responsibilities summary`
- `## Recorder responsibilities summary`
```

- [ ] **Step 3.4: Write `voting.md`**

File `skills/unity-orchestration/voting.md`:

```markdown
---
id: skills.unity-orchestration.voting
title: Voting Rules and Vote Schema
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [voting, reference]
---

# Voting Reference

## Vote message schema

Every vote is sent by an agent to `team-lead` via `SendMessage`. The message
body MUST be a JSON object matching this schema:

```json
{
  "vote": "approve",
  "reason": "one-line justification",
  "blocking_issues": ["optional list", "empty array if none"],
  "suggestions": ["optional list", "empty array if none"]
}
```

- `vote`: one of `"approve"`, `"reject"`, `"abstain"`.
- `reason`: required, one line, ≤ 200 chars.
- `blocking_issues`: required array (may be empty); each entry is one
  short sentence describing a concrete blocker.
- `suggestions`: required array (may be empty); each entry is one short
  actionable suggestion.

## Tally rules

- Pass threshold: **5 approvals out of 9**.
- `abstain` does not count as approval. `reject` is counted as opposed.
- Team lead is a voter, not a neutral facilitator.

## Vote moments

- **Plan Vote** — before execution, on the proposed TaskList distribution.
  File: `docs/tasks/<id>/votes/plan-round-N.md`.
- **Accept Vote** — after Phase 4, on cross-role review of outputs.
  File: `docs/tasks/<id>/votes/accept.md`.

## Anti-collusion rule

For Accept Votes, an agent MUST NOT vote to accept artifacts produced by
its own role pair. If all artifacts under review fall inside the agent's
pair, the agent MUST abstain.

## Deadlock handling

- Plan Vote: max **3 rounds**. On 3rd failure, team lead makes a forced
  call, records it as an ADR in `docs/decisions/`, and escalates to the
  user via a terminal-visible message.
- Accept Vote: max **2 re-entries** to Phase 2. On 3rd attempt, escalate.
- Peer-review ping-pong: team lead intervenes after **5 review bounces**
  on the same sub-task; runs a mini-vote (team lead + two non-pair agents)
  to resolve, records as ADR.

## Tally file format (produced by `scripts/tally-votes.sh`)

```markdown
# Plan Vote — Round N

- **Task:** <task description>
- **Date:** YYYY-MM-DD
- **Result:** PASS (6 approve / 2 reject / 1 abstain)

| Agent | Vote | Reason |
|-------|------|--------|
| team-lead | approve | ... |
| planner-a | reject | ... |
| ... | ... | ... |

## Blocking issues
- ...

## Suggestions
- ...
```
```

- [ ] **Step 3.5: Write `consultation-table.md`**

File `skills/unity-orchestration/consultation-table.md`:

```markdown
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

## MCP lock

- Before calling any `unity-mcp` skill, an agent MUST DM team-lead:
  `mcp_lock acquire <task-id>`. It MAY proceed only after receiving
  `mcp_lock granted`. After the call, it MUST DM `mcp_lock release`.
- Team-lead serializes these requests — grants at most one lock at a time.
- Team-lead logs every lock cycle to `.orchestration/sessions/<id>/mcp-log.md`.
```

- [ ] **Step 3.6: Write `docs-tree-spec.md`**

File `skills/unity-orchestration/docs-tree-spec.md`:

```markdown
---
id: skills.unity-orchestration.docs-tree-spec
title: Recorder Docs Tree Specification
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [docs, reference]
---

# Docs Tree Specification

This file is the authoritative reference for the documentation format
produced by recorders. The design rationale is in the spec
(`docs/superpowers/specs/2026-04-11-unity-orchestration-design.md`, §4).

Copy §4 of the spec as the body of this document, including:

- `## Tree layout` (subsections 4.1)
- `## Required frontmatter` (4.2)
- `## Path-ID system` (4.3)
- `## _meta/index.json schema` (4.4)
- `## Folder README convention` (4.5)
- `## ADR format` (4.6)
- `## Task archive format` (4.7)
- `## Engine independence` (4.8)

Every rule must be reproduced verbatim; recorders consult this file when
writing docs during Phase 6.

## Quick reference

- **Every `.md` needs frontmatter** with `id`, `title`, `owner`, `status`,
  `updated`, `version`.
- **Path-ID rule**: strip `docs/`, replace `/` with `.`, drop `.md`.
- **Folder READMEs are AI landing pages** — read them before individual files.
- **Engine-specific vocabulary** (Prefab, ScriptableObject, AssetBundle, etc.)
  is confined to `docs/tech/`.
```

- [ ] **Step 3.7: Verify structure check still passes**

```bash
cd /d/orchestration-unity
bash tests/structure-check.sh
```
Expected: `structure-check: passed`. (Structure check is not yet extended to
validate these files; that happens in Task 11.)

- [ ] **Step 3.8: Commit**

```bash
git add skills/unity-orchestration/SKILL.md \
        skills/unity-orchestration/workflow.md \
        skills/unity-orchestration/voting.md \
        skills/unity-orchestration/consultation-table.md \
        skills/unity-orchestration/docs-tree-spec.md
git commit -m "feat: add SKILL.md entry point and reference docs"
```

---

## Task 4: Agent role prompts (5 files)

Five prompt files go in `skills/unity-orchestration/agents/`. Each is
injected as the `prompt` when the team lead spawns the corresponding agent.
Every prompt MUST contain these sections: frontmatter, `# Role`,
`## Identity`, `## Responsibilities`, `## Communication protocol`,
`## Forbidden actions`, `## First-turn checklist`.

**Files:**
- Create: `skills/unity-orchestration/agents/team-lead.md`
- Create: `skills/unity-orchestration/agents/planner.md`
- Create: `skills/unity-orchestration/agents/designer.md`
- Create: `skills/unity-orchestration/agents/developer.md`
- Create: `skills/unity-orchestration/agents/recorder.md`

- [ ] **Step 4.1: Create directory**

```bash
mkdir -p /d/orchestration-unity/skills/unity-orchestration/agents
```

- [ ] **Step 4.2: Write `team-lead.md`**

```markdown
---
id: skills.unity-orchestration.agents.team-lead
title: Team Lead Prompt
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [agent-prompt, team-lead]
---

# Role: Team Lead

## Identity

You are the team lead for a Unity orchestration session. You are the central
hub: you distribute work, gate Unity MCP access, tally votes, and decide when
to escalate. You are also a voting participant, not a neutral facilitator.

You will receive a JSON payload on your first turn:

```json
{
  "task": "<task description>",
  "session_path": ".orchestration/sessions/<id>/",
  "team_name": "unity-orch-<timestamp>"
}
```

## Responsibilities

- Spawn the other 8 agents via the `Agent` tool (names: `planner-a`,
  `planner-b`, `designer-a`, `designer-b`, `dev-a`, `dev-b`,
  `recorder-a`, `recorder-b`; `subagent_type: general-purpose`; inject the
  corresponding `agents/<role>.md` prompt).
- Drive the seven-phase workflow (`skills/unity-orchestration/workflow.md`).
- Maintain the TaskList: create tasks in Phase 2, update status through
  Phase 4, never allow more than one `in_progress` per agent.
- Manage the Unity MCP lock. Exactly one agent may hold the lock at a time.
  Log every acquire/release to
  `.orchestration/sessions/<id>/mcp-log.md`.
- Tally votes using `scripts/tally-votes.sh` and write results to
  `docs/tasks/<id>/votes/plan-round-N.md` or `accept.md`.
- Monitor for deadlocks (ping-pong, silent agents, vote failures) and apply
  the deadlock rules in `voting.md`.
- Track your own token usage. Warn at 80%, stop cleanly at 90%.

## Communication protocol

- All inter-agent communication goes through `SendMessage`. Plain text
  output is reserved for reporting final results to the user.
- When addressing the team as a whole, use `to: "*"`.
- When tallying votes, wait until all 9 agents (including yourself) have
  responded OR the 2-ping timeout elapses for silent agents.
- Recorder-A must receive a DM whenever a phase transition occurs.

## Forbidden actions

- Never call `unity-mcp` yourself — developers and designers hold that
  capability.
- Never edit files directly without a TaskList entry in `in_progress`.
- Never skip a phase or merge two phases.
- Never grant two MCP locks simultaneously.
- Never terminate the session before Phase 6 is complete unless the user
  explicitly requests it.

## First-turn checklist

1. Parse the payload. Verify `session_path` exists.
2. Read `skills/unity-orchestration/workflow.md` in full.
3. Read `skills/unity-orchestration/voting.md` in full.
4. Read `skills/unity-orchestration/consultation-table.md` in full.
5. Spawn the other 8 agents with their role prompts.
6. Broadcast the Phase 1 exploration kickoff to all 9 agents (including
   yourself — you must also produce a proposal).
7. Wait for proposals; do not advance to Phase 2 until all 9 are present
   or the silent-agent rule triggers.
```

- [ ] **Step 4.3: Write `planner.md`**

```markdown
---
id: skills.unity-orchestration.agents.planner
title: Planner Prompt
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [agent-prompt, planner]
---

# Role: Planner (game/system designer)

## Identity

You are one of two planners (`planner-a` or `planner-b`). You own game
systems, balancing, levels, narrative direction, and acceptance criteria.
The other planner is your peer: you must reach agreement with them before
handing work off.

If your name ends in `-b`, your additional mandate is **reviewer mode** —
you critique planner-a's proposals and outputs aggressively but
constructively. A rubber-stamp approval from you is a failure.

## Responsibilities

- Define game systems and write specs to `docs/game/systems/<name>.md`.
- Define balance parameters and write to `docs/game/balancing/<name>.md`.
- Define level intents (not layouts — that's design) and write to
  `docs/game/levels/<name>.md`.
- Write acceptance criteria for each sub-task you claim.
- Request developers create `ScriptableObject` data assets for numeric
  game data; don't implement them yourself.
- Peer-review your pair's outputs before they're marked complete.

## Communication protocol

- All communication via `SendMessage`. Address your pair by name
  (`planner-a`/`planner-b`).
- Submit proposals to team-lead by writing them to
  `.orchestration/sessions/<id>/proposals/planner-<a|b>.md`, then DM
  team-lead `proposal submitted`.
- Votes go to team-lead as JSON (see `voting.md`).

## Forbidden actions

- Never call `unity-mcp`. You do not edit scenes, prefabs, or code.
- Never write files under `docs/tech/` or `docs/design/` — those are not
  your territory.
- Never approve your pair's work by default; if you cannot find genuine
  merit to approve, reject and explain.
- Never skip the peer-review handshake.

## First-turn checklist

1. Read the task and session path from the spawn payload.
2. Read `docs/_meta/index.json` (if present) to understand existing docs.
3. Read any existing `docs/game/overview.md`.
4. Explore the codebase for related systems (use `Grep` for keywords in
   the task).
5. Write your proposal to
   `.orchestration/sessions/<id>/proposals/planner-<a|b>.md` using the
   `templates/task-table.template.md` format.
6. DM team-lead `proposal submitted`.
```

- [ ] **Step 4.4: Write `designer.md`**

```markdown
---
id: skills.unity-orchestration.agents.designer
title: Designer Prompt
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [agent-prompt, designer]
---

# Role: Designer (scene/prefab/UI)

## Identity

You are one of two designers (`designer-a` or `designer-b`). You own scene
layout, prefab structure, art direction, lighting intent, and UI
wireframes. You CAN call `unity-mcp` directly to construct scenes and
prefabs, but you are not required to — writing a clear spec for developers
to implement is equally valid. Choose whichever path makes the task
smaller.

If your name ends in `-b`, you are in reviewer mode. See the planner
prompt's reviewer note; the same rule applies.

## Responsibilities

- Define scene layouts and write specs to `docs/design/scenes/<name>.md`.
- Define prefab structures and write to `docs/design/prefabs/<name>.md`.
- Define UI flows and write to `docs/design/ui/<name>.md`.
- Maintain `docs/design/art-direction.md` as the project evolves.
- When constructing actual scenes, use `unity-mcp` GameObject/Material/
  Light/UI skills — BUT always acquire the MCP lock from team-lead first.
- Peer-review your pair's outputs.

## Communication protocol

- All communication via `SendMessage`.
- Before any `unity-mcp` call: DM team-lead `mcp_lock acquire <task-id>`;
  wait for `mcp_lock granted`; after the batch, DM `mcp_lock release`.
- Proposals, votes, and peer review go through the standard channels.

## Forbidden actions

- Never call `unity-mcp` without holding the MCP lock.
- Never edit C# code — that is the developer's territory. Specify, don't
  implement.
- Never edit files under `docs/game/` or `docs/tech/`.
- Never rubber-stamp your pair.

## First-turn checklist

1. Read the task and session path.
2. Read `docs/design/art-direction.md` (if present) and any existing
   entries under `docs/design/scenes/`.
3. Optionally query `unity-mcp` for a read-only view of the current scene
   (e.g., `scene_get_hierarchy`) — this does NOT require the lock if the
   call is explicitly read-only. Confirm with team-lead if unsure.
4. Write your proposal to
   `.orchestration/sessions/<id>/proposals/designer-<a|b>.md`.
5. DM team-lead `proposal submitted`.
```

- [ ] **Step 4.5: Write `developer.md`**

```markdown
---
id: skills.unity-orchestration.agents.developer
title: Developer Prompt
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [agent-prompt, developer]
---

# Role: Developer (C# implementation)

## Identity

You are one of two developers (`dev-a` or `dev-b`). You own C# scripts,
components, editor tools, tests, and data-asset implementation (e.g.,
ScriptableObject classes). You CAN call `unity-mcp` to create scripts,
attach components, and run tests. You MUST hold the MCP lock while doing so.

If your name ends in `-b`, you are in reviewer mode.

## Responsibilities

- Implement C# scripts under `Assets/Scripts/`.
- Create `ScriptableObject` classes requested by planners and populate the
  initial data asset instances.
- Write Unity Test Framework tests under `Assets/Tests/` for any new
  non-trivial logic.
- Document each module you create in `docs/tech/modules/<name>.md` (and
  `docs/tech/api/<name>.md` for public APIs).
- Update `docs/tech/architecture.md` when you make a structural change.
- Peer-review your pair's code (functionality, tests, style, safety).

## Communication protocol

- All communication via `SendMessage`.
- Before any `unity-mcp` call: DM team-lead `mcp_lock acquire <task-id>`;
  wait for `mcp_lock granted`; after the batch, DM `mcp_lock release`.
- Before claiming a task complete, ensure your pair has approved it AND
  tests pass.

## Forbidden actions

- Never call `unity-mcp` without holding the MCP lock.
- Never edit files under `docs/game/` or `docs/design/` — specify instead.
- Never mark a task completed with failing tests.
- Never skip the test-writing step, even for "simple" logic.
- Never rubber-stamp your pair.

## First-turn checklist

1. Read the task and session path.
2. Read `docs/tech/architecture.md` and any relevant `docs/tech/modules/`.
3. Use `Grep`/`Glob` to locate related existing scripts in `Assets/Scripts/`.
4. Optionally query `unity-mcp` for project info (read-only, no lock).
5. Write your proposal to
   `.orchestration/sessions/<id>/proposals/dev-<a|b>.md`.
6. DM team-lead `proposal submitted`.
```

- [ ] **Step 4.6: Write `recorder.md`**

```markdown
---
id: skills.unity-orchestration.agents.recorder
title: Recorder Prompt
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [agent-prompt, recorder]
---

# Role: Recorder (docs + transcript)

## Identity

You are one of two recorders (`recorder-a` or `recorder-b`).

- **recorder-a** is the **writer**: you maintain the session transcript in
  real time, and during Phase 6 you promote session artifacts to
  `docs/tasks/<id>/` and regenerate `_meta/index.json`.
- **recorder-b** is the **docs quality reviewer**: you judge whether the
  docs produced by recorder-a (and the in-project `docs/` tree overall)
  are actually usable as documentation — readability, consistency,
  frontmatter correctness, broken references. You are NOT a rubber stamp;
  if recorder-a's archive is sloppy, reject and list specific fixes.

Your first-turn behavior depends on which of the two you are. The spawn
payload includes `role: "recorder-a"` or `role: "recorder-b"`.

## Responsibilities (recorder-a)

- Append to `.orchestration/sessions/<id>/transcript.md` on every phase
  transition and major DM you're CC'd on. Use the format in
  `consultation-table.md`.
- In Phase 6, promote session artifacts to `docs/tasks/<id>/`:
  - `README.md` (one-page summary with frontmatter `id: tasks.<id>`)
  - `consultation.md` (cleaned transcript)
  - `votes.md` (plan rounds + accept)
  - `outcome.md` (files created/modified with git diff links)
- Update affected folder `README.md` files.
- Run `scripts/update-docs-index.py` to regenerate `_meta/index.json`.
- Append a one-line entry to `docs/CHANGELOG.md`.

## Responsibilities (recorder-b)

- During Phase 5, review `docs/` changes made during this task from a
  documentation-quality perspective:
  - Does every new/modified `.md` have valid frontmatter?
  - Are IDs consistent with paths?
  - Are `depends_on` references resolvable?
  - Is the prose clear for a reader who joined the project today?
  - Are folder `README.md` files up to date?
- In Phase 6, audit recorder-a's archive before the team shuts down.
- Your Accept Vote is gated by whether the docs would be usable by a
  newcomer.

## Communication protocol

- All communication via `SendMessage`.
- Recorder-a receives forwarded messages from team-lead; keep up.
- Recorder-b primarily reads files and talks to team-lead.

## Forbidden actions

- Never call `unity-mcp`.
- Never edit `Assets/` or any source code.
- Recorder-a must not invent content — only record what actually
  happened.
- Recorder-b must not rewrite recorder-a's work; file issues instead and
  let recorder-a fix them.

## First-turn checklist (both)

1. Read the task and session path.
2. Read `docs/_meta/index.json` if present.
3. Read `skills/unity-orchestration/docs-tree-spec.md` in full.
4. Write your proposal to
   `.orchestration/sessions/<id>/proposals/recorder-<a|b>.md`:
   - Past similar tasks in `docs/tasks/` worth referencing
   - Doc hygiene issues you already see
   - Your plan for tracking this session
5. DM team-lead `proposal submitted`.
```

- [ ] **Step 4.7: Verify all five exist and have frontmatter**

```bash
cd /d/orchestration-unity
for f in team-lead planner designer developer recorder; do
  head -8 skills/unity-orchestration/agents/$f.md | head -1 | grep -q '^---$' \
    && echo "OK: $f.md" || echo "FAIL: $f.md"
done
```
Expected: five OK lines.

- [ ] **Step 4.8: Commit**

```bash
git add skills/unity-orchestration/agents/
git commit -m "feat: add 5 agent role prompts (team-lead, planner, designer, developer, recorder)"
```

---

## Task 5: Slash command wrapper + team-lead bootstrap agent

**Files:**
- Create: `commands/unity-orchestration.md`
- Create: `agents/unity-orchestrator.md`

- [ ] **Step 5.1: Write `commands/unity-orchestration.md`**

```bash
mkdir -p /d/orchestration-unity/commands
```

File:

```markdown
---
name: unity-orchestration
description: Run a Unity task through a 9-agent consensus team.
argument-hint: "<task description>"
---

Invoke the `unity-orchestration` skill from the `unity-orchestration` plugin
with the user's task description as input.

User task: $ARGUMENTS

Use the Skill tool to load `unity-orchestration` and follow its bootstrap
procedure. Do not spawn agents directly from this command — the skill owns
that flow.
```

- [ ] **Step 5.2: Write `agents/unity-orchestrator.md`**

```bash
mkdir -p /d/orchestration-unity/agents
```

This file registers a named subagent type that can be used as a one-shot
bootstrap if the user prefers `Agent(subagent_type="unity-orchestrator")`
over the slash command. It is optional for v1 but cheap to include.

File:

```markdown
---
name: unity-orchestrator
description: One-shot bootstrap for the unity-orchestration skill. Invoke this when the user wants an orchestrated Unity task and prefers the Agent tool to the slash command.
tools: Read, Write, Edit, Bash, Glob, Grep, Skill, TeamCreate, TaskCreate, TaskUpdate, TaskList, SendMessage
---

You are the unity-orchestration bootstrap agent. Your only job is to load
the `unity-orchestration` skill (via the Skill tool) and follow its
bootstrap procedure. You do not execute tasks yourself — the team lead the
skill spawns does that.

On your first turn:
1. Call `Skill` with `skill: "unity-orchestration"`.
2. Pass the user's task description as the argument.
3. Report back the team id and session path, then exit.
```

- [ ] **Step 5.3: Verify files exist**

```bash
ls commands/unity-orchestration.md agents/unity-orchestrator.md
```
Expected: both paths printed.

- [ ] **Step 5.4: Commit**

```bash
git add commands/unity-orchestration.md agents/unity-orchestrator.md
git commit -m "feat: add /unity-orchestration slash command and bootstrap agent"
```

---

## Task 6: Templates (non-docs-tree + docs-tree seed)

**Files:**
- Create: `skills/unity-orchestration/templates/task-table.template.md`
- Create: `skills/unity-orchestration/templates/vote-message.template.json`
- Create: `skills/unity-orchestration/templates/adr.template.md`
- Create: `skills/unity-orchestration/templates/doc-frontmatter.template.yaml`
- Create: `skills/unity-orchestration/templates/docs-tree/README.md`
- Create: `skills/unity-orchestration/templates/docs-tree/_meta/glossary.md`
- Create: `skills/unity-orchestration/templates/docs-tree/_meta/conventions.md`
- Create: `skills/unity-orchestration/templates/docs-tree/_meta/index.json`
- Create: `skills/unity-orchestration/templates/docs-tree/game/README.md`
- Create: `skills/unity-orchestration/templates/docs-tree/design/README.md`
- Create: `skills/unity-orchestration/templates/docs-tree/tech/README.md`
- Create: `skills/unity-orchestration/templates/docs-tree/decisions/.gitkeep`
- Create: `skills/unity-orchestration/templates/docs-tree/tasks/.gitkeep`
- Create: `skills/unity-orchestration/templates/docs-tree/CHANGELOG.md`

- [ ] **Step 6.1: Create template directories**

```bash
cd /d/orchestration-unity
mkdir -p skills/unity-orchestration/templates/docs-tree/_meta \
         skills/unity-orchestration/templates/docs-tree/game \
         skills/unity-orchestration/templates/docs-tree/design \
         skills/unity-orchestration/templates/docs-tree/tech \
         skills/unity-orchestration/templates/docs-tree/decisions \
         skills/unity-orchestration/templates/docs-tree/tasks
```

- [ ] **Step 6.2: Write `task-table.template.md` (proposal format)**

```markdown
---
role: <role-name>               # e.g. planner-a
task_id: <YYYY-MM-DD-slug>
---

## Perspective

<One paragraph: how do I see this task from my role's angle?>

## Candidate sub-tasks (I will own)

- [ ] <short actionable step>
- [ ] <short actionable step>

## Dependencies on other roles

- **<role>**: <what I need from them>

## Risks

- <risk and proposed mitigation>

## Estimated effort

<small | medium | large> — <one-line justification>
```

- [ ] **Step 6.3: Write `vote-message.template.json`**

```json
{
  "vote": "approve",
  "reason": "",
  "blocking_issues": [],
  "suggestions": []
}
```

- [ ] **Step 6.4: Write `adr.template.md`**

```markdown
---
id: decisions.<YYYY-MM-DD-slug>
title: <short decision title>
owner: <role-that-drove-decision>
status: stable
updated: <YYYY-MM-DD>
version: 1
tags: [decision]
task_origin: <task-id>
---

# <short decision title>

## Context

<What's the situation? Why is a decision needed?>

## Decision

<What did we decide?>

## Consequences

<Positive / negative / neutral effects.>

## Alternatives considered

- **<option>**: <why rejected>

## Votes

- approve: <agent list>
- reject: <agent list, with reasons>
- abstain: <agent list>
```

- [ ] **Step 6.5: Write `doc-frontmatter.template.yaml`**

```yaml
---
id: <domain>.<section>.<slug>
title: <human-readable title>
owner: <planner|designer|developer|recorder>
status: draft
updated: <YYYY-MM-DD>
version: 1
depends_on: []
referenced_by: []
tags: []
task_origin: <task-id>
---
```

- [ ] **Step 6.6: Write `docs-tree/README.md`**

```markdown
---
id: root
title: Project Documentation
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index]
---

# Project Documentation

This tree is generated and maintained by the `unity-orchestration` plugin's
recorder agents. It is AI-readable first, human-readable second. The format
is documented in
`skills/unity-orchestration/docs-tree-spec.md` (plugin side).

## Top-level areas

- [`_meta/`](_meta/) — glossary, conventions, and the machine-readable
  `index.json`.
- [`game/`](game/README.md) — planner domain: systems, balancing, levels,
  narrative.
- [`design/`](design/README.md) — designer domain: scenes, prefabs, UI, art
  direction.
- [`tech/`](tech/README.md) — developer domain: architecture, modules, API,
  testing. Engine-specific vocabulary lives here.
- [`decisions/`](decisions/) — ADRs. Immutable once `status=stable`.
- [`tasks/`](tasks/) — archived task bundles with consultation transcripts
  and vote records.

## Reading order for AI agents

1. `_meta/index.json` for structure overview.
2. Each folder's `README.md` before diving into its files.
3. `decisions/` for context on past forks in the road.
4. `tasks/<most-recent-id>/README.md` for the latest completed work.
```

- [ ] **Step 6.7: Write `docs-tree/_meta/glossary.md`**

```markdown
---
id: _meta.glossary
title: Glossary
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [glossary]
---

# Glossary

Define project-specific terms here. Each entry:

## <term>

<definition, one or two sentences. Link to canonical doc if applicable.>

---

(No entries yet — add them as the project grows.)
```

- [ ] **Step 6.8: Write `docs-tree/_meta/conventions.md`**

```markdown
---
id: _meta.conventions
title: Documentation Conventions
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [conventions]
---

# Documentation Conventions

Rules every doc in this tree must follow.

## Frontmatter

Every `.md` file MUST have YAML frontmatter with: `id`, `title`, `owner`,
`status`, `updated`, `version`. Optional: `depends_on`, `referenced_by`,
`tags`, `task_origin`.

## Path-ID mapping

- Strip `docs/` prefix.
- Replace `/` with `.`.
- Drop the `.md` extension.

Example: `docs/game/systems/combat.md` → id `game.systems.combat`.

## File size

- Target: 200–400 lines per file.
- Hard limit: 800 lines. If a file exceeds this, split it into a folder
  of smaller files plus an index `README.md`.

## Links

- Between docs in this tree: use relative paths.
- To external URLs: use Markdown links with descriptive text.

## Status values

- `draft` — being written.
- `review` — waiting for peer/recorder-B approval.
- `stable` — approved, safe to reference.
- `archived` — obsolete but preserved for history. Do not delete.

## Engine independence

`game/`, `design/`, `decisions/`, `tasks/`, `_meta/` must remain
engine-agnostic. Unity-specific vocabulary is confined to `tech/`.
```

- [ ] **Step 6.9: Write `docs-tree/_meta/index.json` (initial empty state)**

```json
{
  "version": 1,
  "generated_at": null,
  "generator": "scripts/update-docs-index.py",
  "project": {
    "name": "",
    "engine": "",
    "genre": ""
  },
  "tree": {},
  "by_tag": {},
  "by_owner": {},
  "dangling_references": [],
  "orphans": []
}
```

- [ ] **Step 6.10: Write `docs-tree/game/README.md`**

```markdown
---
id: game
title: Game Design Domain
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index, game]
---

# Game Design Domain (planner territory)

This area is owned by planner agents. It describes what the game IS, not
how it is built.

## Subfolders

- `overview.md` — top-level game concept, target audience, core loop.
- `systems/` — one file per game system (combat, inventory, progression…).
- `levels/` — level and stage specs.
- `balancing/` — numeric tables and rationale.
- `narrative/` — story, characters, dialog.

## Authoring rules

- One system = one file. Split when > 800 lines.
- Every system file must declare `depends_on: [game.overview]` at minimum.
- Do NOT reference Unity-specific constructs; use engine-neutral language.
```

- [ ] **Step 6.11: Write `docs-tree/design/README.md`**

```markdown
---
id: design
title: Visual & UX Design Domain
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index, design]
---

# Visual & UX Design Domain (designer territory)

This area is owned by designer agents. It describes what the game LOOKS
and FEELS like, and what the player sees.

## Subfolders

- `art-direction.md` — tone, color, reference boards.
- `scenes/` — per-scene layout specs.
- `prefabs/` — prefab structures and composition rules.
- `ui/` — UI wireframes and flow diagrams.

## Authoring rules

- Scene specs are engine-neutral where possible: describe intent, not
  Unity hierarchy.
- Prefab specs may mention Unity-specific concepts only when necessary,
  but prefer to link to `tech/` for implementation detail.
- Every scene file must declare `depends_on` on the levels it supports.
```

- [ ] **Step 6.12: Write `docs-tree/tech/README.md`**

```markdown
---
id: tech
title: Technical Domain
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index, tech]
---

# Technical Domain (developer territory)

This area is owned by developer agents. It is the ONLY place where
Unity-specific vocabulary (Prefab, ScriptableObject, AssetBundle, URP,
HDRP, etc.) is permitted in documentation.

## Subfolders

- `architecture.md` — top-level system architecture.
- `modules/` — one file per code module.
- `api/` — public APIs of modules (classes, components, interfaces).
- `testing.md` — test strategy and conventions.

## Authoring rules

- Every module file must declare `depends_on` on the module(s) it imports.
- Public API changes must bump the file `version`.
- Link outward to `game/` or `design/` specs that drove the
  implementation via `depends_on`.
```

- [ ] **Step 6.13: Write `.gitkeep` files + `CHANGELOG.md`**

```bash
cd /d/orchestration-unity/skills/unity-orchestration/templates/docs-tree
: > decisions/.gitkeep
: > tasks/.gitkeep
```

File `templates/docs-tree/CHANGELOG.md`:

```markdown
# Project Changelog

Append-only log of docs-tree changes. One line per completed orchestration
task. Format:

```
YYYY-MM-DD — <task-id> — <one-line summary of what was produced/modified>
```

## Entries

(Empty — entries appear after the first orchestration session completes.)
```

- [ ] **Step 6.14: Verify all template files exist**

```bash
cd /d/orchestration-unity
find skills/unity-orchestration/templates -type f | sort
```
Expected output (order may vary slightly):
```
skills/unity-orchestration/templates/adr.template.md
skills/unity-orchestration/templates/doc-frontmatter.template.yaml
skills/unity-orchestration/templates/docs-tree/CHANGELOG.md
skills/unity-orchestration/templates/docs-tree/README.md
skills/unity-orchestration/templates/docs-tree/_meta/conventions.md
skills/unity-orchestration/templates/docs-tree/_meta/glossary.md
skills/unity-orchestration/templates/docs-tree/_meta/index.json
skills/unity-orchestration/templates/docs-tree/decisions/.gitkeep
skills/unity-orchestration/templates/docs-tree/design/README.md
skills/unity-orchestration/templates/docs-tree/game/README.md
skills/unity-orchestration/templates/docs-tree/tasks/.gitkeep
skills/unity-orchestration/templates/docs-tree/tech/README.md
skills/unity-orchestration/templates/task-table.template.md
skills/unity-orchestration/templates/vote-message.template.json
```

- [ ] **Step 6.15: Commit**

```bash
git add skills/unity-orchestration/templates/
git commit -m "feat: add proposal/vote/adr/frontmatter templates and docs-tree seed"
```

---

## Task 7: `init-workspace.sh` + test

This script scaffolds runtime session state in a target Unity project.

**Files:**
- Create: `skills/unity-orchestration/scripts/init-workspace.sh`
- Create: `tests/scripts/init-workspace.test.sh`

- [ ] **Step 7.1: Write the failing test first**

```bash
mkdir -p /d/orchestration-unity/skills/unity-orchestration/scripts \
         /d/orchestration-unity/tests/scripts
```

File `tests/scripts/init-workspace.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/init-workspace.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$ROOT/skills/unity-orchestration/scripts/init-workspace.sh"
TEMPLATES="$ROOT/skills/unity-orchestration/templates/docs-tree"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
assert_file() { [[ -f "$1" ]] || { echo "FAIL: missing file $1"; FAILED=1; }; }
assert_dir()  { [[ -d "$1" ]] || { echo "FAIL: missing dir  $1"; FAILED=1; }; }

# --- Case 1: empty project, session + docs both scaffolded ----------------
mkdir -p "$TMP/proj1"
bash "$SCRIPT" "$TMP/proj1" "test-task-slug" >/dev/null

# session dir should exist under .orchestration/sessions/<timestamp>-slug
session_dir="$(find "$TMP/proj1/.orchestration/sessions" -mindepth 1 -maxdepth 1 -type d | head -1)"
assert_dir  "$session_dir"
assert_file "$session_dir/state.json"
assert_dir  "$session_dir/proposals"
assert_dir  "$session_dir/votes"
assert_file "$session_dir/transcript.md"
assert_file "$session_dir/mcp-log.md"

# docs/ should be seeded from template
assert_file "$TMP/proj1/docs/README.md"
assert_file "$TMP/proj1/docs/_meta/index.json"
assert_file "$TMP/proj1/docs/game/README.md"
assert_file "$TMP/proj1/docs/CHANGELOG.md"

# --- Case 2: project with existing docs, docs preserved -------------------
mkdir -p "$TMP/proj2/docs"
echo "# existing" > "$TMP/proj2/docs/README.md"
bash "$SCRIPT" "$TMP/proj2" "another-slug" >/dev/null
existing="$(cat "$TMP/proj2/docs/README.md")"
if [[ "$existing" != "# existing" ]]; then
  echo "FAIL: existing docs/README.md was overwritten"
  FAILED=1
fi

# --- Case 3: state.json is valid JSON with required fields ---------------
session_dir2="$(find "$TMP/proj1/.orchestration/sessions" -mindepth 1 -maxdepth 1 -type d | head -1)"
python3 -c "
import json, sys
d = json.load(open('$session_dir2/state.json'))
for k in ('session_id','task_slug','phase','round','created_at'):
    if k not in d: sys.exit('missing key: ' + k)
if d['phase'] != 'boot': sys.exit('phase should be boot, got ' + d['phase'])
" || FAILED=1

if [[ $FAILED -eq 0 ]]; then
  echo "init-workspace.test.sh: PASS"
else
  echo "init-workspace.test.sh: FAIL"
  exit 1
fi
```

Make executable:
```bash
chmod +x /d/orchestration-unity/tests/scripts/init-workspace.test.sh
```

- [ ] **Step 7.2: Run the test and verify it fails**

```bash
cd /d/orchestration-unity
bash tests/scripts/init-workspace.test.sh; echo "exit=$?"
```
Expected: failure message (script doesn't exist yet). Exit non-zero.

- [ ] **Step 7.3: Implement the script**

File `skills/unity-orchestration/scripts/init-workspace.sh`:

```bash
#!/usr/bin/env bash
# Initializes a Unity-orchestration workspace in a target project.
# Creates .orchestration/sessions/<timestamp>-<slug>/ and seeds docs/
# from the plugin's docs-tree template if docs/ is missing.
#
# Usage: init-workspace.sh <project-root> <task-slug>
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: init-workspace.sh <project-root> <task-slug>" >&2
  exit 2
fi

PROJECT_ROOT="$1"
TASK_SLUG="$2"
PLUGIN_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TEMPLATE_DIR="$PLUGIN_ROOT/skills/unity-orchestration/templates/docs-tree"

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "error: project root not found: $PROJECT_ROOT" >&2
  exit 1
fi
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "error: template not found: $TEMPLATE_DIR" >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
SESSION_ID="${TS}-${TASK_SLUG}"
SESSION_DIR="$PROJECT_ROOT/.orchestration/sessions/$SESSION_ID"

mkdir -p "$SESSION_DIR/proposals" "$SESSION_DIR/votes"

# state.json
cat > "$SESSION_DIR/state.json" <<EOF
{
  "session_id": "$SESSION_ID",
  "task_slug": "$TASK_SLUG",
  "phase": "boot",
  "round": 0,
  "created_at": "$TS",
  "mcp_lock_holder": null,
  "task_id": null
}
EOF

# transcript + mcp-log (empty but present)
: > "$SESSION_DIR/transcript.md"
: > "$SESSION_DIR/mcp-log.md"

# Seed docs/ if missing
if [[ ! -d "$PROJECT_ROOT/docs" ]]; then
  cp -R "$TEMPLATE_DIR" "$PROJECT_ROOT/docs"
fi

echo "$SESSION_DIR"
```

Make executable:
```bash
chmod +x /d/orchestration-unity/skills/unity-orchestration/scripts/init-workspace.sh
```

- [ ] **Step 7.4: Run the test and verify it passes**

```bash
cd /d/orchestration-unity
bash tests/scripts/init-workspace.test.sh
```
Expected: `init-workspace.test.sh: PASS`, exit 0.

- [ ] **Step 7.5: Track executable bits and commit**

```bash
git update-index --chmod=+x skills/unity-orchestration/scripts/init-workspace.sh 2>/dev/null || true
git update-index --chmod=+x tests/scripts/init-workspace.test.sh 2>/dev/null || true
git add skills/unity-orchestration/scripts/init-workspace.sh \
        tests/scripts/init-workspace.test.sh
git commit -m "feat: add init-workspace.sh with test"
```

---

## Task 8: `tally-votes.sh` + test

This script reads per-agent vote JSON files from a directory and produces the
markdown tally file that lives under `docs/tasks/<id>/votes/`.

**Files:**
- Create: `skills/unity-orchestration/scripts/tally-votes.sh`
- Create: `tests/scripts/tally-votes.test.sh`
- Create: `tests/fixtures/votes/round-pass/*.json`
- Create: `tests/fixtures/votes/round-fail/*.json`

- [ ] **Step 8.1: Create fixtures**

```bash
cd /d/orchestration-unity
mkdir -p tests/fixtures/votes/round-pass tests/fixtures/votes/round-fail
```

Create 9 fixture files under `round-pass/` — 6 approve, 2 reject, 1 abstain
(passes with 6/9):

`tests/fixtures/votes/round-pass/team-lead.json`:
```json
{"vote":"approve","reason":"distribution is coherent","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-pass/planner-a.json`:
```json
{"vote":"approve","reason":"covers all systems","blocking_issues":[],"suggestions":["clarify balance curve"]}
```
`tests/fixtures/votes/round-pass/planner-b.json`:
```json
{"vote":"reject","reason":"missing acceptance criteria","blocking_issues":["no accept criteria on task 3"],"suggestions":[]}
```
`tests/fixtures/votes/round-pass/designer-a.json`:
```json
{"vote":"approve","reason":"scene scope is realistic","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-pass/designer-b.json`:
```json
{"vote":"approve","reason":"ok","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-pass/dev-a.json`:
```json
{"vote":"approve","reason":"no unknowns in implementation","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-pass/dev-b.json`:
```json
{"vote":"reject","reason":"tests undefined","blocking_issues":["no tests listed for task 5"],"suggestions":["add test plan per sub-task"]}
```
`tests/fixtures/votes/round-pass/recorder-a.json`:
```json
{"vote":"approve","reason":"archival plan is clear","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-pass/recorder-b.json`:
```json
{"vote":"abstain","reason":"insufficient doc impact to judge","blocking_issues":[],"suggestions":[]}
```

Create 9 fixture files under `round-fail/` — 4 approve, 3 reject, 2 abstain
(fails with 4/9):

`tests/fixtures/votes/round-fail/team-lead.json`:
```json
{"vote":"approve","reason":"plan ok","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-fail/planner-a.json`:
```json
{"vote":"reject","reason":"scope too large","blocking_issues":["too many systems in one pass"],"suggestions":[]}
```
`tests/fixtures/votes/round-fail/planner-b.json`:
```json
{"vote":"reject","reason":"balance unclear","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-fail/designer-a.json`:
```json
{"vote":"approve","reason":"ok","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-fail/designer-b.json`:
```json
{"vote":"approve","reason":"ok","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-fail/dev-a.json`:
```json
{"vote":"abstain","reason":"cannot evaluate planner docs","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-fail/dev-b.json`:
```json
{"vote":"abstain","reason":"same","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-fail/recorder-a.json`:
```json
{"vote":"approve","reason":"ok","blocking_issues":[],"suggestions":[]}
```
`tests/fixtures/votes/round-fail/recorder-b.json`:
```json
{"vote":"reject","reason":"docs quality risk","blocking_issues":["no doc update plan"],"suggestions":[]}
```

- [ ] **Step 8.2: Write the failing test**

File `tests/scripts/tally-votes.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/tally-votes.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$ROOT/skills/unity-orchestration/scripts/tally-votes.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0

# --- Case 1: passing round (6 approve / 2 reject / 1 abstain) ------------
out="$TMP/pass.md"
bash "$SCRIPT" \
  --round 1 \
  --type plan \
  --task "test enemy ai" \
  --input "$ROOT/tests/fixtures/votes/round-pass" \
  --output "$out"

grep -q "Result:.*PASS" "$out" || { echo "FAIL: pass round did not produce PASS"; FAILED=1; }
grep -q "6 approve" "$out"     || { echo "FAIL: tally count wrong"; FAILED=1; }
grep -q "2 reject"  "$out"     || { echo "FAIL: reject count wrong"; FAILED=1; }
grep -q "1 abstain" "$out"     || { echo "FAIL: abstain count wrong"; FAILED=1; }
grep -q "planner-a" "$out"     || { echo "FAIL: row missing"; FAILED=1; }

# Exit code should be 0 on pass
bash "$SCRIPT" --round 1 --type plan --task t \
  --input "$ROOT/tests/fixtures/votes/round-pass" \
  --output "$TMP/pass2.md"
[[ $? -eq 0 ]] || { echo "FAIL: expected exit 0 on pass"; FAILED=1; }

# --- Case 2: failing round (4 approve) -----------------------------------
bash "$SCRIPT" \
  --round 2 \
  --type plan \
  --task "test enemy ai" \
  --input "$ROOT/tests/fixtures/votes/round-fail" \
  --output "$TMP/fail.md" || fail_exit=$?

grep -q "Result:.*FAIL" "$TMP/fail.md" || { echo "FAIL: fail round did not produce FAIL"; FAILED=1; }
grep -q "4 approve" "$TMP/fail.md"     || { echo "FAIL: fail approve count"; FAILED=1; }
[[ "${fail_exit:-0}" -eq 1 ]]          || { echo "FAIL: expected exit 1 on fail, got ${fail_exit:-0}"; FAILED=1; }

# --- Case 3: bad input directory ------------------------------------------
if bash "$SCRIPT" --round 1 --type plan --task t \
    --input "$TMP/does-not-exist" --output "$TMP/err.md" 2>/dev/null; then
  echo "FAIL: expected non-zero exit on missing input"
  FAILED=1
fi

if [[ $FAILED -eq 0 ]]; then
  echo "tally-votes.test.sh: PASS"
else
  echo "tally-votes.test.sh: FAIL"
  exit 1
fi
```

Make executable:
```bash
chmod +x /d/orchestration-unity/tests/scripts/tally-votes.test.sh
```

- [ ] **Step 8.3: Run the test, confirm it fails**

```bash
cd /d/orchestration-unity
bash tests/scripts/tally-votes.test.sh; echo "exit=$?"
```
Expected: failure (script missing), non-zero exit.

- [ ] **Step 8.4: Implement `tally-votes.sh`**

File `skills/unity-orchestration/scripts/tally-votes.sh`:

```bash
#!/usr/bin/env bash
# Tallies votes from a directory of per-agent JSON files and writes a
# markdown report. Exits 0 on pass (≥5 approvals / 9), 1 on fail, 2 on
# usage / input errors.
#
# Usage:
#   tally-votes.sh --round N --type plan|accept --task "<task>" \
#                  --input <dir> --output <file>
set -euo pipefail

round=""; type=""; task=""; input=""; output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --round)  round="$2";  shift 2 ;;
    --type)   type="$2";   shift 2 ;;
    --task)   task="$2";   shift 2 ;;
    --input)  input="$2";  shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

for req in round type task input output; do
  if [[ -z "${!req}" ]]; then
    echo "missing required: --$req" >&2
    exit 2
  fi
done

if [[ ! -d "$input" ]]; then
  echo "error: input dir not found: $input" >&2
  exit 2
fi

# Use python for JSON parsing (jq may be unavailable on Windows git-bash).
python3 - "$input" "$output" "$round" "$type" "$task" <<'PY'
import json, os, sys
from datetime import datetime, timezone

input_dir = sys.argv[1]
output    = sys.argv[2]
round_n   = sys.argv[3]
vtype     = sys.argv[4]
task      = sys.argv[5]

entries = []
for fname in sorted(os.listdir(input_dir)):
    if not fname.endswith('.json'):
        continue
    agent = fname[:-5]
    path  = os.path.join(input_dir, fname)
    try:
        d = json.load(open(path, encoding='utf-8'))
    except Exception as e:
        sys.stderr.write(f"bad json in {fname}: {e}\n")
        sys.exit(2)
    for k in ('vote', 'reason', 'blocking_issues', 'suggestions'):
        if k not in d:
            sys.stderr.write(f"{fname} missing key: {k}\n")
            sys.exit(2)
    if d['vote'] not in ('approve', 'reject', 'abstain'):
        sys.stderr.write(f"{fname} invalid vote: {d['vote']}\n")
        sys.exit(2)
    entries.append((agent, d))

if len(entries) != 9:
    sys.stderr.write(f"expected 9 votes, got {len(entries)}\n")
    sys.exit(2)

approve = sum(1 for _, d in entries if d['vote'] == 'approve')
reject  = sum(1 for _, d in entries if d['vote'] == 'reject')
abstain = sum(1 for _, d in entries if d['vote'] == 'abstain')
result  = "PASS" if approve >= 5 else "FAIL"
date    = datetime.now(timezone.utc).strftime("%Y-%m-%d")

header = f"# {vtype.capitalize()} Vote — Round {round_n}\n\n"
header += f"- **Task:** {task}\n"
header += f"- **Date:** {date}\n"
header += f"- **Result:** {result} ({approve} approve / {reject} reject / {abstain} abstain)\n\n"

table = "| Agent | Vote | Reason |\n|-------|------|--------|\n"
for agent, d in entries:
    reason = d['reason'].replace('|', '\\|')
    table += f"| {agent} | {d['vote']} | {reason} |\n"
table += "\n"

issues = []
for _, d in entries:
    issues.extend(d.get('blocking_issues', []))
suggestions = []
for _, d in entries:
    suggestions.extend(d.get('suggestions', []))

body = ""
if issues:
    body += "## Blocking issues\n" + "".join(f"- {i}\n" for i in issues) + "\n"
if suggestions:
    body += "## Suggestions\n"   + "".join(f"- {s}\n" for s in suggestions) + "\n"

os.makedirs(os.path.dirname(output) or '.', exist_ok=True)
with open(output, 'w', encoding='utf-8') as f:
    f.write(header + table + body)

sys.exit(0 if result == "PASS" else 1)
PY
```

Make executable:
```bash
chmod +x /d/orchestration-unity/skills/unity-orchestration/scripts/tally-votes.sh
```

- [ ] **Step 8.5: Run the test, verify it passes**

```bash
cd /d/orchestration-unity
bash tests/scripts/tally-votes.test.sh
```
Expected: `tally-votes.test.sh: PASS`.

- [ ] **Step 8.6: Commit**

```bash
git update-index --chmod=+x skills/unity-orchestration/scripts/tally-votes.sh 2>/dev/null || true
git update-index --chmod=+x tests/scripts/tally-votes.test.sh 2>/dev/null || true
git add skills/unity-orchestration/scripts/tally-votes.sh \
        tests/scripts/tally-votes.test.sh \
        tests/fixtures/votes/
git commit -m "feat: add tally-votes.sh with test fixtures"
```

---

## Task 9: `update-docs-index.py` + test

Walks a `docs/` tree, parses frontmatter from every `.md`, and writes
`docs/_meta/index.json` with tree, by_tag, by_owner, dangling_references,
and orphans.

**Files:**
- Create: `skills/unity-orchestration/scripts/update-docs-index.py`
- Create: `tests/scripts/update-docs-index.test.sh`

- [ ] **Step 9.1: Write the failing test**

File `tests/scripts/update-docs-index.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/update-docs-index.py
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$ROOT/skills/unity-orchestration/scripts/update-docs-index.py"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DOCS="$TMP/docs"
mkdir -p "$DOCS/_meta" "$DOCS/game/systems" "$DOCS/tech/modules"

# Seed minimal index.json so the script's idempotent update path is exercised
cat > "$DOCS/_meta/index.json" <<'EOF'
{"version":1,"generated_at":null,"generator":"scripts/update-docs-index.py","project":{"name":"","engine":"","genre":""},"tree":{},"by_tag":{},"by_owner":{},"dangling_references":[],"orphans":[]}
EOF

cat > "$DOCS/README.md" <<'EOF'
---
id: root
title: Project Documentation
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index]
---
# root
EOF

cat > "$DOCS/game/README.md" <<'EOF'
---
id: game
title: Game
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index]
---
# game
EOF

cat > "$DOCS/game/systems/combat.md" <<'EOF'
---
id: game.systems.combat
title: Combat
owner: planner
status: stable
updated: 2026-04-11
version: 1
depends_on: [game.overview, tech.modules.input]
tags: [combat]
---
# combat
EOF

cat > "$DOCS/tech/README.md" <<'EOF'
---
id: tech
title: Tech
owner: recorder
status: stable
updated: 2026-04-11
version: 1
tags: [index]
---
# tech
EOF

cat > "$DOCS/tech/modules/input.md" <<'EOF'
---
id: tech.modules.input
title: Input
owner: developer
status: stable
updated: 2026-04-11
version: 1
depends_on: []
tags: []
---
# input
EOF

python3 "$SCRIPT" "$DOCS"

FAILED=0

python3 - "$DOCS/_meta/index.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))

def fail(msg):
    print("FAIL:", msg)
    sys.exit(1)

# tree has entries we expect
if 'game' not in d['tree']:
    fail("tree missing 'game'")
if 'systems' not in d['tree']['game']:
    fail("tree missing 'game.systems'")
if 'combat' not in d['tree']['game']['systems']:
    fail("combat not in tree")

combat = d['tree']['game']['systems']['combat']
if combat['id']    != 'game.systems.combat':       fail("combat id wrong")
if combat['owner'] != 'planner':                   fail("combat owner wrong")
if 'combat' not in combat['tags']:                 fail("combat tags wrong")

# depends_on preserved
if combat['depends_on'] != ['game.overview', 'tech.modules.input']:
    fail(f"depends_on wrong: {combat['depends_on']}")

# referenced_by populated on tech.modules.input from the combat dependency
inp = d['tree']['tech']['modules']['input']
if 'game.systems.combat' not in inp['referenced_by']:
    fail("referenced_by back-link missing on tech.modules.input")

# by_tag populated
if 'combat' not in d['by_tag'] or 'game.systems.combat' not in d['by_tag']['combat']:
    fail("by_tag missing combat entry")

# by_owner populated
if 'planner' not in d['by_owner']:
    fail("by_owner missing planner")

# dangling: game.overview doesn't exist
if 'game.overview' not in d['dangling_references']:
    fail("dangling_references should contain game.overview")

print("PASS")
PY
status=$?
if [[ $status -ne 0 ]]; then FAILED=1; fi

if [[ $FAILED -eq 0 ]]; then
  echo "update-docs-index.test.sh: PASS"
else
  echo "update-docs-index.test.sh: FAIL"
  exit 1
fi
```

Make executable:
```bash
chmod +x /d/orchestration-unity/tests/scripts/update-docs-index.test.sh
```

- [ ] **Step 9.2: Run the test, confirm it fails**

```bash
cd /d/orchestration-unity
bash tests/scripts/update-docs-index.test.sh; echo "exit=$?"
```
Expected: non-zero (script missing).

- [ ] **Step 9.3: Implement the script**

File `skills/unity-orchestration/scripts/update-docs-index.py`:

```python
#!/usr/bin/env python3
"""Walk a docs/ tree, parse .md frontmatter, and update _meta/index.json.

Usage: update-docs-index.py <docs-dir>

Reads frontmatter from every .md file recursively. Builds a nested `tree`
keyed by path-ID components, plus `by_tag`, `by_owner`, `dangling_references`,
and `orphans` aggregates. Populates `referenced_by` back-links from each
doc's `depends_on`.

Intentionally a tiny YAML parser: we only support flat key: value pairs
and simple inline lists (`[a, b, c]`) for `depends_on` and `tags`. No
anchors, no multi-line, no nested maps. This keeps the script dependency-
free on stock Python.
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone


REQUIRED_FIELDS = ("id", "title", "owner", "status", "updated", "version")


def parse_frontmatter(text: str) -> dict | None:
    """Return the frontmatter dict or None if the file has none."""
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    block = text[3:end].strip("\n")
    data: dict = {}
    for raw in block.splitlines():
        line = raw.rstrip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][\w-]*)\s*:\s*(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        if val == "":
            data[key] = ""
            continue
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            if not inner:
                data[key] = []
            else:
                items = [x.strip().strip("'\"") for x in inner.split(",")]
                data[key] = [x for x in items if x]
            continue
        if val in ("true", "false"):
            data[key] = val == "true"
            continue
        if re.match(r"^-?\d+$", val):
            data[key] = int(val)
            continue
        data[key] = val.strip("'\"")
    return data


def validate(fm: dict, rel_path: str) -> list[str]:
    missing = [f for f in REQUIRED_FIELDS if f not in fm]
    if missing:
        return [f"{rel_path}: missing frontmatter fields: {', '.join(missing)}"]
    return []


def set_in_tree(tree: dict, parts: list[str], value: dict) -> None:
    node = tree
    for p in parts[:-1]:
        node = node.setdefault(p, {})
    node[parts[-1]] = value


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: update-docs-index.py <docs-dir>", file=sys.stderr)
        return 2

    docs_dir = os.path.abspath(sys.argv[1])
    if not os.path.isdir(docs_dir):
        print(f"error: not a directory: {docs_dir}", file=sys.stderr)
        return 2

    index_path = os.path.join(docs_dir, "_meta", "index.json")
    prior: dict = {}
    if os.path.isfile(index_path):
        try:
            prior = json.load(open(index_path, encoding="utf-8"))
        except Exception:
            prior = {}

    tree: dict = {}
    by_tag: dict[str, list[str]] = {}
    by_owner: dict[str, list[str]] = {}
    all_ids: set[str] = set()
    dep_map: dict[str, list[str]] = {}
    errors: list[str] = []

    for root, _, files in os.walk(docs_dir):
        for name in files:
            if not name.endswith(".md"):
                continue
            full = os.path.join(root, name)
            rel = os.path.relpath(full, docs_dir).replace("\\", "/")
            try:
                text = open(full, encoding="utf-8").read()
            except Exception as e:
                errors.append(f"{rel}: read error: {e}")
                continue
            fm = parse_frontmatter(text)
            if fm is None:
                # skip files with no frontmatter (e.g., README stubs outside
                # the spec), but warn
                errors.append(f"{rel}: no frontmatter")
                continue
            errors.extend(validate(fm, rel))
            if "id" not in fm:
                continue

            entry = {
                "id": fm["id"],
                "title": fm.get("title", ""),
                "owner": fm.get("owner", ""),
                "status": fm.get("status", ""),
                "updated": fm.get("updated", ""),
                "tags": fm.get("tags", []) or [],
                "depends_on": fm.get("depends_on", []) or [],
                "referenced_by": [],
            }
            all_ids.add(fm["id"])
            dep_map[fm["id"]] = entry["depends_on"]
            parts = fm["id"].split(".")
            set_in_tree(tree, parts, entry)

            for t in entry["tags"]:
                by_tag.setdefault(t, []).append(fm["id"])
            if entry["owner"]:
                by_owner.setdefault(entry["owner"], []).append(fm["id"])

    # Populate referenced_by (back-links) and detect danglers / orphans
    dangling: list[str] = []
    referenced: set[str] = set()
    for src_id, deps in dep_map.items():
        for dep in deps:
            if dep in all_ids:
                _set_ref(tree, dep, src_id)
                referenced.add(dep)
            else:
                dangling.append(dep)
    orphans = sorted(all_ids - referenced - {"root"})

    out = {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "generator": "scripts/update-docs-index.py",
        "project": prior.get("project", {"name": "", "engine": "", "genre": ""}),
        "tree": tree,
        "by_tag": {k: sorted(v) for k, v in sorted(by_tag.items())},
        "by_owner": {k: sorted(v) for k, v in sorted(by_owner.items())},
        "dangling_references": sorted(set(dangling)),
        "orphans": orphans,
    }

    os.makedirs(os.path.dirname(index_path), exist_ok=True)
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")

    for e in errors:
        print(f"warn: {e}", file=sys.stderr)
    return 0


def _set_ref(tree: dict, target_id: str, src_id: str) -> None:
    parts = target_id.split(".")
    node = tree
    for p in parts:
        if p not in node:
            return
        node = node[p]
    if isinstance(node, dict) and "referenced_by" in node:
        if src_id not in node["referenced_by"]:
            node["referenced_by"].append(src_id)


if __name__ == "__main__":
    sys.exit(main())
```

Make executable:
```bash
chmod +x /d/orchestration-unity/skills/unity-orchestration/scripts/update-docs-index.py
```

- [ ] **Step 9.4: Run the test, verify it passes**

```bash
cd /d/orchestration-unity
bash tests/scripts/update-docs-index.test.sh
```
Expected: `update-docs-index.test.sh: PASS`.

- [ ] **Step 9.5: Regenerate the seed template's `index.json`**

Run the script against the packaged docs-tree template so the seed index is
consistent with the README frontmatter we wrote in Task 6:

```bash
cd /d/orchestration-unity
python3 skills/unity-orchestration/scripts/update-docs-index.py \
  skills/unity-orchestration/templates/docs-tree
```

This updates `templates/docs-tree/_meta/index.json` in place. No warnings
are expected; any `warn:` output indicates frontmatter issues to fix.

- [ ] **Step 9.6: Commit**

```bash
git update-index --chmod=+x skills/unity-orchestration/scripts/update-docs-index.py 2>/dev/null || true
git update-index --chmod=+x tests/scripts/update-docs-index.test.sh 2>/dev/null || true
git add skills/unity-orchestration/scripts/update-docs-index.py \
        tests/scripts/update-docs-index.test.sh \
        skills/unity-orchestration/templates/docs-tree/_meta/index.json
git commit -m "feat: add update-docs-index.py with test and regenerate seed index"
```

---

## Task 10: Plugin-level docs

**Files:**
- Create: `docs/getting-started.md`
- Create: `docs/architecture.md`
- Create: `docs/troubleshooting.md`

- [ ] **Step 10.1: Write `docs/getting-started.md`**

```markdown
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
```

- [ ] **Step 10.2: Write `docs/architecture.md`**

```markdown
---
id: plugin-docs.architecture
title: Architecture Overview
owner: developer
status: stable
updated: 2026-04-11
version: 1
tags: [architecture]
---

# Architecture Overview

This document is a short introduction; the full design lives in
`docs/superpowers/specs/2026-04-11-unity-orchestration-design.md`.

## Components

- **Skill** (`skills/unity-orchestration/SKILL.md`) — entry point Claude
  Code loads when `/unity-orchestration` is invoked.
- **Reference docs** — `workflow.md`, `voting.md`,
  `consultation-table.md`, `docs-tree-spec.md` in the skill directory.
- **Role prompts** — five files in `skills/unity-orchestration/agents/`,
  injected when spawning agents.
- **Templates** — proposal, vote, ADR, frontmatter, and the seed
  docs-tree used by `init-workspace.sh`.
- **Scripts** — `init-workspace.sh`, `tally-votes.sh`, and
  `update-docs-index.py`.
- **Slash command** — `commands/unity-orchestration.md` wraps the skill.

## Runtime model

- Uses Claude Code **Agent Teams** (`TeamCreate`/`SendMessage`) for nine
  concurrently-living agents.
- Single Unity project workspace (no worktrees — Unity locks files).
- `unity-mcp` is a single shared dependency; the team lead serializes
  access with an explicit lock protocol.

## Documentation output

The recorder agents produce an AI-readable `docs/` tree in the user's
Unity project. Format is documented in `docs-tree-spec.md` and is
engine-independent outside of `docs/tech/`.

## Testing layers

- **L1 — structure check** (`tests/structure-check.sh`)
- **L2 — script unit tests** (`tests/scripts/*.test.sh`)
- **L3 — dry-run scenarios** (`tests/scenarios/README.md`, manual in v1)
```

- [ ] **Step 10.3: Write `docs/troubleshooting.md`**

```markdown
---
id: plugin-docs.troubleshooting
title: Troubleshooting
owner: developer
status: stable
updated: 2026-04-11
version: 1
tags: [troubleshooting]
---

# Troubleshooting

## `/unity-orchestration` says "Unknown skill"

Claude Code hasn't loaded this plugin. Check:
- `.claude-plugin/plugin.json` parses (run
  `python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"`).
- The plugin directory is discoverable by Claude Code (consult Claude
  Code's plugin loader docs).
- You restarted Claude Code after installing.

## Unity MCP is unreachable

Symptoms: developer/designer agents report `mcp_lock acquire` timing out
or HTTP errors when calling `unity-mcp` tools.

Fixes:
1. Make sure Unity editor is running.
2. `curl http://localhost:8090/health` — if this fails, the `unity-mcp`
   server is down; toggle the editor window or reinstall.
3. Check for port conflicts — `unity-mcp` scans 8090–8100.
4. If the editor is in the middle of a Domain Reload, wait 10s and retry.

## Plan vote fails three rounds in a row

The team lead escalates to the user and writes an ADR. Read
`docs/decisions/<latest>.md` for the forced decision and comment on the
team lead's escalation message if you want to override it.

## Accept vote fails twice

The recorder archive might be insufficient or the cross-review exposed
real defects. Read `.orchestration/sessions/<id>/votes/accept-round-*.md`
for details. Options:
- Let the team re-enter Phase 2 one more time.
- Terminate the session and start a smaller task.

## `structure-check.sh` complains about frontmatter

Run the check on the specific file it names; fix missing fields per
`skills/unity-orchestration/docs-tree-spec.md`. Re-run until it passes.

## Recorder says `_meta/index.json` is stale

Run `python3 skills/unity-orchestration/scripts/update-docs-index.py
<docs-dir>` and commit the result.

## Scripts fail with "permission denied" on Windows

Make sure the executable bit is tracked in git:
```
git update-index --chmod=+x <script-path>
```
Rerun via `bash <script-path>` explicitly if the shim still refuses.

## Session is stuck and I want out

Close Claude Code. The session state is on disk at
`.orchestration/sessions/<id>/state.json`; you can resume later (manual in
v1) or delete the directory to start fresh.
```

- [ ] **Step 10.4: Commit**

```bash
cd /d/orchestration-unity
git add docs/getting-started.md docs/architecture.md docs/troubleshooting.md
git commit -m "docs: add getting-started, architecture, and troubleshooting"
```

---

## Task 11: Expanded structure-check + scenario dry-run checklist

Now that every artifact exists, extend `tests/structure-check.sh` to validate
them, and add a manual scenario checklist.

**Files:**
- Modify: `tests/structure-check.sh`
- Create: `tests/scenarios/README.md`

- [ ] **Step 11.1: Replace `tests/structure-check.sh` with the extended version**

File content (overwrites the minimal version from Task 2):

```bash
#!/usr/bin/env bash
# tests/structure-check.sh
# Validates plugin structure. Exits 0 on success, 1 on failure.
# Usage: ./tests/structure-check.sh [plugin-root]
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ERRORS=0

err() { echo "FAIL: $1" >&2; ERRORS=$((ERRORS + 1)); }
ok()  { echo "OK:   $1"; }

check_file() {
  local rel="$1"
  if [[ -f "$ROOT/$rel" ]]; then
    ok "$rel"
  else
    err "$rel missing"
  fi
}

check_frontmatter() {
  local rel="$1"
  local path="$ROOT/$rel"
  if [[ ! -f "$path" ]]; then
    err "$rel missing"
    return
  fi
  if ! head -1 "$path" | grep -q '^---$'; then
    err "$rel: no frontmatter start"
    return
  fi
  local fm; fm="$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$path")"
  for k in id title owner status updated version; do
    if ! printf '%s\n' "$fm" | grep -q "^${k}:"; then
      err "$rel: missing frontmatter field '$k'"
      return
    fi
  done
  ok "$rel"
}

# --- plugin.json --------------------------------------------------------
if [[ ! -f "$ROOT/.claude-plugin/plugin.json" ]]; then
  err ".claude-plugin/plugin.json missing"
else
  if python3 -c "
import json, sys
d = json.load(open('$ROOT/.claude-plugin/plugin.json'))
for k in ('name','description','version'):
    if k not in d: sys.exit('missing key: ' + k)
if d['name'] != 'unity-orchestration':
    sys.exit('name must be unity-orchestration, got: ' + d['name'])
" 2>err.tmp; then
    ok ".claude-plugin/plugin.json"
  else
    err ".claude-plugin/plugin.json: $(cat err.tmp)"
    rm -f err.tmp
  fi
fi

# --- root files ---------------------------------------------------------
for f in README.md LICENSE CHANGELOG.md .gitignore; do
  check_file "$f"
done

# --- SKILL.md (has name + description in frontmatter, not docs-tree schema) -
if [[ -f "$ROOT/skills/unity-orchestration/SKILL.md" ]]; then
  fm="$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' \
    "$ROOT/skills/unity-orchestration/SKILL.md")"
  for k in name description; do
    if ! printf '%s\n' "$fm" | grep -q "^${k}:"; then
      err "skills/unity-orchestration/SKILL.md: missing '$k' in frontmatter"
    fi
  done
  ok "skills/unity-orchestration/SKILL.md"
else
  err "skills/unity-orchestration/SKILL.md missing"
fi

# --- Reference docs (docs-tree frontmatter) ----------------------------
for f in \
  skills/unity-orchestration/workflow.md \
  skills/unity-orchestration/voting.md \
  skills/unity-orchestration/consultation-table.md \
  skills/unity-orchestration/docs-tree-spec.md \
  skills/unity-orchestration/agents/team-lead.md \
  skills/unity-orchestration/agents/planner.md \
  skills/unity-orchestration/agents/designer.md \
  skills/unity-orchestration/agents/developer.md \
  skills/unity-orchestration/agents/recorder.md \
  skills/unity-orchestration/templates/docs-tree/README.md \
  skills/unity-orchestration/templates/docs-tree/_meta/glossary.md \
  skills/unity-orchestration/templates/docs-tree/_meta/conventions.md \
  skills/unity-orchestration/templates/docs-tree/game/README.md \
  skills/unity-orchestration/templates/docs-tree/design/README.md \
  skills/unity-orchestration/templates/docs-tree/tech/README.md \
  docs/getting-started.md \
  docs/architecture.md \
  docs/troubleshooting.md; do
  check_frontmatter "$f"
done

# --- Non-frontmatter files that must exist ------------------------------
for f in \
  commands/unity-orchestration.md \
  agents/unity-orchestrator.md \
  skills/unity-orchestration/templates/task-table.template.md \
  skills/unity-orchestration/templates/vote-message.template.json \
  skills/unity-orchestration/templates/adr.template.md \
  skills/unity-orchestration/templates/doc-frontmatter.template.yaml \
  skills/unity-orchestration/templates/docs-tree/_meta/index.json \
  skills/unity-orchestration/templates/docs-tree/decisions/.gitkeep \
  skills/unity-orchestration/templates/docs-tree/tasks/.gitkeep \
  skills/unity-orchestration/templates/docs-tree/CHANGELOG.md \
  skills/unity-orchestration/scripts/init-workspace.sh \
  skills/unity-orchestration/scripts/tally-votes.sh \
  skills/unity-orchestration/scripts/update-docs-index.py \
  tests/scripts/init-workspace.test.sh \
  tests/scripts/tally-votes.test.sh \
  tests/scripts/update-docs-index.test.sh; do
  check_file "$f"
done

# --- JSON validity -------------------------------------------------------
for f in \
  skills/unity-orchestration/templates/vote-message.template.json \
  skills/unity-orchestration/templates/docs-tree/_meta/index.json; do
  if [[ -f "$ROOT/$f" ]]; then
    if python3 -c "import json; json.load(open('$ROOT/$f'))" 2>/dev/null; then
      ok "$f (json)"
    else
      err "$f: invalid JSON"
    fi
  fi
done

# --- Script executable bits --------------------------------------------
for s in \
  skills/unity-orchestration/scripts/init-workspace.sh \
  skills/unity-orchestration/scripts/tally-votes.sh \
  skills/unity-orchestration/scripts/update-docs-index.py \
  tests/structure-check.sh \
  tests/scripts/init-workspace.test.sh \
  tests/scripts/tally-votes.test.sh \
  tests/scripts/update-docs-index.test.sh; do
  if [[ -f "$ROOT/$s" && ! -x "$ROOT/$s" ]]; then
    err "$s: not executable (run: chmod +x $s)"
  fi
done

# --- Report -------------------------------------------------------------
if [[ $ERRORS -gt 0 ]]; then
  echo
  echo "structure-check: $ERRORS error(s)" >&2
  exit 1
fi
echo
echo "structure-check: passed"
```

- [ ] **Step 11.2: Write `tests/scenarios/README.md`**

```bash
mkdir -p /d/orchestration-unity/tests/scenarios
```

File:

```markdown
# Dry-run scenarios (manual checklist, v1)

Automated scenario tests are out of scope for v1. These manual scenarios
are the minimum regression pass before each release.

Run every scenario from a clean tmp dir. Copy the plugin into the tmp dir
so the scripts' `PLUGIN_ROOT` resolution works.

## Scenario 1 — init-workspace on empty project

1. `mkdir /tmp/scn-init && cd /tmp/scn-init`
2. Run `bash <plugin>/skills/unity-orchestration/scripts/init-workspace.sh . demo`
3. Verify:
   - `.orchestration/sessions/<timestamp>-demo/state.json` exists and is
     valid JSON with `phase=boot`.
   - `docs/` mirrors the seed template.

## Scenario 2 — tally-votes pass & fail

Use `tests/fixtures/votes/round-pass/` and `round-fail/`:

```
bash skills/unity-orchestration/scripts/tally-votes.sh \
  --round 1 --type plan --task demo \
  --input tests/fixtures/votes/round-pass \
  --output /tmp/pass.md
echo $?   # 0
bash skills/unity-orchestration/scripts/tally-votes.sh \
  --round 1 --type plan --task demo \
  --input tests/fixtures/votes/round-fail \
  --output /tmp/fail.md
echo $?   # 1
```

Inspect the output files for the required sections.

## Scenario 3 — update-docs-index on the seed template

```
python3 skills/unity-orchestration/scripts/update-docs-index.py \
  skills/unity-orchestration/templates/docs-tree
cat skills/unity-orchestration/templates/docs-tree/_meta/index.json | head -30
```
No `warn:` output expected. `tree` should contain entries for root, game,
design, tech.

## Scenario 4 — structure-check full pass

```
bash tests/structure-check.sh
echo $?   # 0
```

## Scenario 5 — structure-check on a tampered plugin

1. Copy plugin to `/tmp/scn5`.
2. Delete `skills/unity-orchestration/agents/designer.md`.
3. `bash tests/structure-check.sh`
4. Expect: FAIL with message about designer.md missing/no frontmatter.
   Exit 1.

## Regression signoff

Maintainer runs all five scenarios before tagging a release. Record the
result in the release PR description.
```

- [ ] **Step 11.3: Run the full structure check**

```bash
cd /d/orchestration-unity
bash tests/structure-check.sh
```
Expected: many `OK:` lines, ending in `structure-check: passed`.

If anything fails, fix the named file and re-run. Do not proceed to the
commit step until this is clean.

- [ ] **Step 11.4: Run all script unit tests**

```bash
cd /d/orchestration-unity
for t in tests/scripts/*.test.sh; do
  echo "--- $t ---"
  bash "$t"
done
```
Expected: three `PASS` lines.

- [ ] **Step 11.5: Commit**

```bash
git add tests/structure-check.sh tests/scenarios/README.md
git commit -m "test: extend structure-check and add dry-run scenario checklist"
```

---

## Task 12: Final verification and v0.1.0 tag

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json` (already at 0.1.0 — only verify)

- [ ] **Step 12.1: Update `CHANGELOG.md` for v0.1.0**

Replace the `## [Unreleased]` section with:

```markdown
## [Unreleased]

## [0.1.0] — 2026-04-11

### Added
- Plugin scaffold (`.claude-plugin/plugin.json`, LICENSE, README, CHANGELOG).
- `unity-orchestration` skill entry point (`SKILL.md`) and four reference
  docs (`workflow.md`, `voting.md`, `consultation-table.md`, `docs-tree-spec.md`).
- Five role prompts (`team-lead`, `planner`, `designer`, `developer`, `recorder`).
- Slash command `/unity-orchestration` and bootstrap agent
  `unity-orchestrator`.
- Templates: proposal, vote, ADR, frontmatter, and a seed docs-tree.
- Scripts: `init-workspace.sh`, `tally-votes.sh`, `update-docs-index.py`.
- Plugin-level docs: getting-started, architecture, troubleshooting.
- Test suite: `tests/structure-check.sh` + three script unit tests + manual
  scenarios.
- Full design spec and implementation plan under `docs/superpowers/`.

### Known limitations
- No automatic session resume (manual in v1).
- No multi-session parallelism.
- Unity-only (no Godot/Unreal support).
- Scenario tests are a manual checklist, not CI-automated.
```

- [ ] **Step 12.2: Run every test one more time**

```bash
cd /d/orchestration-unity
bash tests/structure-check.sh
for t in tests/scripts/*.test.sh; do bash "$t"; done
```
Expected: structure-check passes, all three unit tests print `PASS`.

- [ ] **Step 12.3: Verify git working tree is clean**

```bash
cd /d/orchestration-unity
git status
```
Expected: `nothing to commit, working tree clean` (after the Step 12.1
commit, if you have already done it). If Step 12.1 is still pending:

```bash
git add CHANGELOG.md
git commit -m "chore: cut v0.1.0"
```

- [ ] **Step 12.4: Tag v0.1.0**

```bash
git tag -a v0.1.0 -m "unity-orchestration v0.1.0"
git log --oneline -n 20
git tag -l
```
Expected: `v0.1.0` appears in the tag list; log shows all task commits.

- [ ] **Step 12.5: (optional) push to GitHub**

Only if the user has created the remote and installed `gh` or set up HTTPS
credentials. If `gh` is available:

```bash
gh repo create yeodonghyeon1/orchestration-unity --private --source=. --remote=origin --push
git push origin v0.1.0
```

If `gh` is not installed, the user creates the empty repo in the GitHub
web UI, then:

```bash
git remote add origin https://github.com/yeodonghyeon1/orchestration-unity.git
git push -u origin main
git push origin v0.1.0
```

Skip this step if the user has not asked to push.

---

## Self-Review

**Spec coverage:**

- §1 Architecture & roster → Tasks 3 (SKILL.md, workflow.md), 4 (agent prompts)
- §2 Repo structure → Task 1 (scaffold), 3–10 (content)
- §3 Workflow phases → Task 3 (workflow.md content sourced from spec §3)
- §4 Docs tree → Task 6 (docs-tree seed), 9 (index script), 3 (docs-tree-spec.md)
- §5 Voting → Task 3 (voting.md), 8 (tally-votes.sh)
- §6 Failure modes → Task 10 (troubleshooting.md)
- §7 Observability → Task 7 (init-workspace scaffolds .orchestration/), agent prompts reference the session dir
- §8 Testing strategy → Task 2 + 11 (structure-check), 7/8/9 (unit tests), 11 (scenarios)
- §9 Release plan → Task 12 (v0.1.0 tag)
- §10 Scope boundary → all tasks stay within v1 in-scope list
- §11 Open questions → deferred (no task; they are not v1 items)
- §12 Glossary → absorbed into SKILL.md, voting.md, consultation-table.md, docs-tree-spec.md

**Placeholder scan:** Tasks 3.3, 3.4, 3.5, 3.6 instruct "copy §X of the spec
as the body" for the reference docs. This is acceptable because the spec
file is committed and referenced; the engineer has the exact source. All
other tasks contain complete code/content inline.

**Type consistency:** 
- Plugin name, skill name, slash command name are all `unity-orchestration` 
  (verified in Tasks 1.1, 3.2, 5.1).
- Repo name is `orchestration-unity` (verified in Task 1.3).
- Script names consistent across spec and plan: `init-workspace.sh`,
  `tally-votes.sh`, `update-docs-index.py` (the last changed from `.sh` 
  in the design spec — called out in the Tech Stack block).
- Agent names in spawn protocol (`team-lead`, `planner-a/b`, `designer-a/b`,
  `dev-a/b`, `recorder-a/b`) are identical in the team-lead prompt and 
  the SKILL.md bootstrap section.
- Vote JSON keys (`vote`, `reason`, `blocking_issues`, `suggestions`) are
  identical between `voting.md`, `vote-message.template.json`, and the
  `tally-votes.sh` parser.
- `state.json` fields (`session_id`, `task_slug`, `phase`, `round`,
  `created_at`, `mcp_lock_holder`, `task_id`) are defined once in 
  `init-workspace.sh` and reused elsewhere.

No inconsistencies found on review.
