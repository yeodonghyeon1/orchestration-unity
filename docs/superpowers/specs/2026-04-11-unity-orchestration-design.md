---
id: specs.2026-04-11-unity-orchestration-design
title: Unity Orchestration Plugin — Design
owner: architect
status: review
updated: 2026-04-11
version: 1
tags: [design, orchestration, unity, agent-teams]
---

# Unity Orchestration Plugin — Design

> Superpowers-compatible Claude Code plugin that runs Unity game development
> as a 9-agent consensus team. Repo: `orchestration-unity`. Skill name:
> `unity-orchestration`. Slash command: `/unity-orchestration`.

## 0. Goals & Non-Goals

**Goals**
- Drive Unity game dev tasks through a 9-agent team that debates, distributes,
  and votes on work.
- Every "big task" produces durable, AI-readable documentation in a general
  (engine-independent) tree format.
- Leverage the existing Superpowers plugin format and `unity-mcp` MCP server
  (upstream at `D:\unity-mcp`, `CoplayDev/unity-mcp`).
- Make peer critique *structural*: each role has a pair (A/B) that must agree
  internally before handing off, and cross-role review is required before any
  task is accepted.
- All orchestration state is inspectable as plain files.

**Non-Goals (v1)**
- Multi-session parallel execution.
- Engines other than Unity.
- Agent long-term memory across sessions.
- Web dashboard / GUI.
- Automated scenario tests against a real Unity editor in CI.

## 1. Architecture & Agent Roster

### 1.1 High-level flow

```
User
  │ /unity-orchestration "<task>"
  ▼
unity-orchestration SKILL
  - scaffolds .orchestration/ + docs/
  - TeamCreate "unity-orch-<timestamp>"
  - spawns 9 agents
  - hands off to team-lead
  ▼
team-lead (hub)
  ├── peer DMs between role pairs (A↔B)
  ├── broadcasts to all 9 for votes
  └── gates access to unity-mcp (lock)
      ▼
Unity Editor + unity-mcp  (designers/developers only)
      ▼
Unity project workspace (single, not worktree-isolated)
 ├── Assets/
 ├── docs/             ← recorder output, general format
 └── .orchestration/   ← runtime artifacts (gitignored)
```

### 1.2 Agent roster (9 total)

| # | Name | Role | Subagent type | Unity MCP access |
|---|------|------|--------------|------------------|
| 1 | `team-lead` | Hub, vote tally, round management, MCP lock | general-purpose | no |
| 2 | `planner-a` | Game design, systems/balancing spec, data assets | general-purpose | no (data assets via dev) |
| 3 | `planner-b` | Planner peer reviewer | general-purpose | no |
| 4 | `designer-a` | Scene / prefab / UI construction | general-purpose | yes |
| 5 | `designer-b` | Designer peer reviewer | general-purpose | yes |
| 6 | `dev-a` | C# implementation, tests | general-purpose | yes |
| 7 | `dev-b` | Developer peer reviewer | general-purpose | yes |
| 8 | `recorder-a` | Docs writer, transcript curator | general-purpose | no |
| 9 | `recorder-b` | Docs quality reviewer ("is this doc a good doc?") | general-purpose | no |

### 1.3 Core design principles

1. **Parallel exploration, serialized writes.** Reads and votes fan out; file
   edits and Unity MCP calls are serialized via the shared TaskList's
   `in_progress` constraint plus a team-lead-managed MCP lock.
2. **Unity MCP is a single gate.** Only designers and developers hold that
   capability, and they announce lock acquire/release to the team lead.
3. **All inter-agent communication goes through `SendMessage`.** Plain-text
   output is for the user only.
4. **Recorder-A is a standing observer.** The team lead forwards every major
   decision so the transcript stays live.
5. **Designers can touch Unity MCP but don't have to.** They may also write
   specs for developers to implement.
6. **Planners can create data assets (e.g., ScriptableObject)** via hand-off
   to developers; they don't call MCP directly.

## 2. Repository Structure (Superpowers-compatible)

