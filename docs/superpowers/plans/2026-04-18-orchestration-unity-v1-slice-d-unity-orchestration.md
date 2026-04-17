# orchestration-unity v1.0 — Slice D: Unity Orchestration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the `unity-orchestration` skill to orchestrate the full Superpowers chain (brainstorming → writing-plans → executing-plans → TDD → verification → finishing-a-development-branch), using `develop_docs/` as the context source and `unity-mcp` for actual scene/prefab/code changes. Add code-derived develop_docs updates after verification (Slice C Step 10).

**Architecture:** The skill becomes a **meta-orchestrator** — a thin wrapper that invokes Superpowers skills in sequence and calls `scripts/code-to-docs.py` after successful task completion to update `develop_docs/tech/unity/**`. The 10-agent consensus team code is GONE. Main Claude drives everything; sub-agents are only spawned via `superpowers:subagent-driven-development`.

**Tech Stack:** Claude Code Skill/Command markdown, Superpowers skill chain, unity-mcp MCP, bash (git + code scan automation).

**Delivers:**
- Rewritten `skills/unity-orchestration/SKILL.md` (Superpowers-chain entry)
- Rewritten `skills/unity-orchestration/workflow.md` (5-stage pipeline)
- Rewritten `commands/unity-orchestration.md` (structured task flow)
- `scripts/code-doc-updater.sh` — bash orchestrator that runs `code-to-docs.py` across touched C# files and updates develop_docs
- Integration test simulating a mini task through the pipeline

**Reads from spec:** Sections 8 (slash commands), 8.1 (unity-orchestration flow), 17.4 (code-derived updates)

**Prerequisites:** Slices A, B, C complete.

---

## File Structure Map

### Create

| Path | Purpose |
|------|---------|
| `scripts/code-doc-updater.sh` | After code change, scan touched C# files → update develop_docs via provenance.py + code-to-docs.py |
| `tests/sync-engine-tests/test-code-doc-updater.sh` | Unit test for the updater |
| `tests/integration/test-unity-orchestration-flow.sh` | End-to-end flow simulation (without real Unity MCP) |
| `tests/fixture/mini-unity-project/` | Minimal directory mimicking Unity project layout |

### Modify

| Path | Change |
|------|--------|
| `skills/unity-orchestration/SKILL.md` | Full rewrite — Superpowers chain orchestrator |
| `skills/unity-orchestration/workflow.md` | Full rewrite — 5-stage pipeline + code-derived step |
| `commands/unity-orchestration.md` | Rewrite — take `<task>` arg, invoke Superpowers chain |
| `skills/unity-orchestration/docs-tree-spec.md` | Extend to document `tech/unity/**` code-derived conventions |
| `CHANGELOG.md` | Append Slice D entries |
| `.claude-plugin/plugin.json` | Bump to `1.0.0-alpha.4` |

### Delete (v0.2.0 consensus team artifacts)

| Path | Reason |
|------|--------|
| `skills/unity-orchestration/agents/team-lead.md` | v0.2.0 consensus team |
| `skills/unity-orchestration/agents/planner-a.md` | v0.2.0 |
| `skills/unity-orchestration/agents/planner-b.md` | v0.2.0 |
| `skills/unity-orchestration/agents/designer-a.md` | v0.2.0 |
| `skills/unity-orchestration/agents/designer-b.md` | v0.2.0 |
| `skills/unity-orchestration/agents/dev-a.md` | v0.2.0 |
| `skills/unity-orchestration/agents/dev-b.md` | v0.2.0 |
| `skills/unity-orchestration/agents/recorder-a.md` | v0.2.0 |
| `skills/unity-orchestration/agents/recorder-b.md` | v0.2.0 |
| `skills/unity-orchestration/agents/tester.md` | v0.2.0 |
| `skills/unity-orchestration/voting.md` | No more voting |
| `skills/unity-orchestration/consultation-table.md` | No consensus |
| `scripts/tally-votes.sh` | No more votes |
| `agents/unity-orchestrator.md` | Bootstrap no longer needed |

