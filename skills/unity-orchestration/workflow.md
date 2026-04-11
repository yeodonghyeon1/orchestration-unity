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

## Overview

A "big task" runs through seven phases: Boot, Exploration, Distribution, Plan
Vote, Execution, Accept Vote, and Close. The team lead drives every phase
transition; recorder-A appends to `transcript.md` throughout. Reads, votes,
and reviews fan out in parallel; file writes and Unity MCP calls are
serialized through the TaskList `in_progress` constraint and the team-lead-
managed MCP lock.

## Phase 0 — Boot

1. User runs `/unity-orchestration "<task>"`.
2. SKILL creates `.orchestration/sessions/<timestamp>-<slug>/`.
3. `scripts/init-workspace.sh` seeds `docs/` from `templates/docs-tree/` if
   missing.
4. `TeamCreate unity-orch-<timestamp>` then spawn team-lead; team-lead spawns
   the other eight.
5. Team lead receives the initial task payload and session path.

## Phase 1 — Exploration (parallel)

- Team lead broadcasts: "explore from your role's perspective and submit a
  proposal".
- Each agent writes `.orchestration/sessions/<id>/proposals/<role>-{a|b}.md`
  containing: perspective summary, candidate sub-tasks, dependencies on other
  roles, risks.
- Proposals use a fixed frontmatter and section layout (see templates).

## Phase 2 — Distribution (team lead)

- Team lead reads all 9 proposals and builds a TaskList draft via `TaskCreate`,
  setting `owner`, `description`, `blockedBy`.
- Conflicts (two roles claiming the same work) are merged; gaps assigned to the
  closest role.
- Snapshot saved to `distribution-round-N.md`; broadcast to all agents.

## Phase 3 — Plan Vote

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

## Phase 4 — Execution (micro-cycles)

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

## Phase 5 — Accept Vote (cross-role review)

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

## Phase 6 — Close

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

## Team lead responsibilities summary

- Spawn the other eight agents in Phase 0 after being spawned by the SKILL.
- Broadcast phase transitions to the full team and inject phase-specific
  prompts (explore, vote, review, etc.).
- Read all 9 proposals in Phase 2 and build the TaskList distribution
  draft via `TaskCreate`, resolving conflicts and gap-filling owners.
- Run `scripts/tally-votes.sh` after each Plan Vote and Accept Vote and
  publish results under `docs/tasks/<id>/votes/`.
- Hold and serialize the Unity MCP lock: grant at most one `mcp_lock acquire`
  at a time, log every cycle to `mcp-log.md`, force release on completion.
- Route DMs between role pairs and watch for ping-pong; intervene with a
  mini-vote after 5 review bounces and record the call as an ADR.
- Enforce deadlock caps: 3 plan rounds, 2 accept re-entries, then escalate
  to the user with a forced call recorded in `docs/decisions/`.
- Vote alongside the other eight agents — team lead is a voter, not a
  neutral facilitator.
- Call `TeamDelete` in Phase 6 and emit the final user-visible summary.

## Recorder responsibilities summary

- **Recorder-A** is a standing observer: appends every major decision and
  message routed through team-lead to `transcript.md` (append-only).
- **Recorder-A** writes proposals in Phase 1, executes assigned tasks in
  Phase 4, and runs `scripts/update-docs-index.sh` after edits.
- **Recorder-A** in Phase 6 promotes session artifacts to `docs/tasks/<id>/`
  (README, consultation, votes, outcome), updates affected folder READMEs,
  regenerates `_meta/index.json`, and appends to `docs/CHANGELOG.md`.
- **Recorder-A** participates in Accept Votes by reviewing everyone else's
  artifacts (its own docs are excluded from its vote scope).
- **Recorder-B** acts as docs quality reviewer — "is this doc a good doc?" —
  checking readability, consistency, frontmatter completeness, and
  `_meta/index.json` freshness during Accept Votes.
- **Recorder-B** audits recorder-A's Phase 6 archive and pushes back if the
  task bundle is insufficient before the team lead calls `TeamDelete`.
