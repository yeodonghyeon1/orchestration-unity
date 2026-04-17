# orchestration-unity v1.0 — Slice E: Migration + Release Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the v1.0.0 release — migration helper for v0.2.0 users, replacement of the v0.2.0 docs with v1.0 versions, final CHANGELOG, README update, and git tag `v1.0.0`.

**Architecture:** Single bash migration script (`scripts/migrate-v02-to-v1.sh`) that detects v0.2.0 artifacts, offers to move `docs/` → `develop_docs/`, and preserves `.orchestration/sessions/` as historical. Documentation files swap: `architecture-v1.md` → `architecture.md`, `notion-schema-guide-v1.md` → `notion-schema-guide.md` (the old versions go to `docs/archive/v0.2/`). README replaced. Version bumped to `1.0.0` (no suffix), tagged.

**Tech Stack:** bash migration helper, markdown edits.

**Delivers:**
- `scripts/migrate-v02-to-v1.sh` — detects v0.2.0 artifacts and migrates
- v1.0 docs become canonical (v0.2.0 docs archived)
- Updated `README.md` with v1.0 workflow
- Final CHANGELOG `[1.0.0]` entry
- Git tag `v1.0.0`

**Reads from spec:** Section 12 (Migration) and Section 14 (Acceptance Criteria)

**Prerequisites:** Slices A, B, C, D all complete and tests passing.

---

## File Structure Map

### Create

| Path | Purpose |
|------|---------|
| `scripts/migrate-v02-to-v1.sh` | Migration helper for existing v0.2.0 users |
| `tests/integration/test-migration.sh` | Simulate migration from v0.2.0 layout |
| `tests/fixture/v0.2-layout/` | Mock v0.2.0 project layout for test |

### Move (archive old docs)

| From | To |
|------|-----|
| `docs/architecture.md` | `docs/archive/v0.2/architecture.md` |
| `docs/getting-started.md` | `docs/archive/v0.2/getting-started.md` |
| `docs/troubleshooting.md` | `docs/archive/v0.2/troubleshooting.md` |

### Rename (promote v1 docs to canonical names)

| From | To |
|------|-----|
| `docs/architecture-v1.md` | `docs/architecture.md` |
| `docs/notion-schema-guide-v1.md` | `docs/notion-schema-guide.md` |

### Modify

| Path | Change |
|------|--------|
| `README.md` | Full rewrite for v1.0 workflow |
| `CHANGELOG.md` | Promote `[Unreleased]` to `[1.0.0]` + dated entry |
| `.claude-plugin/plugin.json` | Bump to `1.0.0` (drop `-alpha.*`) |

---

## Phase E-1: Migration Helper

### Task 1: `scripts/migrate-v02-to-v1.sh` (TDD)

**Files:**
- Create: `scripts/migrate-v02-to-v1.sh`
- Create: `tests/fixture/v0.2-layout/`
- Create: `tests/integration/test-migration.sh`

- [ ] **Step 1: Build v0.2.0 fixture layout**

```bash
mkdir -p tests/fixture/v0.2-layout/docs/game/systems
mkdir -p tests/fixture/v0.2-layout/docs/design
mkdir -p tests/fixture/v0.2-layout/.orchestration/sessions/2026-04-11-sample

# Sample v0.2.0 docs tree content
cat > tests/fixture/v0.2-layout/docs/game/systems/combat.md <<'EOF'
---
id: game.systems.combat
title: Combat System
---
# Combat System

Legacy v0.2.0 doc.
EOF

cat > tests/fixture/v0.2-layout/.orchestration/sessions/2026-04-11-sample/README.md <<'EOF'
# Sample v0.2.0 session artifact (to preserve as historical)
EOF
```

- [ ] **Step 2: Write the failing test**

`tests/integration/test-migration.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIG="$REPO_ROOT/scripts/migrate-v02-to-v1.sh"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -r "$REPO_ROOT/tests/fixture/v0.2-layout/"* "$TMP/"

# Run migration (non-interactive flag for automated test)
(cd "$TMP" && bash "$MIG" --yes)

# Verify develop_docs exists with moved content
[ -f "$TMP/develop_docs/game/systems/combat.md" ] \
    || fail "docs/game was not moved to develop_docs/game"
pass "docs/ tree moved to develop_docs/"

# Verify notion_docs scaffolded
[ -d "$TMP/notion_docs/_meta" ] || fail "notion_docs/_meta missing"
pass "notion_docs scaffolded"

# Verify .orchestration preserved
[ -d "$TMP/.orchestration/sessions/2026-04-11-sample" ] \
    || fail ".orchestration was deleted (should be preserved)"
pass ".orchestration preserved"

# Verify original docs/ removed (migrated, not duplicated)
[ ! -d "$TMP/docs/game" ] || fail "docs/game should have been moved, not copied"
pass "docs/ source removed after move"

echo "All migration tests passed"
```