```
orchestration-unity/
├── .claude-plugin/
│   ├── plugin.json                 # name: unity-orchestration
│   └── marketplace.json            # optional; for later publishing
├── skills/
│   └── unity-orchestration/
│       ├── SKILL.md                # entry point
│       ├── workflow.md             # full 7-phase workflow reference
│       ├── voting.md               # vote format + tally rules
│       ├── consultation-table.md   # TaskList usage conventions
│       ├── docs-tree-spec.md       # recorder tree format reference
│       ├── agents/
│       │   ├── team-lead.md
│       │   ├── planner.md          # A and B share; B gets reviewer flag
│       │   ├── designer.md
│       │   ├── developer.md
│       │   └── recorder.md
│       ├── templates/
│       │   ├── task-table.template.md
│       │   ├── vote-message.template.json
│       │   ├── adr.template.md
│       │   ├── doc-frontmatter.template.yaml
│       │   └── docs-tree/          # seed docs/ tree copied into user project
│       │       ├── README.md
│       │       ├── _meta/
│       │       │   ├── glossary.md
│       │       │   ├── conventions.md
│       │       │   └── index.json
│       │       ├── game/README.md
│       │       ├── design/README.md
│       │       ├── tech/README.md
│       │       ├── decisions/.gitkeep
│       │       ├── tasks/.gitkeep
│       │       └── CHANGELOG.md
│       └── scripts/
│           ├── init-workspace.sh
│           ├── tally-votes.sh
│           └── update-docs-index.sh
├── commands/
│   └── unity-orchestration.md      # /unity-orchestration wrapper
├── agents/
│   └── unity-orchestrator.md       # optional team-lead bootstrap agent
├── docs/
│   ├── getting-started.md
│   ├── architecture.md
│   ├── troubleshooting.md
│   └── superpowers/
│       └── specs/
│           └── 2026-04-11-unity-orchestration-design.md   # this file
├── tests/
│   ├── structure-check.sh
│   ├── scripts/                    # unit tests for the shell scripts
│   └── scenarios/                  # manual dry-run scripts
├── .gitignore
├── LICENSE                         # MIT
├── README.md
└── CHANGELOG.md
```

**Naming discipline**
- Repo name: `orchestration-unity` (filesystem and GitHub).
- Plugin name, skill name, and slash command: `unity-orchestration` (all three
  identical so no "unknown skill" mismatches).

## 3. Workflow (Task Lifecycle)

One "big task" runs through seven phases. The team lead drives each phase
transition; recorder-A appends to `transcript.md` throughout.

### Phase 0 — Boot
1. User runs `/unity-orchestration "<task>"`.
2. SKILL creates `.orchestration/sessions/<timestamp>-<slug>/`.
3. `scripts/init-workspace.sh` seeds `docs/` from `templates/docs-tree/` if
   missing.
4. `TeamCreate unity-orch-<timestamp>` then spawn team-lead; team-lead spawns
   the other eight.
5. Team lead receives the initial task payload and session path.

### Phase 1 — Exploration (parallel)
- Team lead broadcasts: "explore from your role's perspective and submit a
  proposal".
- Each agent writes `.orchestration/sessions/<id>/proposals/<role>-{a|b}.md`
  containing: perspective summary, candidate sub-tasks, dependencies on other
  roles, risks.
- Proposals use a fixed frontmatter and section layout (see templates).

### Phase 2 — Distribution (team lead)
- Team lead reads all 9 proposals and builds a TaskList draft via `TaskCreate`,
  setting `owner`, `description`, `blockedBy`.
- Conflicts (two roles claiming the same work) are merged; gaps assigned to the
  closest role.
- Snapshot saved to `distribution-round-N.md`; broadcast to all agents.

### Phase 3 — Plan Vote
- Every agent (including team lead) sends a vote via `SendMessage` with this
  JSON body:
  ```json
  {
    "vote": "approve | reject | abstain",
    "reason": "one line",
    "blocking_issues": ["..."],
    "suggestions": ["..."]
  }
  ```
- Team lead runs `scripts/tally-votes.sh` and writes
  `docs/tasks/<id>/votes/plan-round-N.md`.
- **Pass rule:** ≥ 5 approvals out of 9. `abstain` does not count as approval.
- On fail: collect reject reasons, broadcast, return to Phase 2. Max 3 plan
  rounds; on 3rd failure, team lead makes a forced call, records it as an ADR
  in `docs/decisions/`, and escalates to the user.