---

## Phase D-1: Delete v0.2.0 Consensus Team

### Task 1: Remove agents and voting infrastructure

**Files:** (delete — listed above)

- [ ] **Step 1: Verify current state**

```bash
ls skills/unity-orchestration/agents/
ls skills/unity-orchestration/voting.md skills/unity-orchestration/consultation-table.md 2>/dev/null
```

Expected: 10 agent files + 2 reference files present.

- [ ] **Step 2: Delete files**

```bash
git rm -r skills/unity-orchestration/agents/
git rm skills/unity-orchestration/voting.md
git rm skills/unity-orchestration/consultation-table.md
git rm scripts/tally-votes.sh
git rm -r agents/ 2>/dev/null || true
```

- [ ] **Step 3: Verify structure-check still passes after we update it**

(We'll update structure-check.sh in the next task; for now it will fail. That's expected — we'll fix in Task 2.)

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: remove v0.2.0 consensus team artifacts (10 agents, voting, consultation)"
```

---

### Task 2: Update `tests/structure-check.sh` to reflect v1.0

**Files:**
- Modify: `tests/structure-check.sh`

- [ ] **Step 1: Remove v0.2.0 assertions**

Open `tests/structure-check.sh`. Remove all lines that assert the existence of files we just deleted (agents/*, voting.md, consultation-table.md, tally-votes.sh, unity-orchestrator.md).

Example: if structure-check.sh had:

```bash
[ -f skills/unity-orchestration/voting.md ] || { echo "missing"; exit 1; }
```

Delete it.

- [ ] **Step 2: Run structure-check**

```bash
bash tests/structure-check.sh
```

Expected: pass (all v1.0 assertions already pass from Slices A-C; v0.2.0 assertions removed).

- [ ] **Step 3: Commit**

```bash
git add tests/structure-check.sh
git commit -m "test: update structure-check to remove v0.2.0 agent/vote assertions"
```

---

## Phase D-2: Rewrite unity-orchestration Skill

### Task 3: Rewrite `skills/unity-orchestration/SKILL.md`

**Files:**
- Modify: `skills/unity-orchestration/SKILL.md` (full rewrite)

- [ ] **Step 1: Replace file contents**

```markdown
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
```

- [ ] **Step 2: Structure-check passes**

```bash
bash tests/structure-check.sh
```

Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add skills/unity-orchestration/SKILL.md
git commit -m "refactor(skills): rewrite unity-orchestration as Superpowers chain orchestrator"
```

---

### Task 4: Rewrite `skills/unity-orchestration/workflow.md`

**Files:**
- Modify: `skills/unity-orchestration/workflow.md` (full rewrite)

- [ ] **Step 1: Replace contents**

```markdown
---
id: skills.unity-orchestration.workflow
title: Unity Orchestration Workflow (v1.0 — Superpowers chain)
owner: developer
status: stable
updated: 2026-04-18
version: 2
tags: [workflow, reference, v1]
supersedes: workflow.md (v1)
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

Commit the develop_docs changes on the same feature branch (NOT the sync branch).

## Step 11 — Branch finishing

`superpowers:finishing-a-development-branch` presents merge/PR options. The
user decides: merge to main / open PR / keep branch open for more work / discard.

## Error handling

- **Notion MCP absent**: brainstorming and planning still work; step 8 warns and stops.
- **unity-mcp absent**: plan can still be produced, implementation paused at Step 6.
- **User rejects plan at Step 4**: go back to Step 3 or Step 1 depending on feedback scope.
- **Verification fails at Step 9**: go back to Step 6 for the failing task; do NOT proceed.
- **code-doc-updater.sh fails at Step 10**: warning only; do not block Step 11. File an issue.
```

- [ ] **Step 2: Verify**

```bash
bash tests/structure-check.sh
```

Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add skills/unity-orchestration/workflow.md
git commit -m "refactor(skills): rewrite workflow.md as 11-step Superpowers chain"
```

---

### Task 5: Rewrite `commands/unity-orchestration.md`

**Files:**
- Modify: `commands/unity-orchestration.md`

- [ ] **Step 1: Replace contents**

```markdown
---
description: Drive a Unity game development task through the full Superpowers discipline chain
argument-hint: "<task description, e.g., 'add enemy patrol system'>"
---

# /unity-orchestration

Run the provided `<task>` through the eleven-step Superpowers chain,
backed by `develop_docs/` context and `unity-mcp` execution.

If no argument provided: prompt user for task description; do not proceed without it.

Invoke the skill:

```
Skill('unity-orchestration')
```

The skill enforces:
- HARD-GATE on brainstorming before planning
- User approval gate on the written plan before code is written
- TDD Iron Law (failing test first)
- Verification before completion

Interrupts allowed at: after Step 1 (brainstorm outcome unsatisfactory),
after Step 4 (plan unsatisfactory), after Step 9 (verification surfaces issues).

See `skills/unity-orchestration/workflow.md` for the full step-by-step flow.
```

- [ ] **Step 2: Commit**

```bash
git add commands/unity-orchestration.md
git commit -m "refactor(commands): /unity-orchestration takes task arg, invokes Superpowers chain"
```

---

## Phase D-3: code-doc-updater Script

### Task 6: `scripts/code-doc-updater.sh` — automate Step 10 (TDD)

**Files:**
- Create: `scripts/code-doc-updater.sh`
- Test: `tests/sync-engine-tests/test-code-doc-updater.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/sync-engine-tests/test-code-doc-updater.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UP="$REPO_ROOT/scripts/code-doc-updater.sh"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Set up mini project
mkdir -p "$TMP/Assets/Scripts/Combat"
cat > "$TMP/Assets/Scripts/Combat/CombatSystem.cs" <<'EOF'
public sealed class CombatSystem {
    public void StartCombat() {}
}
EOF

mkdir -p "$TMP/develop_docs/tech/unity/scripts"
cat > "$TMP/develop_docs/tech/unity/scripts/combat-system.md" <<'EOF'
---
id: tech.unity.scripts.combat-system
title: CombatSystem
source_notion_docs: []
---
# CombatSystem

<!-- source: notion:plan.combat-system -->
## Overview

Notion content.
<!-- /source -->

<!-- source: code:Assets/Scripts/Combat/CombatSystem.cs -->
## Implementation

(stale)
<!-- /source -->
EOF

# Run updater
(cd "$TMP" && bash "$UP" Assets/Scripts/Combat/CombatSystem.cs)

# Verify: code section updated
grep -q "StartCombat" "$TMP/develop_docs/tech/unity/scripts/combat-system.md" || fail "code section did not update"
pass "code section regenerated"

# Verify: notion section untouched
grep -q "Notion content" "$TMP/develop_docs/tech/unity/scripts/combat-system.md" || fail "notion section wiped"
pass "notion section preserved"

# Verify: stale code content replaced
if grep -q "(stale)" "$TMP/develop_docs/tech/unity/scripts/combat-system.md"; then
    fail "stale code content not replaced"
fi
pass "stale content removed"

echo "All code-doc-updater tests passed"
```

Make executable.

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/sync-engine-tests/test-code-doc-updater.sh
```

Expected: FAIL (script missing).

- [ ] **Step 3: Implement `scripts/code-doc-updater.sh`**

```bash
#!/usr/bin/env bash
# code-doc-updater.sh — after code changes, update develop_docs/tech/unity/**
# with fresh C# signatures via code-to-docs.py + provenance.py.
#
# Usage:
#     scripts/code-doc-updater.sh <file1.cs> [<file2.cs> ...]
#
# For each input file:
#   1. Find develop_docs/tech/unity/**/*.md that references this file in
#      code_references[].path frontmatter (grep-based; no YAML parser).
#   2. Run code-to-docs.py on the file to generate the new code section.
#   3. Run provenance.py replace (or append if marker missing) to merge.
#
# Non-fatal on errors — logs and continues so it doesn't block Step 11.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
C2D="$REPO_ROOT/scripts/code-to-docs.py"
PROV="$REPO_ROOT/scripts/provenance.py"

DEV_DOCS="${DEVELOP_DOCS:-develop_docs}"
if [ ! -d "$DEV_DOCS/tech/unity" ]; then
    echo "warn: $DEV_DOCS/tech/unity not found — nothing to update" >&2
    exit 0
fi

for cs_file in "$@"; do
    if [ ! -f "$cs_file" ]; then
        echo "skip: $cs_file (not a file)" >&2
        continue
    fi

    # Find develop_docs referencing this file
    matches=$(grep -rl "path: $cs_file" "$DEV_DOCS/tech/unity" 2>/dev/null || true)
    if [ -z "$matches" ]; then
        echo "info: no develop_docs references $cs_file — skipping" >&2
        continue
    fi

    # Generate new markdown section from code
    tmp_section=$(mktemp)
    python3 "$C2D" "$cs_file" > "$tmp_section" || {
        echo "warn: code-to-docs.py failed on $cs_file" >&2
        rm -f "$tmp_section"
        continue
    }

    marker="code:$cs_file"

    for doc in $matches; do
        # Check if marker already exists; replace or append
        if python3 "$PROV" sources "$doc" | grep -qx "$marker"; then
            python3 "$PROV" replace "$doc" "$marker" "$tmp_section" \
                && echo "updated: $doc ($marker)" \
                || echo "warn: replace failed for $doc" >&2
        else
            python3 "$PROV" append "$doc" "$marker" "$tmp_section" \
                && echo "appended: $doc ($marker)" \
                || echo "warn: append failed for $doc" >&2
        fi
    done

    rm -f "$tmp_section"
done

exit 0
```

Make executable.

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/sync-engine-tests/test-code-doc-updater.sh
```

Expected: 3 `✓` marks.

- [ ] **Step 5: Commit**

```bash
git add scripts/code-doc-updater.sh tests/sync-engine-tests/test-code-doc-updater.sh
git commit -m "feat(scripts): code-doc-updater.sh for Step 10 develop_docs refresh"
```

---

## Phase D-4: End-to-End Simulation

### Task 7: Integration test — simulated orchestration flow

**Files:**
- Create: `tests/integration/test-unity-orchestration-flow.sh`
- Create: `tests/fixture/mini-unity-project/` (minimal scaffold)

- [ ] **Step 1: Create mini Unity project fixture**

```bash
mkdir -p tests/fixture/mini-unity-project/Assets/Scripts/Combat
mkdir -p tests/fixture/mini-unity-project/ProjectSettings
touch tests/fixture/mini-unity-project/ProjectSettings/.gitkeep
```

- [ ] **Step 2: Write the flow simulation test**

`tests/integration/test-unity-orchestration-flow.sh`:

```bash
#!/usr/bin/env bash
# Simulates the path through unity-orchestration without invoking actual Claude
# skills or unity-mcp. Verifies that the SCRIPT LAYER (code-doc-updater.sh
# + code-to-docs.py + provenance.py + docs-index.py) behaves correctly as
# a pipeline.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Seed mini project
cp -r "$REPO_ROOT/tests/fixture/mini-unity-project/"* "$TMP/"
cd "$TMP"

# Seed develop_docs with existing unity doc
mkdir -p develop_docs/tech/unity/scripts develop_docs/_meta
cat > develop_docs/tech/unity/scripts/combat-system.md <<'EOF'
---
id: tech.unity.scripts.combat-system
title: CombatSystem
source_notion_docs: []
code_references:
  - path: Assets/Scripts/Combat/CombatSystem.cs
    kind: class
    symbol: CombatSystem
---
# CombatSystem

<!-- source: code:Assets/Scripts/Combat/CombatSystem.cs -->
## Implementation

(empty)
<!-- /source -->
EOF

# Write initial C# (Step 6 simulated outcome)
cat > Assets/Scripts/Combat/CombatSystem.cs <<'EOF'
public sealed class CombatSystem
{
    public void StartCombat() {}
    public int MaxActionPoints => 3;
}
EOF

# Step 9 simulated: verification passed. Step 10 runs updater.
bash "$REPO_ROOT/scripts/code-doc-updater.sh" Assets/Scripts/Combat/CombatSystem.cs

# Verify develop_docs was updated
grep -q "StartCombat" develop_docs/tech/unity/scripts/combat-system.md \
    || fail "develop_docs not updated after Step 10"
pass "Step 10 updated develop_docs"

# Rebuild index after changes
python3 "$REPO_ROOT/scripts/docs-index.py" develop_docs
[ -f develop_docs/_meta/index.json ] || fail "index not rebuilt"
pass "index rebuilt"

# Simulate a code change — add a new method
cat > Assets/Scripts/Combat/CombatSystem.cs <<'EOF'
public sealed class CombatSystem
{
    public void StartCombat() {}
    public void EndCombat() {}
    public int MaxActionPoints => 3;
}
EOF

# Run updater again
bash "$REPO_ROOT/scripts/code-doc-updater.sh" Assets/Scripts/Combat/CombatSystem.cs

# Verify EndCombat is now in develop_docs
grep -q "EndCombat" develop_docs/tech/unity/scripts/combat-system.md \
    || fail "develop_docs did not reflect new method"
pass "subsequent Step 10 reflects code changes"

echo "All unity-orchestration flow integration tests passed"
```

Make executable.

- [ ] **Step 3: Run test**

```bash
bash tests/integration/test-unity-orchestration-flow.sh
```

Expected: 3 `✓` marks.

- [ ] **Step 4: Commit**

```bash
git add tests/fixture/mini-unity-project/ tests/integration/test-unity-orchestration-flow.sh
git commit -m "test(integration): simulate unity-orchestration Step 6 → 10 → index rebuild"
```

---

## Phase D-5: Release Metadata

### Task 8: Update CHANGELOG and version

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Bump to `1.0.0-alpha.4`**

- [ ] **Step 2: Append to `[Unreleased]`**

```markdown
### Slice D (Unity Orchestration v1.0) — this release candidate
- REMOVED: 10-agent consensus team (agents/*.md, voting.md, consultation-table.md, tally-votes.sh)
- REMOVED: `agents/unity-orchestrator.md` bootstrap
- Rewrote `skills/unity-orchestration/SKILL.md` as Superpowers chain orchestrator
- Rewrote `skills/unity-orchestration/workflow.md` with 11-step flow
- Rewrote `commands/unity-orchestration.md` to take `<task>` argument
- Added `scripts/code-doc-updater.sh` — automates Step 10 (code → develop_docs/tech/unity)
- Integration test simulates Steps 6 → 10 → index rebuild
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: bump to 1.0.0-alpha.4 with Slice D CHANGELOG entry"
```

---

## Completion Criteria (Slice D Done)

- [ ] `bash tests/structure-check.sh` passes (with v0.2.0 artifacts absent)
- [ ] `bash tests/sync-engine-tests/test-code-doc-updater.sh` passes
- [ ] `bash tests/integration/test-unity-orchestration-flow.sh` passes
- [ ] `skills/unity-orchestration/agents/` directory absent
- [ ] `voting.md`, `consultation-table.md`, `tally-votes.sh` absent
- [ ] `.claude-plugin/plugin.json` version = `1.0.0-alpha.4`
- [ ] 8 commits on main branch (Tasks 1-8)
- [ ] `skills/unity-orchestration/SKILL.md` describes 11-step Superpowers chain
- [ ] `workflow.md` has frontmatter `version: 2`

Proceed to Slice E: Migration + Release.