Make executable.

- [ ] **Step 3: Run to verify failure**

```bash
bash tests/integration/test-migration.sh
```

Expected: FAIL (script missing).

- [ ] **Step 4: Implement `scripts/migrate-v02-to-v1.sh`**

```bash
#!/usr/bin/env bash
# migrate-v02-to-v1.sh — migrate an existing v0.2.0 orchestration-unity
# Unity project to the v1.0 layout.
#
# Behavior:
#   1. Detect existing `docs/` tree (v0.2.0 style). If present, move
#      its content into `develop_docs/`.
#   2. Scaffold `notion_docs/` (via init-workspace.sh).
#   3. Preserve `.orchestration/sessions/` untouched (historical).
#   4. Print a summary.
#
# Flags:
#   --yes         skip interactive prompts (for CI/tests)
#   --dry-run     print what would be done, do not modify anything
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

YES=0
DRY=0
for arg in "$@"; do
    case "$arg" in
        --yes) YES=1 ;;
        --dry-run) DRY=1 ;;
    esac
done

confirm() {
    if [ "$YES" -eq 1 ]; then return 0; fi
    read -r -p "$1 [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

log() { echo "  ▸ $*"; }
act() { [ "$DRY" -eq 1 ] && log "DRY: $*" || { log "$*"; eval "$@"; }; }

echo "=== orchestration-unity v0.2 → v1.0 migration ==="

# 1. docs/ → develop_docs/
if [ -d docs ] && [ ! -d develop_docs ]; then
    echo "Detected v0.2.0 docs/ tree."
    if confirm "Move docs/ → develop_docs/ ?"; then
        act "mkdir -p develop_docs"
        # Move only directories that match v0.2 doc-tree pattern.
        # Leave docs/superpowers/ (plans/specs) in place.
        for d in game design tech decisions tasks _meta; do
            if [ -d "docs/$d" ]; then
                act "mv docs/$d develop_docs/"
            fi
        done
        log "moved docs/ content → develop_docs/"
    else
        log "skipped docs/ migration"
    fi
else
    log "no v0.2.0 docs/ tree found (or develop_docs already exists); skipping"
fi

# 2. Scaffold notion_docs via init-workspace.sh
if [ ! -d notion_docs ]; then
    if confirm "Scaffold notion_docs/ and _meta/ files?"; then
        act "bash $REPO_ROOT/scripts/init-workspace.sh ."
        log "notion_docs/ scaffolded"
    else
        log "skipped notion_docs scaffold"
    fi
fi

# 3. .orchestration/ preserved as-is
if [ -d .orchestration ]; then
    log "preserving .orchestration/ as historical (no action)"
fi

# 4. Summary
echo ""
echo "=== migration complete ==="
echo "next steps:"
echo "  - fill notion_docs/_meta/page-map.json via /notion-sync (or manually)"
echo "  - review CHANGELOG for v1.0 breaking changes"
echo "  - run: bash tests/structure-check.sh"
```

Make executable.

- [ ] **Step 5: Run test to verify pass**

```bash
bash tests/integration/test-migration.sh
```

Expected: 4 `✓` marks.

- [ ] **Step 6: Commit**

```bash
git add scripts/migrate-v02-to-v1.sh tests/fixture/v0.2-layout/ tests/integration/test-migration.sh
git commit -m "feat(scripts): add migrate-v02-to-v1.sh with --yes and --dry-run flags"
```

---

## Phase E-2: Documentation Swap

### Task 2: Archive v0.2.0 docs and promote v1.0 docs

**Files:**
- Move 3 files to `docs/archive/v0.2/`
- Rename 2 files to canonical names

- [ ] **Step 1: Create archive directory and move v0.2 docs**

```bash
mkdir -p docs/archive/v0.2
git mv docs/architecture.md docs/archive/v0.2/architecture.md
git mv docs/getting-started.md docs/archive/v0.2/getting-started.md
git mv docs/troubleshooting.md docs/archive/v0.2/troubleshooting.md
```

- [ ] **Step 2: Promote v1 docs**

```bash
git mv docs/architecture-v1.md docs/architecture.md
git mv docs/notion-schema-guide-v1.md docs/notion-schema-guide.md
```