### Phase 4 — Execution (micro-cycles)
For each sub-task in dependency order:
1. Owner sets `TaskUpdate status=in_progress`.
2. Owner performs work. Before any `unity-mcp` call, owner DMs team-lead
   "`mcp_lock acquire <task-id>`"; releases on completion.
3. Owner requests peer review from their role pair via DM.
4. Peer responds `approve` or `request_changes`. Iterates until the pair
   agrees.
5. Team lead intervenes if a pair ping-pongs more than 5 times (see 5.1).
6. Owner sets `status=completed`; recorder-A appends to transcript.
7. Next task by blockedBy order.

Parallelism rule: exploration, reviews, and votes fan out; file writes and MCP
calls serialize on the `in_progress` constraint and the MCP lock.

### Phase 5 — Accept Vote (cross-role review)
- Team lead broadcasts: "task complete, review other roles' output and cast
  accept votes".
- Each agent must review *outputs from roles outside their own pair*
  (anti-collusion rule): their own pair's work is excluded from their vote
  scope.
- Review scope examples:
  - Developers review planner docs for implementability and designer scenes
    for script wiring.
  - Designers review code for UX impact and planner docs for visual
    feasibility.
  - Planners review code/scene vs. intended game feel.
  - Recorder-B checks that docs are usable as documentation (readability,
    consistency, `index.json` freshness).
  - Recorder-A reviews everyone else's artifacts (since its own docs are
    excluded from its vote).
- **Pass rule:** ≥ 5 accepts out of 9.
- On fail: collect issue list, team lead generates follow-up tasks, return to
  Phase 2. Hard cap: 2 accept re-entries; after that, escalate to user with a
  "the initial design may be wrong" message and offer session termination.

### Phase 6 — Close
- Recorder-A promotes session artifacts to `docs/tasks/<id>/`:
  - `README.md` (one-page summary, with frontmatter)
  - `consultation.md` (cleaned transcript)
  - `votes.md` (all plan + accept rounds)
  - `outcome.md` (files created/modified, with diff links)
- Recorder-A updates affected folder `README.md` files and regenerates
  `_meta/index.json`.
- Appends one line to `docs/CHANGELOG.md`.
- Recorder-B reviews recorder-A's archive; pushes back if insufficient.
- Team lead calls `TeamDelete`; SKILL emits a short summary to the user with a
  link to `docs/tasks/<id>/README.md`.

## 4. Documentation Tree Format (Recorder Spec)

This is the format recorder-A produces and recorder-B audits. It is
engine-independent; Unity-specific vocabulary is confined to `docs/tech/`.

### 4.1 Tree layout

```
docs/
├── README.md                        # root index
├── _meta/
│   ├── glossary.md
│   ├── conventions.md
│   └── index.json                   # machine-readable index
├── game/                            # planner domain
│   ├── README.md
│   ├── overview.md
│   ├── systems/                     # one file per system
│   ├── levels/
│   ├── balancing/
│   └── narrative/
├── design/                          # designer domain
│   ├── README.md
│   ├── art-direction.md
│   ├── scenes/
│   ├── prefabs/
│   └── ui/
├── tech/                            # developer domain (Unity-specific ok here)
│   ├── README.md
│   ├── architecture.md
│   ├── modules/
│   ├── api/
│   └── testing.md
├── decisions/                       # ADRs
│   └── YYYY-MM-DD-<slug>.md
├── tasks/                           # archived task bundles
│   └── YYYY-MM-DD-<task-id>/
└── CHANGELOG.md
```

### 4.2 Required frontmatter (every `.md`)

```yaml
---
id: game.systems.enemy-patrol        # required; see path-ID rules
title: 적 순찰 시스템                 # required
owner: planner                       # required; planner|designer|developer|recorder
status: draft | review | stable | archived
updated: 2026-04-11                  # required; YYYY-MM-DD
version: 1                           # required; bump on major rewrites
depends_on: [game.overview]          # optional
referenced_by: []                    # auto-populated by index script
tags: [combat, enemy, ai]            # optional
task_origin: 2026-04-11-enemy-patrol # optional
---
```

`structure-check.sh` fails on any missing required field.

### 4.3 Path-ID system (1:1 with file path)

```
docs/game/systems/enemy-patrol.md  ->  game.systems.enemy-patrol
docs/tech/modules/input.md         ->  tech.modules.input
docs/decisions/2026-04-11-ecs.md   ->  decisions.2026-04-11-ecs
```

