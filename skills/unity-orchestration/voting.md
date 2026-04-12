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

- Pass threshold: **6 approvals out of 10**.
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
pair, the agent MUST abstain. The tester has no pair and reviews all
artifacts from a player-experience perspective; they are never required
to abstain.

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
- **Result:** PASS (7 approve / 2 reject / 1 abstain)

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