- [ ] **Step 3: Update frontmatter to drop `-v1` suffix in `supersedes:`**

Open the renamed `docs/architecture.md`. Update frontmatter:

```yaml
---
id: plugin-docs.architecture
title: Architecture Overview
owner: developer
status: stable
updated: 2026-04-18
version: 1.0.0
tags: [architecture, v1]
---
```

(Remove the `supersedes: architecture.md` line now that it IS `architecture.md`.)

Open the renamed `docs/notion-schema-guide.md`. Update frontmatter similarly.

- [ ] **Step 4: Create archive pointer README**

`docs/archive/v0.2/README.md`:

```markdown
# v0.2.0 Archived Documentation

These documents describe the v0.2.0 release (10-agent consensus team). They
are preserved for historical reference. Current docs are at the parent level.

| Archived file | Described |
|---------------|-----------|
| `architecture.md` | 10-agent team, voting, pair review, playtest |
| `getting-started.md` | v0.2.0 install and first run |
| `troubleshooting.md` | v0.2.0 deadlock fixes, recorder issues |

See `docs/superpowers/specs/2026-04-11-unity-orchestration-design.md`
for the v0.2.0 design spec (also preserved).
```

- [ ] **Step 5: Commit (one commit per logical group)**

```bash
git add docs/archive/v0.2/
git commit -m "docs: archive v0.2.0 documentation under docs/archive/v0.2/"
```

```bash
git add docs/architecture.md docs/notion-schema-guide.md
git commit -m "docs: promote v1.0 architecture and notion-schema-guide to canonical names"
```

---

## Phase E-3: README Replacement

### Task 3: Rewrite `README.md` for v1.0

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace contents**

```markdown
# orchestration-unity

A Claude Code plugin that drives Unity game development through a
**Notion-driven Superpowers pipeline**. Human designers write in Notion;
Claude mirrors to `notion_docs/`, refines into `develop_docs/`, and
implements via `unity-mcp` with full TDD and verification discipline.

- **Skill names:** `unity-orchestration`, `notion-sync`, `docs-refinement`
- **Slash commands:** `/unity-orchestration`, `/notion-sync`, `/docs-refinement`, `/docs-update`
- **Requires:** Claude Code, [Superpowers plugin](https://github.com/obra/superpowers-marketplace), Notion MCP, [unity-mcp](https://github.com/CoplayDev/unity-mcp), a Unity project

> Coming from v0.2.0 (10-agent consensus)? See `CHANGELOG.md` for breaking
> changes and run `bash scripts/migrate-v02-to-v1.sh` to migrate.

## Install

```
/plugin marketplace add yeodonghyeon1/orchestration-unity
/plugin install unity-orchestration@orchestration-unity
```

Restart Claude Code if prompted, then `cd` into your Unity project.

## First-time setup

1. Create three top-level pages in your Notion workspace: `개발`, `아트`, `기획` (see `docs/notion-schema-guide.md` for content conventions).
2. Run once: `bash scripts/init-workspace.sh .`
3. First sync: `/notion-sync` — confirms page → folder mappings.

## Daily workflows

### When Notion changes
```
/docs-update
```
Runs: sync → refine → commit → push to `sync/notion-YYYYMMDD-HHMM` branch.
Review the PR manually and merge.

### When developing a feature
```
/unity-orchestration "add enemy patrol system"
```
Runs the eleven-step Superpowers chain: brainstorming → plan → TDD execution → verification → code-derived develop_docs update → branch finishing.

## Architecture at a glance

```
Notion (개발 / 아트 / 기획)
    ↓ /notion-sync
notion_docs/  (1:1 raw mirror)
    ↓ /docs-refinement
develop_docs/  (refined, cross-referenced, living)
    ↓ /unity-orchestration <task>
Superpowers chain → Unity MCP → code + tests
    ↓ Step 10