Rules: drop `docs/`, replace `/` with `.`, drop `.md`, keep hyphens. IDs are the
canonical reference form — `depends_on` uses IDs, not paths.

### 4.4 `_meta/index.json` schema

```json
{
  "version": 1,
  "generated_at": "2026-04-11T10:23:00Z",
  "generator": "scripts/update-docs-index.sh",
  "project": { "name": "My Unity Game", "engine": "unity-6000.0.20f1" },
  "tree": {
    "game": {
      "systems": {
        "enemy-patrol": {
          "id": "game.systems.enemy-patrol",
          "title": "적 순찰 시스템",
          "owner": "planner",
          "status": "stable",
          "updated": "2026-04-11",
          "tags": ["combat", "enemy", "ai"],
          "depends_on": ["game.overview"],
          "referenced_by": ["tech.modules.enemy-ai"]
        }
      }
    }
  },
  "by_tag": { "combat": ["game.systems.enemy-patrol"] },
  "by_owner": { "planner": ["game.overview", "game.systems.enemy-patrol"] },
  "dangling_references": [],
  "orphans": []
}
```

`scripts/update-docs-index.sh` regenerates this file by parsing all `.md`
frontmatter. It is recorder-A's responsibility to run it after edits; CI runs
it to detect drift.

### 4.5 Folder README convention