develop_docs/tech/unity/**  (auto-updated with class signatures)
```

See `docs/architecture.md` for the full component diagram.

## Docs

- `docs/architecture.md` — architecture overview
- `docs/notion-schema-guide.md` — Notion content conventions
- `docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md` — full technical spec
- `docs/archive/v0.2/` — historical v0.2.0 docs

## Status

**v1.0.0** — initial Notion-driven Superpowers release. Supersedes v0.2.0
consensus team entirely. See `CHANGELOG.md`.

Bug reports and PRs welcome at <https://github.com/yeodonghyeon1/orchestration-unity/issues>.

## License

MIT — see `LICENSE`.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for v1.0 Notion-driven Superpowers pipeline"
```

---

## Phase E-4: Final Release

### Task 4: Finalize CHANGELOG and bump to 1.0.0

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Set version to `1.0.0`**

In `.claude-plugin/plugin.json`, change `"version": "1.0.0-alpha.4"` to `"version": "1.0.0"`.

- [ ] **Step 2: Rewrite CHANGELOG header**

Replace the `[Unreleased]` section header with `[1.0.0] — 2026-04-18` and
consolidate the 5 slice subsections into a single release entry:

```markdown
## [1.0.0] — 2026-04-18

### BREAKING
- Complete redesign: 10-agent consensus team replaced with Notion-driven Superpowers pipeline.
- `/unity-orchestration` arguments, skill names, and workflow semantics have all changed. Existing v0.2.0 users should run `bash scripts/migrate-v02-to-v1.sh`.
- Removed: `skills/unity-orchestration/agents/*.md`, `voting.md`, `consultation-table.md`, `scripts/tally-votes.sh`, `agents/unity-orchestrator.md`.

### Added
- Two-tier docs: `notion_docs/` (raw Notion mirror) + `develop_docs/` (refined, cross-referenced).
- `/notion-sync`, `/docs-refinement`, `/docs-update` slash commands.
- `scripts/notion-hash.py` — deterministic SHA256 of Notion content.
- `scripts/page-map.py` — Notion page → folder mapping.
- `scripts/sync-state.py` — `_meta/sync-state.json` management.
- `scripts/docs-index.py` — `_meta/index.json` with tree + reverse_index (fixes v0.2 `_self` bug).
- `scripts/bfs-impact.py` — reverse-index BFS traversal.
- `scripts/provenance.py` — HTML-comment section-level source markers.
- `scripts/code-to-docs.py` — C# public surface → markdown.
- `scripts/code-doc-updater.sh` — post-implementation develop_docs updater.
- `scripts/migrate-v02-to-v1.sh` — migrate existing v0.2.0 projects.
- `skills/notion-sync/` — 4-step change detection.
- `skills/docs-refinement/` — BFS-based incremental refinement.
- Rewritten `skills/unity-orchestration/` — 11-step Superpowers chain orchestrator.
- Section-level provenance (`notion:*` / `code:*` / `manual`) for Living Knowledge Base.
- Integration tests: notion-sync, docs-refinement, preservation, unity-orchestration flow, migration.
- Docs: `architecture.md` (v1 promoted), `notion-schema-guide.md`, full spec at `docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md`.

### Changed
- `scripts/update-docs-index.py` → forwarding shim to `docs-index.py`.
- `scripts/init-workspace.sh` now seeds `notion_docs/` and `develop_docs/` dual trees.
- v0.2.0 docs archived under `docs/archive/v0.2/`.

### Preserved
- `.orchestration/sessions/` content from v0.2.0 sessions (unused in v1.0 but not deleted).
- `docs/superpowers/specs/2026-04-11-unity-orchestration-design.md` (v0.2.0 design spec).
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: release v1.0.0"
```

---

### Task 5: Tag the release

**Files:** none (git tag only)

- [ ] **Step 1: Verify all tests pass**

```bash
bash tests/structure-check.sh
bash tests/sync-engine-tests/test-notion-hash.sh
bash tests/sync-engine-tests/test-page-map.sh
bash tests/sync-engine-tests/test-sync-state.sh
bash tests/sync-engine-tests/test-docs-index.sh
bash tests/sync-engine-tests/test-bfs-impact.sh
bash tests/sync-engine-tests/test-provenance.sh
bash tests/sync-engine-tests/test-code-to-docs.sh
bash tests/sync-engine-tests/test-code-doc-updater.sh
bash tests/integration/test-notion-sync.sh
bash tests/integration/test-docs-refinement.sh
bash tests/integration/test-preservation.sh
bash tests/integration/test-unity-orchestration-flow.sh
bash tests/integration/test-migration.sh
```

All must pass. If any fails: STOP, fix the failure, do NOT tag.

- [ ] **Step 2: Create annotated tag**

```bash
git tag -a v1.0.0 -m "orchestration-unity v1.0.0 — Notion-driven Superpowers pipeline"
```

- [ ] **Step 3: Push tag (user confirms first)**

Ask user: "All tests passed. Push tag `v1.0.0` to origin?"

On yes:
```bash
git push origin v1.0.0
```

On no: keep local tag, notify user they can push later with `git push origin v1.0.0`.

---

## Phase E-5: Smoke Test Against a Real Unity Project

### Task 6: Manual smoke test checklist

**Files:**
- Create: `tests/manual-scenarios/v1-smoke-test.md`

- [ ] **Step 1: Write the checklist**

```markdown
# v1.0.0 Smoke Test (Manual)

Run on a **fresh Unity project** (or a copy) with a **test Notion workspace**.

## Pre-conditions

- [ ] orchestration-unity v1.0.0 installed
- [ ] Superpowers plugin installed
- [ ] Notion MCP connected
- [ ] unity-mcp MCP connected
- [ ] Test Unity project with `Assets/` + `ProjectSettings/`

## Init

- [ ] Run `bash scripts/init-workspace.sh .`
- [ ] Verify `notion_docs/_meta/sync-state.json` exists
- [ ] Verify `develop_docs/_meta/index.json` will exist after first refinement
- [ ] Verify `notion_docs/_meta/page-map.json` has `mappings: []`

## First sync

- [ ] Create 3 test Notion pages: `개발`, `아트`, `기획`
- [ ] Run `/notion-sync`
- [ ] Confirm folder mapping prompts appear (3 times, one per page)
- [ ] Verify `notion_docs/dev/`, `notion_docs/art/`, `notion_docs/plan/` populated
- [ ] Check frontmatter fields: `notion_page_id`, `content_hash`, `synced_at`

## Idempotent re-sync

- [ ] Run `/notion-sync` again without changes
- [ ] Expected: 0 file diffs, "no changes" summary

## Edit detection

- [ ] Edit one Notion page (add a paragraph)
- [ ] Run `/notion-sync`
- [ ] Expected: only that page's `.md` updated (hash changed)

## Refinement

- [ ] Run `/docs-refinement`
- [ ] Verify `develop_docs/game/` or `develop_docs/design/` populated
- [ ] Verify `source_notion_docs[]` frontmatter set correctly

## Full pipeline

- [ ] Run `/docs-update`
- [ ] Verify new branch `sync/notion-YYYYMMDD-HHMM` created
- [ ] Verify 2 commits: one for notion_docs, one for develop_docs
- [ ] Verify push to origin succeeded (or local branch if offline)
- [ ] Verify `main` is NOT modified

## Game dev workflow

- [ ] Run `/unity-orchestration "add a simple enemy patrol script"`
- [ ] Verify brainstorming runs (HARD-GATE prompts appear)
- [ ] Approve plan at user gate
- [ ] Verify TDD discipline: failing test written first
- [ ] Verify `unity-mcp` calls made for scene/prefab work
- [ ] After completion: verify `develop_docs/tech/unity/` updated with new C# signatures

## Migration

- [ ] On a v0.2.0 sample project, run `bash scripts/migrate-v02-to-v1.sh`
- [ ] Verify `docs/` tree moved to `develop_docs/`
- [ ] Verify `notion_docs/` scaffolded
- [ ] Verify `.orchestration/sessions/` preserved intact

## Pass criteria

All checkboxes above must be checked. File any failures at
<https://github.com/yeodonghyeon1/orchestration-unity/issues>.
```

- [ ] **Step 2: Commit**

```bash
git add tests/manual-scenarios/v1-smoke-test.md
git commit -m "test: add v1.0 manual smoke test checklist"
```

---

## Completion Criteria (Slice E + Full v1.0 Done)

### Slice E specific
- [ ] `bash tests/integration/test-migration.sh` passes
- [ ] v0.2.0 docs in `docs/archive/v0.2/`
- [ ] `docs/architecture.md` and `docs/notion-schema-guide.md` are the v1.0 versions
- [ ] `README.md` describes v1.0 workflow
- [ ] `CHANGELOG.md` has `[1.0.0]` dated section
- [ ] `.claude-plugin/plugin.json` version = `1.0.0`
- [ ] Git tag `v1.0.0` created (push pending user confirm)
- [ ] 6 commits on main (Tasks 1-6)

### Full v1.0 acceptance (from spec Section 14)
- [ ] `/notion-sync` produces correct `notion_docs/` from a test workspace
- [ ] `/docs-refinement` produces cross-referenced `develop_docs/`
- [ ] Hash-based change detection skips unchanged pages
- [ ] BFS reverse-index correctly identifies affected files
- [ ] `/docs-update` commits + pushes to sync branch
- [ ] `/unity-orchestration` invokes full Superpowers chain
- [ ] v0.2 → v1.0 migration works on sample project
- [ ] CHANGELOG has BREAKING label
- [ ] README updated
- [ ] All structure-check and unit + integration tests pass
- [ ] Smoke-test checklist executed against a real Unity project

v1.0.0 is shippable. 🎉