Every subfolder has a `README.md` that functions as an AI-first landing page:
- Frontmatter with `owner: recorder` and `status`.
- A one-line description per file in the folder.
- Local authoring rules specific to the folder (e.g., "one system per file, >
  800 lines must split").
SKILL.md instructs agents to read folder READMEs before diving into individual
files.

### 4.6 ADR format

`docs/decisions/YYYY-MM-DD-<slug>.md` with `id: decisions.YYYY-MM-DD-<slug>`
and sections: Context, Decision, Consequences, Alternatives Considered, Votes.
Once `status=stable`, ADR content is frozen; reversing requires a new ADR that
declares `Supersedes decisions.YYYY-MM-DD-<slug>`.

### 4.7 Task archive format

`docs/tasks/<id>/` contains `README.md` (with frontmatter `id:
tasks.<id>`), `consultation.md`, `votes.md`, `outcome.md`, and optional
`artifacts/`. Only `README.md` carries frontmatter; the other files are
considered internal to the bundle.

### 4.8 Engine independence

`game/`, `design/`, `decisions/`, `tasks/`, `_meta/` are engine-neutral. Unity
vocabulary (Prefab, ScriptableObject, AssetBundle, etc.) is permitted only in
`tech/`. Success criterion: the same tree, minus `tech/` module names, should
drop into a Godot/Unreal project unchanged.

## 5. Voting Mechanism

### 5.1 Two vote moments
- **Plan Vote** — before execution, on the proposed distribution.
- **Accept Vote** — after the big task, on cross-role review of outputs.

Both use the same vote JSON (see Phase 3), and both require ≥ 5 approvals out
of 9. Team lead is a voter, not a neutral facilitator.

### 5.2 Anti-collusion rule
For accept votes, an agent may *not* vote on artifacts produced by its own
role pair. If all relevant artifacts fall inside the agent's pair, the agent
must abstain on that sub-decision — it cannot approve its own pair's work.

### 5.3 Vote storage
- `docs/tasks/<id>/votes/plan-round-N.md` — one file per plan round.
- `docs/tasks/<id>/votes/accept.md` — final accept vote(s).
- Each file contains: per-agent rows (vote, reason, issues, suggestions),
  tally, outcome.

### 5.4 Deadlock handling
- Plan: max 3 rounds → forced call + ADR + user escalation.
- Accept: max 2 re-entries to Phase 2 → user escalation.
- Role-pair ping-pong: team lead intervenes after 5 review bounces, runs a
  mini-vote with team lead + two non-pair agents, records as ADR.

## 6. Failure Modes & Recovery

| Failure | Detected by | Recovery |
|---|---|---|
| Unity MCP unresponsive | dev/designer timeout | escalate to team lead → user DM; pause MCP tasks, continue doc work |
| Agent silent | team lead, last-reply timestamp | ping DM; 2 no-reply → auto-abstain for that round |
| Peer-review ping-pong | team lead | 5-bounce threshold → mini-vote intervention |
| Plan vote fails 3 rounds | team lead | forced call + ADR + escalation |
| Accept vote re-entry cap | team lead | 2 re-entries → user escalation with terminate option |
| Concurrent file edit | should be impossible | if it happens, it's a serialization bug; abort + report |
| Recorder lag | team lead | non-blocking; sync before next round |
| Token budget | team lead self-tracking | warn at 80%, hard stop at 90% after current task completes |
| User interrupt | — | state persisted in `.orchestration/sessions/<id>/state.json`; resume is manual in v1 |

## 7. Observability

Every session produces:

```
.orchestration/sessions/<timestamp>-<slug>/
├── state.json                       # current phase, round, task status
├── proposals/                       # phase-1 outputs
├── distribution-round-*.md          # phase-2 snapshots
├── votes/
│   ├── plan-round-1.md
│   ├── plan-round-2.md
│   └── accept.md
├── transcript.md                    # append-only, recorder-A managed
├── mcp-log.md                       # who called unity-mcp, when, what
└── final-report.md                  # phase-6 output
```

`.orchestration/` is in `.gitignore`. Only curated content (Phase 6 archive)
is promoted to `docs/tasks/<id>/` and committed.

## 8. Testing Strategy

Three layers, because LLM-driven orchestration resists conventional unit
tests:

**Layer 1 — Structure check (`tests/structure-check.sh`)**
- `.claude-plugin/plugin.json` exists and parses.
- All `skills/*/SKILL.md` have required frontmatter fields.
- All `agents/*.md` contain role description + forbidden-actions section.
- All `templates/docs-tree/*.md` have valid frontmatter.
- Scripts are executable.
- Runs in CI on every push.

**Layer 2 — Script unit tests (`tests/scripts/`)**
- `tally-votes.sh`: fixed input → expected output (5 approve / 3 reject / 1
  abstain → pass).
- `update-docs-index.sh`: fixed docs tree → expected `index.json` diff.
- `init-workspace.sh`: empty dir → expected files created.

**Layer 3 — Dry-run scenarios (`tests/scenarios/`)**
- Manual execution only. Mock `unity-mcp` responses + scripted fake task; run
  one cycle; verify phase transitions, vote file format, task archive
  creation.
- Manual regression checklist in v1; automation deferred to v2.

**Explicit non-goals for testing**
- No quality grading of agent outputs (LLM non-determinism).
- No CI end-to-end against a real Unity editor (local manual only).

## 9. Release Plan

- `v0.1.0` — sections 1–4 implemented, dry-run passes.
- `v0.2.0` — session resume automation.
- `v1.0.0` — three successful real-project cycles completed.
- SemVer; Keep-a-Changelog format in `CHANGELOG.md`.

## 10. v1 Scope Boundary (YAGNI)

**In scope (v1)**
- Everything in sections 1–8.
- One slash command (`/unity-orchestration`).
- Nine agent prompts.
- Seed docs-tree template.
- Three shell scripts.
- Plugin-level `docs/` (getting-started, architecture, troubleshooting).

**Out of scope (v1)**
- Agent long-term memory.
- Multi-session parallelism.
- Web dashboard.
- Engines other than Unity.
- Automatic resume.
- Automated scenario tests.

## 11. Open Questions (deferred, not blocking v1)

- Whether recorder-B should be a read-only `Explore` agent type (cheaper) once
  the read-only subagent gains file parity.
- Whether `unity-mcp` lock should become a file-based lease to survive
  team-lead crashes.
- Whether to introduce a "critic" mini-role alongside team-lead for final
  quality gating on very large tasks.

## 12. Glossary

- **Role pair** — two agents sharing a role (A + B) who must reach internal
  agreement before handing work off.
- **Consultation table** — the shared TaskList + transcript/votes files
  representing the team's current state of negotiation.
- **MCP lock** — team-lead-managed mutual exclusion over Unity MCP calls.
- **Path ID** — canonical reference to a doc, derived from its file path.
- **Plan vote** — pre-execution vote on task distribution.
- **Accept vote** — post-execution cross-role review vote.
- **Anti-collusion rule** — an agent cannot vote to accept artifacts produced
  by its own role pair.
